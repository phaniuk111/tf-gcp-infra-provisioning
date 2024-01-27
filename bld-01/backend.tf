terraform {
  backend "gcs" {
    bucket = "flash-keel-412418-tfstate"
    prefix = "bld-01"
  }
}