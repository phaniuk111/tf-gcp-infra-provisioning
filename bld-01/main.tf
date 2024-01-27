module "vpc" {
  source                  = "../modules/network/vpc"
  project_id              = var.project_id
  name                    = var.name
  description             = var.description
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = var.routing_mode
}