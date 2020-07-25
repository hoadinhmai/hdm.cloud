variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "stage" {
  type = string
}

variable "pipeline_name" {
  type    = string
  default = "hdm-cloud"
}

variable "github_username" {
  type    = string
  default = "hoadinhmai"
}

variable "github_repo" {
  type    = string
  default = "hdm.cloud"
}