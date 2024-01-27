# Create subnets
resource "google_compute_subnetwork" "subnetwork" {
  name          = var.subnet_name
  project       = var.project_id
  network       = var.network
  region        = var.region
  ip_cidr_range = var.kubernetes_network_ipv4_cidr

  private_ip_google_access = true
  /*
  secondary_ip_range {
    range_name    = "vault-pods"
    ip_cidr_range = var.kubernetes_pods_ipv4_cidr
  }

  secondary_ip_range {
    range_name    = "vault-svcs"
    ip_cidr_range = var.kubernetes_services_ipv4_cidr
  }
  */
}
