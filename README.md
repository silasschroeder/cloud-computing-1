# Cloud Computing and Big Data — mjcs2

This repository contains the portfolio submission for the module **Cloud Computing and Big Data**. It documents the goal, implementation, and reproducibility of the assigned tasks. The portfolio is structured around two use cases:

1. **Tasks 1–3**: Provision of immutable infrastructure on OpenStack, deployment of a versionable and stateful application on Kubernetes, and demonstration of scalability and monitoring.
2. **Tasks 4–5**: Setup of a lightweight data lake and distributed processing for machine learning batch jobs, followed by real-time stream processing with Kafka and autoscaling.

Group members:

- Maya Seifert (`8252799`)
- Jonas Giessler (`TODO`)
- Christian Fischer (`3105350`)
- Sarah Wonke (`8926805`)
- Silas Schröder (`1653329`)

## Repository Structure

- `task_1/` — Immutable infrastructure (OpenTofu config, master/worker user-data)
- `images/stateful-app/` — Stateful Node.js demo application (file-backed counter)
- `images/batch-processing/` — Dask-based batch training (Naïve Bayes classifier)
- `images/stream-processing/` — Faust-based Kafka stream processor (prediction inference)
- `images/pfisterer-front-end/` — Express-based front end for request/response over Kafka
- `images/demo-keda/` — Load generator for autoscaling demo
- `workflow1-3.sh` — Ordered list of commands for Tasks 1–3 (not meant to be executed directly)
- `workflow4-5.sh` — Ordered list of commands for Tasks 4–5 (not meant to be executed directly)
- `README.md` — This documentation

## General Notes

