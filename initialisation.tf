variable "worker_count" {
  default = 2
}

variable "app_version" {
  description = "Version of the sample application to deploy"
  type        = string
  default     = "1.0.0"
}

variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 3
}

variable "min_replicas" {
  description = "Minimum number of replicas for autoscaling"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of replicas for autoscaling"
  type        = number
  default     = 10
}

variable "infrastructure_version" {
  description = "Version tag for the infrastructure deployment"
  type        = string
  default     = "v1.0.0"
}

# Define required providers
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

resource "openstack_compute_instance_v2" "master" {
  name            = "mjcs2-k8s-master-${var.infrastructure_version}" //-${count.index}"
  image_id        = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name     = "mb1.small"
  security_groups = ["default"]
  key_pair        = "silasschroeder"
  user_data       = file("${path.module}/master.sh")

  network {
    name = "provider_912"
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.network.0.fixed_ip_v4}" # Eliminates the problem of being unable to ssh to the VM
  }

  tags = [
    "version:${var.infrastructure_version}",
    "app_version:${var.app_version}"
  ]
}

resource "openstack_compute_instance_v2" "worker_nodes" {
  count           = var.worker_count
  name            = "mjcs2-k8s-worker-${count.index}-${var.infrastructure_version}"
  image_id        = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name     = "mb1.small"
  security_groups = ["default"]
  key_pair        = "silasschroeder"
  user_data = templatefile("${path.module}/worker.sh", {
    master_ip = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
  })

  network {
    name = "provider_912"
  }

  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.network.0.fixed_ip_v4}" # Eliminates the problem of being unable to ssh to the VM
  }

  depends_on = [openstack_compute_instance_v2.master] # Ensure master is created first

  tags = [
    "version:${var.infrastructure_version}",
    "app_version:${var.app_version}"
  ]
}

# Generate the k8s manifest with current variables
resource "local_file" "k8s_manifest" {
  content = templatefile("${path.module}/k8s-manifests/sample-app.yaml.tpl", {
    master_ip    = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
    app_version  = var.app_version
    app_replicas = var.app_replicas
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
  })
  filename = "${path.module}/k8s-entities-${var.infrastructure_version}.yaml"
}

# Output values for reference
output "master_ip" {
  value = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
}

output "infrastructure_version" {
  value = var.infrastructure_version
}

output "app_version" {
  value = var.app_version
}

output "k8s_manifest_file" {
  value = local_file.k8s_manifest.filename
}
