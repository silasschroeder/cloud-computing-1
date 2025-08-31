# Define number of worker nodes (default: 2)
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
  name            = "mjcs2-k8s-master"                     # Name of the VM
  image_id        = "c57c2aef-f74a-4418-94ca-d3fb169162bf" # ID of image to use (Ubuntu 22.04)
  flavor_name     = "mb1.medium"                           # Defines VM resources 
  security_groups = ["default"]                            # Applies defined security groups
  key_pair        = "silasschroeder"                       # CHANGE TO YOUR KEYPAIR

  # Path to user data script (will be executed on first boot)
  user_data = file("${path.module}/nodes/master.sh")

  network {
    name = "DHBW" # Network the VM is attached to
  }

  # Eliminates the problem of being unable to ssh to the VM due to changed host keys
  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.network.0.fixed_ip_v4}"
  }
}

resource "openstack_compute_instance_v2" "worker_nodes" {
  count           = var.worker_count                       # Number of worker nodes to create
  name            = "mjcs2-k8s-worker-${count.index}"      # Name of the VM
  image_id        = "c57c2aef-f74a-4418-94ca-d3fb169162bf" # ID of image to use (Ubuntu 22.04)
  flavor_name     = "mb1.small"                            # Defines VM resources 
  security_groups = ["default"]                            # Applies defined security groups
  key_pair        = "silasschroeder"                       # CHANGE TO YOUR KEYPAIR

  # Uses a template file to pass the master's IP to the worker's user data script
  user_data = templatefile("${path.module}/nodes/worker.sh", {
    master_ip = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
  })

  network {
    name = "DHBW" # Network the VM is attached to
  }

  # Eliminates the problem of being unable to ssh to the VM due to changed host keys
  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.network.0.fixed_ip_v4}"
  }

  # Ensure master is created first
  depends_on = [openstack_compute_instance_v2.master]
}

# Write the master's floating IP to a local file for easy access
resource "local_file" "floating_ip" {
  content  = openstack_compute_instance_v2.master.network.0.fixed_ip_v4
  filename = "${path.module}/openstack-inventory.txt"
}
