terraform {
  backend "s3" {
    key    = "hdm.cloud/terraform.tfstate"
    region = "ap-southeast-2"
  }
}