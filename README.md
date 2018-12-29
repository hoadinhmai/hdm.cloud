# hdm.cloud
A personal serverless website

## Architecture
1. CloudFormation provisions S3 bucket and set Route53 record fronted by Cloudflare
2. AWS CodePipeline sources https://github.com/hoadinhmai/hdm.cloud.git on commit to master branch
3. AWS CodeBuild syncs contents to S3 bucket