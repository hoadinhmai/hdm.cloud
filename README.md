# hdm.cloud
A simple personal website hosted on Amazon S3.

## Architecture
1. CloudFormation creates an S3 bucket and set a Route53 record fronted by Cloudflare
2. AWS CodePipeline sources https://github.com/hoadinhmai/hdm.cloud.git on commit to master branch
3. AWS CodeBuild syncs contents to S3 bucket

## Terraform usage
Creates a CodePipeline and CodeBuild project for deploying static content to S3  
```cd terraform && make infra stage=<dev\prod>```

## Container usage
Each commit to master triggers a Gitlab CI build of a new Docker image (Nginx:alpine + static content).  
Image is pushed to Gitlab registry and ready to be consumed by ECS Fargate CloudFormation deployment.

## Packer & Ansible usage
packer.json template provisions an AMI with Nginx pre-installed via Ansible to host static content on EC2.
