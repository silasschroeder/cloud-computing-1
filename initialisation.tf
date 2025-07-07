variable "master_count" {
  default = 1
}

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

resource "openstack_compute_instance_v2" "master_nodes" {
  count           = var.master_count
  name            = "mjcs2-k8s-master" //-${count.index}"
  image_id        = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name     = "mb1.small"
  security_groups = ["default"]
  key_pair        = "silasschroeder"
  user_data       = file("${path.module}/MasterWorkerStructure/master.sh")

  network {
    name = "provider_912"
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.network.0.fixed_ip_v4}" # Remove old host key
  }
  provisioner "local-exec" { # write ip to file
    command = "echo ${self.network.0.fixed_ip_v4} > ${path.module}/MasterWorkerStructure/k8s_master_ip.txt"
  }
}

resource "openstack_compute_instance_v2" "worker_nodes" {
  count           = var.worker_count
  name            = "mjcs2-k8s-worker-${count.index}"
  image_id        = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name     = "mb1.small"
  security_groups = ["default"]
  key_pair        = "silasschroeder"
  user_data       = <<-EOF
#!/bin/bash
set -e
curl -L https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh -o /tmp/bootstrap-salt.sh
chmod +x /tmp/bootstrap-salt.sh
sudo /tmp/bootstrap-salt.sh -A ${openstack_compute_instance_v2.master_nodes[0].network.0.fixed_ip_v4}
EOF
  provisioner "local-exec" {
    command = "ssh-keygen -R ${self.network.0.fixed_ip_v4}" # Remove old host key
  }
  network {
    name = "provider_912"
  }

  depends_on = [openstack_compute_instance_v2.master_nodes] # Ensure master is created first
}
