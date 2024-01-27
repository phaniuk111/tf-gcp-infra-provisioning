variable "gke_name" {}
variable "region" {}
variable "network" {}
variable "subnet_name" {}
variable "project_id" {}
variable "master_authorized_networks" {
  type = list(object({
    display_name = string
    cidr_block   = string
  }))
}


