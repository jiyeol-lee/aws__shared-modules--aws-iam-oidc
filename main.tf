terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# -----------------------------------------------------------------------------
# GitHub OIDC Provider
# -----------------------------------------------------------------------------

# Get GitHub OIDC provider thumbprint (only when creating)
data "tls_certificate" "github" {
  count = var.create_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# Data source for existing OIDC provider (when not creating)
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# Create OIDC provider (when creating)
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github[0].certificates[0].sha1_fingerprint]

  tags = merge(var.tags, {
    Name      = "github-actions-oidc"
    ManagedBy = "Terraform"
  })
}

# Local to get the correct provider ARN
locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
  oidc_provider_url = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].url : data.aws_iam_openid_connect_provider.github[0].url
}

# -----------------------------------------------------------------------------
# IAM Role for GitHub Actions
# -----------------------------------------------------------------------------

# Trust policy (assume role policy)
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to specific GitHub repositories
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for repo in var.github_repositories : "repo:${repo}:*"]
    }
  }
}

# IAM Role
resource "aws_iam_role" "github_actions" {
  name                 = var.role_name
  description          = var.role_description
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Custom IAM Policies
# -----------------------------------------------------------------------------

# Create custom policies
resource "aws_iam_policy" "custom" {
  for_each = var.custom_policies

  name        = each.key
  description = "Custom policy for GitHub Actions: ${each.key}"
  policy      = each.value

  tags = var.tags
}

# Attach custom policies to the role
resource "aws_iam_role_policy_attachment" "custom" {
  for_each = aws_iam_policy.custom

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value.arn
}

# -----------------------------------------------------------------------------
# Managed IAM Policies
# -----------------------------------------------------------------------------

# Attach managed policies to the role
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}
