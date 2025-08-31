# Batch training job using Dask + dask-ml:
# - Connects to a remote Dask cluster (scheduler) for distributed compute.
# - Loads the Breast Cancer dataset (WDBC) from S3/MinIO via s3fs.
# - Trains a Gaussian Naive Bayes model (dask-ml).
# - Extracts learned parameters and saves them back to S3 as JSON, to be used by stream processors.
#
# Notes:
# - This is a simple demo; no train/test split, feature scaling, or validation is performed.
# - Credentials are hardcoded for simplicity; prefer environment variables or secret managers in production.
# - Dask DataFrame is lazy; many operations are deferred and computed during .fit() or explicit .compute() calls.

import dask.dataframe as dd
from dask.distributed import Client
from dask_ml.naive_bayes import GaussianNB
import json
import s3fs

# Connect to the Dask scheduler service (inside Kubernetes cluster in this example).
# Make sure the service name/port matches your deployment.
client = Client("tcp://dask-scheduler:8786")

# Column names: first two are id and target, followed by 30 feature columns.
# The feature order must be consistent with downstream inference.
col_names = (
    ["id", "target"] +
    [f"feature_{i}" for i in range(1, 31)]
)

# S3/MinIO configuration (suggestion: read from env in real deployments).
ENDPOINT = "http://minio.default.svc.cluster.local:9000"
ACCESS_KEY = "minioadmin"
SECRET_KEY = "minioadminpassword"

# Input CSV path and model output path in S3.
DATA = "s3://breastcancer-data/wdbc.data"
MODEL_PATH = "s3://models/naive_bayes_params.json"

# Read CSV from S3 into a Dask DataFrame.
# storage_options flow through to s3fs; endpoint_url targets the MinIO service.
df = dd.read_csv(
    DATA,
    storage_options={
        "key": ACCESS_KEY,
        "secret": SECRET_KEY,
        "client_kwargs": {"endpoint_url": ENDPOINT},
    },
    header=None,
    names=col_names,
)

# df.shape will show (nan, ncols) until computed; printing is fine for quick diagnostics.
print("[INFO] Dataframe loaded with shape:", df.shape)

# Basic preprocessing:
# - Drop the non-predictive 'id' column.
# - Map target labels: 'M' -> 1 (malignant), 'B' -> 0 (benign).
#   The meta hints Dask about the dtype to avoid triggering a full compute.
df = df.drop("id", axis=1)
df["target"] = df["target"].map({"M": 1, "B": 0}, meta=("target", "int64"))

# Split into features (X) and labels (y) and convert to Dask Arrays.
# lengths=True records chunk lengths, which some algorithms may require.
X = df.drop("target", axis=1).to_dask_array(lengths=True)
y = df["target"].to_dask_array(lengths=True)

# Train a Gaussian Naive Bayes model (very basic, no hyperparameters here).
# The actual computation will be distributed across the Dask cluster.
nb = GaussianNB()
nb = nb.fit(X, y)

# Extract learned parameters for serving:
# - class_count_, class_prior_, theta_ (means), sigma_ (variances), classes_
# Use .compute() to materialize Dask results, then convert to lists for JSON serialization.
params = {
    "class_count_": nb.class_count_.compute().tolist(),
    "class_prior_": nb.class_prior_.compute().tolist(),
    "classes_": nb.classes_.tolist(),
    "theta_": nb.theta_.compute().tolist(),
    "sigma_": nb.sigma_.compute().tolist(),
}

# Initialize an s3fs filesystem client. Consider using session/role-based auth in production.
fs = s3fs.S3FileSystem(
    key=ACCESS_KEY,
    secret=SECRET_KEY,
    client_kwargs={"endpoint_url": ENDPOINT},
)

# Write parameters as JSON to S3 so other services (e.g., stream processing app) can load them.
with fs.open(MODEL_PATH, "w") as f:
    json.dump(params, f)

print("[SUCCESS] Model parameters saved to", MODEL_PATH)