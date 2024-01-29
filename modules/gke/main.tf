# Create GKE cluster with 2 nodes in our custom VPC/Subnet
resource "google_container_cluster" "primary" {
  project                  = var.project_id
  name                     = var.gke_name
  location                 = var.region
  network                  = var.network
  subnetwork               = var.subnet_name
  remove_default_node_pool = false ## create the smallest possible default node pool and immediately delete it.

  initial_node_count = 1


  private_cluster_config {
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  
    ip_allocation_policy {
    // Choose the range, but let GCP pick the IPs within the range
    cluster_ipv4_cidr_block   = ""
    services_ipv4_cidr_block  = ""
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
      display_name = cidr_blocks.value.display_name
      cidr_block   = cidr_blocks.value.cidr_block
    }
}
}
}











