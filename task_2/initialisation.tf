variable "worker_count" {
  default = 2
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
  name            = "mjcs2-k8s-master" //-${count.index}"
  image_id        = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name     = "mb1.small"
  security_groups = ["default"]
  key_pair        = "Jonas Public"

  network {
    name = "DHBW"
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.network.0.fixed_ip_v4} || true" # Eliminates the problem of being unable to ssh to the VM
  }
}

resource "openstack_compute_instance_v2" "worker_nodes" {
  count           = var.worker_count
  name            = "mjcs2-k8s-worker-${count.index}"
  image_id        = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name     = "mb1.small"
  security_groups = ["default"]
  key_pair        = "Jonas Public"

  network {
    name = "DHBW"
  }

  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.network.0.fixed_ip_v4} || true" # Eliminates the problem of being unable to ssh to the VM
  }

  depends_on = [openstack_compute_instance_v2.master] # Ensure master is created first
}

resource "local_file" "floating_ip" {
  content  = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
  filename = "${path.module}/openstack-inventory.txt"
}

# Output for easier access
output "master_ip" {
  value = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
}
