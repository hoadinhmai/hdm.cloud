provider "aws" {
  version = "~> 2.0"
  region = var.aws_region
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.pipeline_name}-codepipeline-bucket-${var.stage}"
  acl    = "private"
}

data "aws_ssm_parameter" "github_token" {
  name = "github_token"
}

data "aws_iam_policy_document" "codepipeline_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.pipeline_name}-codepipeline-role-${var.stage}"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_policy.json
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.pipeline_name}-codepipeline-policy-${var.stage}"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
    "Statement": [
        {
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketVersioning",
                "s3:PutObject"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "cloudwatch:*",
                "iam:PassRole"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ],
    "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role" "codebuild_assume_role" {
  name = "${var.pipeline_name}-codebuild-role-${var.stage}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    Service = local.tags["service"]
    Owner   = local.tags["owner"]
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.pipeline_name}-codebuild-policy"
  role = aws_iam_role.codebuild_assume_role.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
       "s3:PutObject",
       "s3:PutObjectAcl",
       "s3:DeleteObject",
       "s3:GetObject",
       "s3:GetObjectVersion",
       "s3:GetBucketVersioning"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Effect": "Allow",
      "Resource": [
        "${aws_codebuild_project.build_project.id}"
      ],
      "Action": [
        "codebuild:*"
      ]
    },
    {
      "Action": [
          "cloudformation:ValidateTemplate"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "ssm:GetParameters",
        "ssm:GetParameter",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    }
  ]
}
POLICY
}

resource "aws_codebuild_project" "build_project" {
  name          = "${var.pipeline_name}-codebuild-${var.stage}"
  description   = "CodeBuild project for ${var.pipeline_name} - ${var.stage}"
  service_role  = aws_iam_role.codebuild_assume_role.arn
  build_timeout = "30"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/nodejs:6.3.1"
    type         = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yaml"
  }
}

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.pipeline_name}-codepipeline-${var.stage}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner                = var.github_username
        OAuthToken           = data.aws_ssm_parameter.github_token.value
        Repo                 = var.github_repo
        Branch               = local.stage["branch"]
        PollForSourceChanges = "true"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["deployed"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }
}

resource "aws_sns_topic" "sns-topic" {
  name = "${var.pipeline_name}-sns-topic-${var.stage}"
}

data "aws_iam_policy_document" "iam-policy" {
  statement {
      sid = "TrustCloudWatchEvents"
      effect = "Allow"
      resources = ["${aws_sns_topic.sns-topic.arn}"]
      actions = ["sns:Publish"]
      principals {
          type = "Service"
          identifiers = ["events.amazonaws.com"]
      }
  }
}

resource "aws_sns_topic_policy" "topic-policy" {
  arn = aws_sns_topic.sns-topic.arn
  policy = data.aws_iam_policy_document.iam-policy.json
}

resource "aws_cloudwatch_event_rule" "event-rule" {
  name = "${var.pipeline_name}-cw-event-rule-${var.stage}"
  event_pattern = <<PATTERN
{
    "source": ["aws.codebuild"],
    "detail-type": ["CodeBuild Build State Change"],
    "detail": {
        "build-status": [
            "SUCCEEDED", 
            "FAILED",
            "STOPPED"
        ]
    }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "event_target" {
  target_id = "${var.pipeline_name}-cw-event-target-${var.stage}"
  rule = aws_cloudwatch_event_rule.event-rule.name
  arn = aws_sns_topic.sns-topic.arn
}