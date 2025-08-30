# Cloud Computing and Big Data

This repository is part of the examination requirements for the module **Cloud Computing and Big Data**. It serves to convey the objectives and to document the commands used by the group **mjcs2** to achieve these objectives. Members of this group are Maya Seifert (`8252799`), Jonas Giessler (`TODO`), Christian Fischer (`3105350`), Sarah Wonke (`8926805`), and Silas Schröder (`1653329`).

TODO: Installation tofu  
TODO: All steps can be followed via the screencasts  
TODO: Each task has its own folder

## Task 1

TODO: Immutable update demo

### Preliminary Notes

The evaluation criteria for Task 1 are technology selection, application complexity, completeness of documentation, as well as innovation and efficiency of the implementation.

As an alternative to Terraform, the group decided to use [OpenTofu](https://opentofu.org) for the following three reasons:

1. `.tf` files can be used by both Terraform, the technology introduced in the lecture, and OpenTofu. This makes transferring the application from the lecture to the portfolio straightforward.
2. OpenTofu is open source software, whereas the Terraform source code is not publicly accessible. This makes OpenTofu more trustworthy than Terraform.
3. OpenTofu is an actively maintained tool. At the time of writing this document (August 30, 2025, 10:53 AM), the [latest commit](https://github.com/opentofu/opentofu/commit/28493bc63f83aaa5fb2ff5063f050d80f9c51f4f) on the associated [GitHub repository](https://github.com/opentofu/opentofu) was 6 hours old.

To meet the requirement of application complexity, and as suggested in the assignment, a stateful application will be implemented. The goal is to simultaneously meet the requirements for Task 2 and Task 3. Therefore, the application itself will only be presented in Section 3.

### Implementation

When located in the project directory, the corresponding folder for Task 1 must be used. This folder contains `env.sh` and `initialisation.tf`. `env.sh` includes the environment variables required to access the OpenStack of DHBW Mannheim. Normally, environment variables are used to avoid publishing credentials in a repository. However, in order to make the workflow reproducible, the environment variables are provided here. `initialisation.tf` contains the actual script to start three instances: one master and two workers. Relevant configurations for execution are:

- `worker_count`: Variable defining the number of worker nodes. Can be adjusted as needed.
- `depends_on`: Variable in the worker nodes ensuring that the master already exists before the workers join the application cluster. More on this in Task # **TODO**.
- `user_data`: References `.sh` files that are executed on the instance upon startup. This becomes relevant in Task 2.
- `key_pair`: Must be set to a personal key pair for both the master and the worker nodes to enable SSH access to the machines.
- `provisioner "local-exec"`: When establishing an SSH connection to an instance, the following issue may occasionally appear: ![identification-problem](https://raw.githubusercontent.com/silasschroeder/files/main/images/identification-problem.png). This block addresses the problem.

All other configurations only determine the name, resources, and key of the instances. Execution is carried out using the following commands:

```sh
cd task_1
source env.sh
tofu init
tofu apply -auto-approve
```

After approximately three minutes, all instances are active. If `key_pair` or `user_data` in `initialisation.tf` is deleted or modified, the immutability of the instances can be demonstrated by running `tofu plan`. The output will be:

```
Plan: 2 to add, 0 to change, 2 to destroy.
```

This shows that the instances must be rebuilt during an update. However, the output of `tofu plan` when changing `image_id` or `flavor_name` looks like this:

```
Plan: 0 to add, 2 to change, 0 to destroy.
```

This behavior is due to the OpenStack API, which supports resize and rebuild operations. These operations contradict the principle of immutability. Restarting an instance when changing the mentioned attributes can be enforced using the `lifecycle { replace_triggered_by=[...] }` block. For the continuation of the project, however, this is not relevant, and therefore it was omitted.

## Task 2

Aufgabe 2 fordert das Installieren einer Anwendung, die Versionierung dieser, das Versionieren der Infrastruktur, ein erfolgreiches Rollback, das Löschen alter Infrastrukturversionen, sowie umfangreiche Dokumentation.

Zur verfügung stehende, versionierte Anwendungen:

- silasschroeder/stateful-app:v1.1
- silasschroeder/stateful-app:v1.2
- silasschroeder/stateful-app:v1.3

## Task 3

A multi-node Kubernetes infrastructure must be deployed on the OpenStack environment, hosting a containerized and versionable application with scalability and external accessibility.

In order to use kubernetes, the distro utulize
