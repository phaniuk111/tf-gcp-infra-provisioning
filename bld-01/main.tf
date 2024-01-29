module "vpc" {
  source                  = "../modules/network/vpc"
  project_id              = "flash-keel-412418"
  name                    = "dev-vpc"
  description             = "VPC for Developer"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}


module "subnet" {
  source                       = "../modules/network/subnet"
  subnet_name                  = "dev-subnet"
  network                      = module.vpc.name
  project_id                   = "flash-keel-412418"
  region                       = "europe-west2"
  kubernetes_network_ipv4_cidr = "10.10.0.0/24"
  depends_on                   = [module.vpc]
}

module "gke" {
  source      = "../modules/gke"
  gke_name    = "wordspres-gke-euwe2"
  subnet_name = module.subnet.name
  project_id  = "flash-keel-412418"
  network     = module.vpc.name
  region      = "europe-west2"
  master_authorized_networks = [
    {
      display_name = "jenkins"
      cidr_block   = "34.175.175.22/32"
    },
    {
      display_name = "shell"
      cidr_block   = "34.78.220.0/22"
     
    }
  ]
  depends_on = [module.vpc, module.subnet]
}