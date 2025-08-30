import dask.dataframe as dd
from dask.distributed import Client
from dask_ml.naive_bayes import GaussianNB
import json
import s3fs

client = Client("tcp://dask-scheduler:8786")

col_names = (
    ["id", "target"] +
    [f"feature_{i}" for i in range(1, 31)]
)

# Configure via env in k8s
ENDPOINT = "http://minio.default.svc.cluster.local:9000"
ACCESS_KEY = "minioadmin"
SECRET_KEY = "minioadminpassword"

DATA = "s3://breastcancer-data/wdbc.data"
MODEL_PATH = "s3://models/naive_bayes_params.json"

df = dd.read_csv(DATA,
                 storage_options={
                     "key": ACCESS_KEY,
                     "secret": SECRET_KEY,
                     "client_kwargs": {"endpoint_url": ENDPOINT}}, 
                 header=None,
                 names=col_names)

print("[INFO] Dataframe loaded with shape:", df.shape)

df = df.drop("id", axis=1)
df["target"] = df["target"].map({"M": 1, "B": 0}, meta=('target', 'int64'))
X = df.drop("target", axis=1).to_dask_array(lengths=True)
y = df["target"].to_dask_array(lengths=True)


# Disclaimer: very basic model, just for demo purposes
nb = GaussianNB()
nb = nb.fit(X, y)

#params
params = {
    "class_count_": nb.class_count_.compute().tolist(),
    "class_prior_": nb.class_prior_.compute().tolist(),
    "classes_": nb.classes_.tolist(),
    "theta_": nb.theta_.compute().tolist(),
    "sigma_": nb.sigma_.compute().tolist()
}

fs = s3fs.S3FileSystem(
    key=ACCESS_KEY,
    secret=SECRET_KEY,
    client_kwargs={"endpoint_url": ENDPOINT},
)

with fs.open(MODEL_PATH, "w") as f:
     json.dump(params, f)

print("[SUCCESS] Model parameters saved to", MODEL_PATH)