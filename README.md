# AWS IAM OIDC Module for GitHub Actions

Terraform module for creating an IAM OIDC provider and role for GitHub Actions authentication. This enables GitHub Actions workflows to securely access AWS resources without storing long-lived credentials.

## Key Benefits

- **No Long-Lived Credentials**: Eliminates the need for AWS access keys in GitHub secrets
- **Automatic Credential Rotation**: OIDC tokens are short-lived and automatically rotated
- **Repository Scoping**: Trust policy restricts access to specific repositories
- **Enhanced Security**: Follows AWS security best practices for federated identity
- **GitOps-Friendly**: Works seamlessly with GitHub Actions deployment workflows

## Usage

### Basic Example

```hcl
module "github_actions_oidc" {
  source = "git@github.com:your-org/aws__shared-modules--iam-oidc.git"

  role_name = "my-app-github-actions"
  github_repositories = [
    "my-org/my-repo"
  ]
}
```

### Multiple Repositories

```hcl
module "github_actions_oidc" {
  source = "git@github.com:your-org/aws__shared-modules--iam-oidc.git"

  role_name = "platform-github-actions"
  github_repositories = [
    "my-org/frontend-app",
    "my-org/backend-api",
    "my-org/shared-infrastructure"
  ]

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
}
```

### With Custom Policies

```hcl
# Define policy using data block (recommended)
data "aws_iam_policy_document" "s3_deploy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::my-bucket",
      "arn:aws:s3:::my-bucket/*"
    ]
  }
}

data "aws_iam_policy_document" "cloudfront_invalidation" {
  statement {
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations"
    ]
    resources = ["arn:aws:cloudfront::*:distribution/ABCD1234"]
  }
}

module "github_actions_oidc" {
  source = "git@github.com:your-org/aws__shared-modules--iam-oidc.git"

  role_name = "static-site-deployer"
  github_repositories = [
    "my-org/static-site"
  ]

  custom_policies = {
    "s3-deploy"               = data.aws_iam_policy_document.s3_deploy.json
    "cloudfront-invalidation" = data.aws_iam_policy_document.cloudfront_invalidation.json
  }

  tags = {
    Project     = "static-site"
    Environment = "production"
  }
}
```

## GitHub Actions Workflow

After deploying this module, configure your GitHub Actions workflow:

```yaml
name: Deploy

on:
  push:
    branches: [main]

# Required: Grant OIDC token permissions
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/my-app-github-actions
          aws-region: us-east-1

      - name: Verify AWS access
        run: aws sts get-caller-identity

      - name: Deploy to S3
        run: |
          npm run build
          aws s3 sync dist/ s3://my-bucket --delete

      - name: Invalidate CloudFront cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ABCD1234 \
            --paths "/*"
```

### Key Workflow Requirements

1. **permissions: id-token: write** - Required for GitHub to generate OIDC tokens
2. **aws-actions/configure-aws-credentials@v4** - Official AWS action for OIDC authentication
3. **role-to-assume** - ARN of the IAM role created by this module

## Inputs

| Name                 | Description                                                                             | Type           | Default                                                                     | Required |
| -------------------- | --------------------------------------------------------------------------------------- | -------------- | --------------------------------------------------------------------------- | :------: |
| role_name            | Name of the IAM role for GitHub Actions                                                 | `string`       | `"github-actions-role"`                                                     |    no    |
| role_description     | Description for the IAM role                                                            | `string`       | `"IAM role for GitHub Actions OIDC authentication"`                         |    no    |
| github_repositories  | List of GitHub repositories allowed to assume this role (format: owner/repo)            | `list(string)` | n/a                                                                         |   yes    |
| custom_policies      | Map of custom IAM policy names to their JSON policy documents                           | `map(string)`  | `{}`                                                                        |    no    |
| managed_policy_arns  | List of AWS managed policy ARNs to attach to the role                                   | `list(string)` | `[]`                                                                        |    no    |
| max_session_duration | Maximum session duration in seconds (900-43200)                                         | `number`       | `3600`                                                                      |    no    |
| create_oidc_provider | Whether to create the GitHub OIDC provider. Set to false if the provider already exists | `bool`         | `true`                                                                      |    no    |
| tags                 | Tags to apply to all resources                                                          | `map(string)`  | `{"ManagedBy": "Terraform", "RootModule": "aws__shared-modules--iam-oidc"}` |    no    |

## Outputs

| Name                | Description                                             |
| ------------------- | ------------------------------------------------------- |
| oidc_provider_arn   | ARN of the IAM OIDC provider for GitHub Actions         |
| oidc_provider_url   | URL of the IAM OIDC provider                            |
| role_name           | Name of the IAM role for GitHub Actions                 |
| role_arn            | ARN of the IAM role for GitHub Actions                  |
| role_id             | Unique ID of the IAM role                               |
| policy_names        | List of custom policy names attached to the role        |
| policy_arns         | List of custom policy ARNs attached to the role         |
| github_repositories | List of GitHub repositories allowed to assume this role |

## Security Best Practices

### Repository Scoping

Always specify exact repository names in the trust policy:

```hcl
# Good: Specific repositories
github_repositories = ["my-org/my-repo"]

# Avoid: Never use wildcards for organization
# This would allow ANY repo in the org to assume the role
```

**Note on Branch/Environment Filtering**: The default trust policy uses `repo:owner/repo:*` which allows all branches and environments. For stricter control (e.g., only allowing `main` branch or specific environments), you would need to customize the trust policy. Common patterns:

- `repo:owner/repo:ref:refs/heads/main` - Only main branch
- `repo:owner/repo:environment:production` - Only production environment

### Session Duration

Use the minimum session duration needed for your workflows:

```hcl
# Default: 1 hour (usually sufficient)
max_session_duration = 3600

# Extended: Only if workflows require longer
max_session_duration = 7200  # 2 hours
```

## Related Documentation

- [GitHub Actions: Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS: Creating IAM OIDC identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