- All technologies used are open source.
- The repository is **self-contained**; no external services are required.
- Additionally, YAML files and the WDBC dataset were moved to a separate public repository: [https://github.com/silasschroeder/files](https://github.com/silasschroeder/files).  
  This allows direct use via raw links (e.g., [MinIO Helm config](https://raw.githubusercontent.com/silasschroeder/files/main/task_4/minio.yaml)) for Helm installations or Kubernetes entity creation without saving files locally, reducing storage requirements.
- Workflows are provided to reflect the order of relevant commands, but they are **not executable scripts**. Their purpose is to guide step-by-step reproduction together with the included screencasts.
- Screencasts (compressed) demonstrate each major milestone, including infrastructure provisioning, Kubernetes deployment, monitoring, batch training, and stream processing.
- Due to limited quota in the OpenStack environment (10 GB disk per VM), reduced datasets and lightweight distributions were used. This design choice is explained in the following tasks.

---

## Task 1 — Immutable Infrastructure

**Goal**: Provision an immutable multi-VM environment on OpenStack using **OpenTofu**, and demonstrate an immutable update.

### Technology Choice: OpenTofu vs Terraform

OpenTofu was chosen over Terraform for several reasons:

1. **Compatibility**: `.tf` files are interoperable with Terraform, so the knowledge from lectures is transferable.
2. **Openness**: OpenTofu is fully open source, unlike Terraform whose source code is no longer openly developed.
3. **Trust**: Open governance and transparency make OpenTofu more reliable in academic and professional contexts.
4. **Community activity**: At the time of submission, OpenTofu is actively maintained with frequent commits and community contributions.

### Design

- Three instances: one master, two workers (configurable via variable).
- Dependencies ensure the master node is provisioned before workers join.
- User data scripts install K3s and prepare the nodes for later tasks.
- SSH key pairs are required for access.

### Implementation

The relevant files are in `task_1/`:

- `env.sh` — Environment variables for OpenStack (credentials simplified for reproducibility).
- `initialisation.tf` — Terraform-compatible configuration for the master and workers.
- `nodes/master.sh`, `nodes/worker.sh` — User data scripts executed on instance startup.

**Execution:**

```sh
cd task_1
source env.sh
tofu init
tofu apply -auto-approve
```

After a few minutes, the infrastructure is ready.

### Immutable Update

- Changing `user_data` or `key_pair` leads to **destroy-and-recreate** behavior:

  ```
  Plan: X to add, 0 to change, X to destroy.
  ```

- Changing attributes like `flavor` or `image` may instead produce an **in-place update** (mutable). This is due to the design of the OpenStack API, which supports resize and rebuild operations.
- To enforce immutability in such cases, the block

  ```hcl
  lifecycle { replace_triggered_by = [...] }
  ```

  can be used. For this project, this was not deemed necessary.

---

## Task 2 — Versioned Infrastructure and Application

**Goal**: Deploy versioned infrastructure with automated rollback capabilities and demonstrate infrastructure version management.

### Implementation

Task 2 extends the basic infrastructure from Task 1 with sophisticated version management using Git tags and automated deployment scripts. The system provides:

- **Versioned deployments**: Each infrastructure version is tagged in Git and deployed with corresponding application versions
- **Automated rollback**: Ability to rollback to any previous infrastructure version using Git history
- **Stateful application**: Containerized Node.js app with persistent storage and NFS shared volumes
- **Version cleanup**: Tools for managing Git branches and tags to maintain repository cleanliness

### Key Scripts

Located in `task_2/`:

- `deploy_version.sh` — Deploy new versioned infrastructure with K3s and stateful application
- `rollback.sh` — Interactive rollback to previous versions using Git tags  
- `destroy.sh` — Complete infrastructure teardown
- `cleanup_versions.sh` — Git version and branch management

### Workflow

```sh
cd task_2
# Deploy new version
./deploy_version.sh  # Creates Git tag, deploys infrastructure and app

# Rollback if needed
./rollback.sh        # Interactive selection of previous versions

# Clean up when done
./destroy.sh         # Destroy all resources
```

Available application images:

- `silasschroeder/stateful-app:v1.1`
- `silasschroeder/stateful-app:v1.2`
- `silasschroeder/stateful-app:v1.3`

---

## Task 3 — Microservice Architecture on Kubernetes

The **stateful app requirement from Task 1** was implemented here, as it required Kubernetes deployment.

**Goal**: Provide a multi-node Kubernetes environment and deploy a containerized, scalable, and externally accessible application.

### Technology Choice: K3s vs Alternatives

K3s was chosen as the Kubernetes distribution because:

1. **Lightweight footprint**: It consumes significantly less disk and memory than upstream Kubernetes distributions.
2. **Quota constraints**: The 10 GB disk limit in OpenStack makes K3s the only practical choice.
3. **Ease of installation**: K3s offers a fast setup with minimal configuration.
4. **Documentation**: The official K3s documentation is clear and concise.

### Implementation

The K3s setup is triggered automatically via `master.sh` and `worker.sh` during VM initialization.
Each script performs three steps:

1. Install K3s (server on master, agent on workers).
2. Install NFS server/client for storage.
3. Deploy the Kubernetes manifests on the master.

### Monitoring and Scalability

- **Prometheus** was integrated via Helm.
- Horizontal Pod Autoscaling (HPA) was tested by applying stress to the cluster.
- Replica count of the stateful app was monitored with the Prometheus query:

  ```
  kube_deployment_status_replicas{deployment="stateful-app"}
  ```

---

## Task 4 — Data Lake and Batch Processing

**Goal**: Install a distributed object store and a distributed compute engine, then perform a machine learning batch job.

### Technology Choice: MinIO & Dask vs Hadoop & Spark

- **MinIO** was chosen over Hadoop HDFS because it is lightweight, S3-compatible, and better suited to small-scale environments.
- **Dask** was chosen over Spark because it integrates easily with Python ML libraries and has lower resource requirements.
- Together, these technologies fulfill the requirements while respecting quota constraints.
- Larger-scale Hadoop/Spark deployments would be used in production scenarios.

### Implementation

- To implement Tasks 4 and 5, the base scripts (`master.sh`, `worker.sh`) have to be **reduced to the K3s setup only**, so that three plain Kubernetes instances can be provisioned without extra components. The required services (MinIO, Dask, Kafka, Faust) will then be installed declaratively on top of this cluster. This procedure is also shown in the screencast `task4_v1`.

- MinIO and Dask were installed via Helm.

- The MinIO client (`mc`) was configured for interaction.

- The Helm values and variable descriptions can be found in the [external configuration repository](https://github.com/silasschroeder/files).
  Users can consult this to adjust fields when filling in required parameters.

- The dataset used was the [Wisconsin Breast Cancer Diagnostic dataset](https://archive.ics.uci.edu/dataset/17/breast+cancer+wisconsin+diagnostic).

  - The CSV was **not reduced artificially**; rather, it is inherently small (570 lines).
  - Although the task required “non-trivial” data, we deliberately chose this dataset to respect strict storage quotas.

- A batch job (`images/batch-processing/app.py`) trained a **Naïve Bayes classifier** with Dask-ML.

- The resulting model parameters were stored in MinIO (`models/naive_bayes_params.json`).

---

## Task 5 — Stream Processing

**Goal**: Process real-time data streams with Kafka, provide horizontal scalability, and integrate with the previously trained model.

### Technology Choice: Kafka & Faust vs Alternatives

- **Kafka** was chosen as the ingestion cluster due to its robustness and popularity.

- **Faust** was selected as the stream processor because of its Pythonic interface and integration with Kafka.

- **KEDA** was used for autoscaling based on Kafka lag. Unlike the built-in HPA, which only supports CPU and memory metrics, KEDA makes it possible to scale workloads based on the number of unprocessed Kafka messages.

- Alternatives like Flink or Spark Streaming were considered, but Faust + Kafka was simpler to integrate with the batch-trained model.

### Implementation

- Kafka was installed with the Strimzi operator.
- Faust-based stream processor consumed incoming feature data, applied the Naïve Bayes model, and produced predictions.
- An Express-based front end (`images/pfisterer-front-end`) provided a user interface.
- A load generator (`images/demo-keda/app.py`) was used for stress testing and autoscaling validation.

---

## Architecture Summary

- **Infrastructure**: OpenTofu on OpenStack (master + workers).
- **Cluster**: K3s Kubernetes distribution.
- **Application**: Stateful app deployed on Kubernetes.
- **Monitoring**: Prometheus with HPA demo.
- **Data Lake**: MinIO object storage.
- **Batch Processing**: Dask-based Naïve Bayes training.
- **Streaming**: Kafka (Strimzi) with Faust for real-time classification.
- **Autoscaling**: KEDA driven by Kafka lag.

---

## Reproducibility

1. Provision infrastructure:

   ```sh
   cd task_1
   source env.sh
   tofu init
   tofu apply -auto-approve
   ```

2. Connect to master and use workflows as **guides**:

   - `workflow1-3.sh` (Tasks 1–3)
   - `workflow4-5.sh` (Tasks 4–5)

3. Validate results via screencasts and manual checks.

---

## Screencasts

Short, compressed screencasts are included in the submission ZIP. They demonstrate:

- Immutable updates with OpenTofu.
- Kubernetes cluster setup and monitoring with Prometheus.
- Horizontal scaling of the stateful app.
- Batch training with Dask and storage of model parameters in MinIO.
- Stream processing with Kafka, Faust, and autoscaling via KEDA.
