variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "claude"
}

variable "region" {
  description = "Bedrock region (source region for inference profiles)."
  type        = string
}

variable "workload_profile" {
  description = "AWS CLI profile for the workload account. null = default credential chain."
  type        = string
  default     = null
}

variable "identity_center_region" {
  description = "Region of the IAM Identity Center instance."
  type        = string
}

variable "management_profile" {
  description = "AWS CLI profile for the management / Identity Center delegated admin account."
  type        = string
  default     = null
}

# --- People --------------------------------------------------------------

variable "users" {
  description = <<-EOT
    Identity Center user name => { team, plan }.
    plan = "bedrock" (pay per token) or "team" (Claude Team seat).
    Moving someone between plans is a one-word change here.
  EOT
  type = map(object({
    team = string
    plan = string
  }))

  validation {
    condition     = alltrue([for u in values(var.users) : contains(["bedrock", "team"], u.plan)])
    error_message = "plan must be \"bedrock\" or \"team\"."
  }
}

variable "teams" {
  description = "Team names. Each Bedrock team gets its own tagged inference profiles for cost allocation."
  type        = list(string)
}

# --- Bedrock -------------------------------------------------------------

variable "models" {
  description = <<-EOT
    Model role => source ARN to copy into each team's application inference profile.
    Use system cross-region inference profile ARNs, from:
      aws bedrock list-inference-profiles --type-equals SYSTEM_DEFINED
    Roles: "primary" (default model, required), and optionally "opus", "sonnet"
    (targets of the /model aliases) and "background" (small/fast model).
    Roles you leave out fall back to the primary profile.
  EOT
  type        = map(string)

  validation {
    condition     = contains(keys(var.models), "primary")
    error_message = "models must contain a \"primary\" entry."
  }

  validation {
    condition     = alltrue([for k in keys(var.models) : contains(["primary", "opus", "sonnet", "background"], k)])
    error_message = "model roles must be primary, opus, sonnet or background."
  }
}

variable "model_ids" {
  description = "Foundation model IDs behind var.models, e.g. anthropic.claude-... (needed for IAM on the destination regions)."
  type        = list(string)
}

variable "inference_destination_regions" {
  description = "Regions the cross-region inference profiles route to."
  type        = list(string)
}

variable "guardrail_arn" {
  description = "Guardrail ARN (e.g. from bedrock-secure-access). Must have cross-Region inference enabled when using cross-region profiles."
  type        = string
}

variable "guardrail_version" {
  description = "Published numeric guardrail version enforced by IAM."
  type        = string
}

variable "session_duration" {
  description = "Session duration of the Bedrock permission set (ISO 8601)."
  type        = string
  default     = "PT8H"
}

variable "sso_profile_name" {
  description = "AWS CLI profile name users configure for Claude Code (used in the generated managed settings)."
  type        = string
  default     = "claude-bedrock"
}

# --- Claude Team plan ----------------------------------------------------

variable "claude_saml_application_arn" {
  description = "ARN of the Claude SAML application created in the Identity Center console (docs/saml-setup.md). null = assign the group in the console instead."
  type        = string
  default     = null
}

variable "claude_org_uuid" {
  description = "Claude organization UUID (claude.ai > Admin settings > Organization). Used in the generated managed settings."
  type        = string
}

# --- Cost ----------------------------------------------------------------

variable "team_monthly_budget_usd" {
  description = "Monthly Bedrock budget per team in USD."
  type        = number
  default     = 200
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts."
  type        = list(string)
}

variable "invocation_log_group_name" {
  description = "CloudWatch log group receiving Bedrock invocation logs (e.g. from bedrock-secure-access)."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    Project   = "claude-hybrid-access"
    ManagedBy = "terraform"
  }
}
