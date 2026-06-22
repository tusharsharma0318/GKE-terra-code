terraform {
  backend "gcs" {
    bucket = "tus-terraform-state"
    prefix = "terra-gkestatefile"
  }
}