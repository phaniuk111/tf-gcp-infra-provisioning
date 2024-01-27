variable "project_id" {
  type        = string
  description = "ID of a Google Cloud Project"
}

variable "name" {
  type        = string
  description = "name of the VPC"
}

variable "auto_create_subnetworks" {
  type    = bool
  default = false
}

variable "description" {
  type = string
}

variable "routing_mode" {
  type = string
}


variable "region" {}
variable "kubernetes_network_ipv4_cidr" {}

variable "gke_name" {}
variable "master_authorized_networks" {}
