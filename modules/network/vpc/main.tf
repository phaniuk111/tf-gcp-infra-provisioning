//VPC for Developer
resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.name
  description             = var.description
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = var.routing_mode
}