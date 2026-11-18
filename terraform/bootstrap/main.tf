terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "memos-terraform-state-435059220418"
  force_destroy = true

  tags = {
    Name    = "memos-terraform-state"
    Project = "Memos"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = var.github_oidc_provider_url
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_repository_subject]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Name    = var.github_actions_role_name
    Project = "Memos"
  }
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid = "TerraformBackend"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*"
    ]
  }

  statement {
    sid       = "ECRAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECR"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchDeleteImage",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:ListTagsForResource",
      "ecr:PutImage",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:UploadLayerPart"
    ]
    resources = ["arn:aws:ecr:eu-west-2:${data.aws_caller_identity.current.account_id}:repository/memos"]
  }

  statement {
    sid = "DatabaseRead"
    actions = [
      "rds:DescribeDBEngineVersions",
      "rds:DescribeDBInstances",
      "rds:DescribeDBSubnetGroups"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }

  statement {
    sid = "DatabaseManage"
    actions = [
      "rds:AddTagsToResource",
      "rds:CreateDBInstance",
      "rds:CreateDBSubnetGroup",
      "rds:DeleteDBInstance",
      "rds:DeleteDBSubnetGroup",
      "rds:ListTagsForResource",
      "rds:ModifyDBInstance",
      "rds:ModifyDBSubnetGroup",
      "rds:RemoveTagsFromResource"
    ]
    resources = [
      "arn:aws:rds:eu-west-2:${data.aws_caller_identity.current.account_id}:db:memos",
      "arn:aws:rds:eu-west-2:${data.aws_caller_identity.current.account_id}:subgrp:memos",
      "arn:aws:rds:eu-west-2:${data.aws_caller_identity.current.account_id}:pg:*",
      "arn:aws:rds:eu-west-2:${data.aws_caller_identity.current.account_id}:og:*",
      "arn:aws:rds:eu-west-2:${data.aws_caller_identity.current.account_id}:secgrp:*"
    ]
  }

  statement {
    sid       = "RdsServiceRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["rds.amazonaws.com"]
    }
  }

  statement {
    sid = "RdsManagedSecret"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:TagResource"
    ]
    resources = ["arn:aws:secretsmanager:eu-west-2:${data.aws_caller_identity.current.account_id}:secret:rds!db-*"]
  }

  statement {
    sid       = "DescribeSecretsManagerKey"
    actions   = ["kms:DescribeKey"]
    resources = ["arn:aws:kms:eu-west-2:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "kms:ResourceAliases"
      values   = ["alias/aws/secretsmanager"]
    }
  }

  statement {
    sid = "MemosSecretMetadata"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret"
    ]
    resources = ["arn:aws:secretsmanager:eu-west-2:${data.aws_caller_identity.current.account_id}:secret:memos/*"]
  }

  statement {
    sid       = "LogGroupRead"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["arn:aws:logs:eu-west-2:${data.aws_caller_identity.current.account_id}:log-group:*"]
  }

  statement {
    sid = "LogGroupManage"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DeleteRetentionPolicy",
      "logs:ListTagsForResource",
      "logs:ListTagsLogGroup",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup",
      "logs:TagResource",
      "logs:UntagLogGroup",
      "logs:UntagResource"
    ]
    resources = [
      "arn:aws:logs:eu-west-2:${data.aws_caller_identity.current.account_id}:log-group:/ecs/memos-task",
      "arn:aws:logs:eu-west-2:${data.aws_caller_identity.current.account_id}:log-group:/ecs/memos-task:*"
    ]
  }

  statement {
    sid       = "AlarmRead"
    actions   = ["cloudwatch:DescribeAlarms"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }

  statement {
    sid = "AlarmManage"
    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource"
    ]
    resources = ["arn:aws:cloudwatch:eu-west-2:${data.aws_caller_identity.current.account_id}:alarm:memos-*"]
  }

  statement {
    sid = "VpcEndpoints"
    actions = [
      "ec2:CreateVpcEndpoint",
      "ec2:DeleteVpcEndpoints",
      "ec2:DescribePrefixLists",
      "ec2:DescribeVpcEndpointServices",
      "ec2:DescribeVpcEndpoints",
      "ec2:ModifyVpcEndpoint"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }

  statement {
    sid = "IAMRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/memos-ecs-execution-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/memos-setup"
    ]
  }

  statement {
    sid = "IAMExecutionPolicy"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/memos-ecs-execution-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/memos-setup"
    ]

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
    }
  }

  statement {
    sid     = "PassTaskRoles"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/memos-ecs-execution-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/memos-setup"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "github_actions_compute" {
  statement {
    sid = "EC2Networking"
    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteNatGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVpc",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcs",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateAddress",
      "ec2:DisassociateRouteTable",
      "ec2:ModifySecurityGroupRules",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ReleaseAddress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }

  statement {
    sid = "ECSServices"
    actions = [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecs:DeleteCluster",
      "ecs:DeleteService",
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:ListTagsForResource",
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:TagResource",
      "ecs:UntagResource",
      "ecs:UpdateCluster",
      "ecs:UpdateService"
    ]
    resources = [
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:cluster/memos-cluster",
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:service/memos-cluster/memos-service",
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:task/memos-cluster/*",
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:task-definition/memos-task:*",
      "arn:aws:ecs:eu-west-2:${data.aws_caller_identity.current.account_id}:task-definition/memos-setup:*"
    ]
  }

  statement {
    sid = "ECSAccountLevel"
    actions = [
      "ecs:DeleteTaskDefinitions",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:ListServices",
      "ecs:ListTaskDefinitions",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }

  statement {
    sid = "Autoscaling"
    actions = [
      "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingActivities",
      "application-autoscaling:DescribeScalingPolicies",
      "application-autoscaling:ListTagsForResource",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:TagResource",
      "application-autoscaling:UntagResource"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }

  statement {
    sid = "LoadBalancerRead"
    actions = [
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth"
    ]
    resources = ["*"]
  }

  statement {
    sid = "LoadBalancerManage"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyListenerAttributes",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetWebAcl"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:eu-west-2:${data.aws_caller_identity.current.account_id}:loadbalancer/app/memos-alb/*",
      "arn:aws:elasticloadbalancing:eu-west-2:${data.aws_caller_identity.current.account_id}:listener/app/memos-alb/*",
      "arn:aws:elasticloadbalancing:eu-west-2:${data.aws_caller_identity.current.account_id}:targetgroup/memos-tg-5230/*"
    ]
  }

  statement {
    sid = "WebACL"
    actions = [
      "wafv2:AssociateWebACL",
      "wafv2:CreateWebACL",
      "wafv2:DeleteWebACL",
      "wafv2:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:ListTagsForResource",
      "wafv2:TagResource",
      "wafv2:UntagResource",
      "wafv2:UpdateWebACL"
    ]
    resources = [
      "arn:aws:wafv2:eu-west-2:${data.aws_caller_identity.current.account_id}:regional/webacl/memos-waf/*",
      "arn:aws:wafv2:eu-west-2:*:regional/managedruleset/*/*",
      "arn:aws:elasticloadbalancing:eu-west-2:${data.aws_caller_identity.current.account_id}:loadbalancer/app/memos-alb/*"
    ]
  }

  statement {
    sid       = "WebACLList"
    actions   = ["wafv2:ListWebACLs"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }

  statement {
    sid       = "WebACLLookup"
    actions   = ["wafv2:GetWebACLForResource"]
    resources = ["arn:aws:wafv2:eu-west-2:${data.aws_caller_identity.current.account_id}:regional/webacl/*/*"]
  }

  statement {
    sid = "Certificates"
    actions = [
      "acm:AddTagsToCertificate",
      "acm:DeleteCertificate",
      "acm:DescribeCertificate",
      "acm:GetCertificate",
      "acm:ListTagsForCertificate",
      "acm:RemoveTagsFromCertificate",
      "acm:RequestCertificate"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-2"]
    }
  }
}

resource "aws_iam_policy" "github_actions" {
  name        = "memos-github-actions-policy"
  description = "Permissions used by Memos GitHub Actions workflows"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json

  tags = {
    Name    = "memos-github-actions-policy"
    Project = "Memos"
  }
}

resource "aws_iam_policy" "github_actions_compute" {
  name        = "memos-github-actions-compute-policy"
  description = "Network, compute and load balancer permissions used by Memos GitHub Actions workflows"
  policy      = data.aws_iam_policy_document.github_actions_compute.json

  tags = {
    Name    = "memos-github-actions-compute-policy"
    Project = "Memos"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

resource "aws_iam_role_policy_attachment" "github_actions_compute" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_compute.arn
}

