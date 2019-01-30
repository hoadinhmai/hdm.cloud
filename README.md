# hdm.cloud
A personal serverless website

## Architecture
1. CloudFormation provisions S3 bucket and set Route53 record fronted by Cloudflare
2. AWS CodePipeline sources https://github.com/hoadinhmai/hdm.cloud.git on commit to master branch
3. AWS CodeBuild syncs contents to S3 bucket

## Terraform usage
Provision AWS CodePipeline and CodeBuild project
`terraform apply -var "github_token=token"`

## Container usage
Each commit to master triggers a Gitlab CI build of a new Docker image (Nginx:alpine + static content). Image is pushed to Gitlab registry and ready to be consumed by ECS Fargate CloudFormation deployment.

## Packer & Ansible usage
packer.json template provisions an AMI with Nginx pre-installed via Ansible to host static content.
