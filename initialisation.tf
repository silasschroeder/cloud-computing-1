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

resource "openstack_compute_instance_v2" "tf_init" {
  name            = "mjcs2" # Maya, Jonas, Chris, Sarah, Silas
  image_id        = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name     = "mb1.small"
  security_groups = ["default"]

  network {
    name = "provider_912"
  }
}

resource "local_file" "floating_ip" {
  content  = openstack_compute_instance_v2.tf_init.network.0.fixed_ip_v4
  filename = "${path.module}/openstack-inventory.txt"
}
