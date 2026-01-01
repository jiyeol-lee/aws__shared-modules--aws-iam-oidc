output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for GitHub Actions"
  value       = local.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the IAM OIDC provider"
  value       = local.oidc_provider_url
}

output "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.name
}

output "role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "role_id" {
  description = "Unique ID of the IAM role"
  value       = aws_iam_role.github_actions.id
}

output "policy_names" {
  description = "List of custom policy names attached to the role"
  value       = [for policy in aws_iam_policy.custom : policy.name]
}

output "policy_arns" {
  description = "List of custom policy ARNs attached to the role"
  value       = [for policy in aws_iam_policy.custom : policy.arn]
}

output "github_repositories" {
  description = "List of GitHub repositories allowed to assume this role"
  value       = var.github_repositories
}
