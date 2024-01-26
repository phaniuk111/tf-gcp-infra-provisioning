terraform {
  backend "gcs" {
    bucket = "flash-keel-412418-tfstate-tfstate"
    prefix = "bld-01"
  }
}