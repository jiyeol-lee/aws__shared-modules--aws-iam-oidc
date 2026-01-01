variable "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
  default     = "github-actions-role"
}

variable "role_description" {
  description = "Description for the IAM role"
  type        = string
  default     = "IAM role for GitHub Actions OIDC authentication"
}

variable "github_repositories" {
  description = "List of GitHub repositories allowed to assume this role (format: owner/repo)"
  type        = list(string)

  validation {
    condition     = length(var.github_repositories) > 0
    error_message = "At least one GitHub repository must be specified."
  }

  validation {
    condition     = alltrue([for repo in var.github_repositories : can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]*/[a-zA-Z0-9][a-zA-Z0-9._-]*$", repo))])
    error_message = "Each repository must be in 'owner/repo' format with valid GitHub naming (alphanumeric, dots, hyphens, underscores)."
  }
}

variable "custom_policies" {
  description = "Map of custom IAM policy names to their JSON policy documents. Each value must be valid IAM policy JSON."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.custom_policies : can(jsondecode(v))])
    error_message = "All custom_policies values must be valid JSON documents."
  }
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the role."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.managed_policy_arns : can(regex("^arn:aws:iam::(aws|[0-9]{12}):policy/", arn))])
    error_message = "All managed_policy_arns must be valid IAM policy ARNs (format: arn:aws:iam::ACCOUNT:policy/NAME or arn:aws:iam::aws:policy/NAME)."
  }
}

variable "max_session_duration" {
  description = "Maximum session duration (in seconds) for the assumed role. Must be between 900 (15 minutes) and 43200 (12 hours)."
  type        = number
  default     = 3600 # 1 hour

  validation {
    condition     = var.max_session_duration >= 900 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 900 (15 minutes) and 43200 (12 hours)."
  }
}

variable "create_oidc_provider" {
  description = "Whether to create the GitHub OIDC provider. Set to false if the provider already exists in your AWS account."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy  = "Terraform"
    RootModule = "aws__shared-modules--iam-oidc"
  }
}
