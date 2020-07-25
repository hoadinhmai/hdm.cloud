locals {
  tags = {
    service = var.pipeline_name
    owner   = "HDM"
  }

  stages = {
    dev = {
      branch = "develop"
    }

    prod = {
      branch = "master"
    }
  }

  stage = "${local.stages[var.stage]}"
}
