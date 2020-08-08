.PHONY: *
SHELL := '/bin/bash'
	
init:
	terraform init --backend-config=config/${stage}.backend.tfvars

upgrade:
	terraform init -upgrade

validate:
	terraform validate

plan:
	terraform workspace select ${stage} || terraform workspace new ${stage}
	terraform plan -input=false -out=tfplan -var="stage=${stage}"

apply:
	terraform apply -input=false tfplan

destroy:
	terraform destroy -var="stage=${stage}"

infra: init plan apply stage=${stage}