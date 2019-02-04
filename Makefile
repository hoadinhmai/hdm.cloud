.PHONY: *
SHELL := '/bin/bash'

terraform-init:
	cd terraform && terraform init

terraform-upgrade:
	cd terraform && terraform init -upgrade

terraform-validate:
	@cd terraform && terraform validate -var "github_token=$(GITHUB_TOKEN)"

terraform-apply:
	@cd terraform && terraform apply -var "github_token=$(GITHUB_TOKEN)" -auto-approve

terraform-destroy:
	@cd terraform && terraform destroy -var "github_token=$(GITHUB_TOKEN)"