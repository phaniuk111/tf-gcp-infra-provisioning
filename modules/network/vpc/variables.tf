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
