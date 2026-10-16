output "groups" {
  description = "Identity Center group per plan."
  value       = { for k, g in aws_identitystore_group.plan : k => g.display_name }
}

output "inference_profiles" {
  description = "Application inference profile ARN per team and model role."
  value       = { for k, p in aws_bedrock_inference_profile.team : k => p.arn }
}

output "permission_set_arn" {
  description = "ARN of the ClaudeCodeBedrock permission set."
  value       = aws_ssoadmin_permission_set.claude_code_bedrock.arn
}

output "managed_settings_bedrock" {
  description = "Claude Code managed-settings.json per team for the bedrock plan."
  value       = local.bedrock_settings
}

output "managed_settings_claudeai" {
  description = "Claude Code managed-settings.json for the team plan."
  value       = local.claudeai_settings
}

output "users_by_plan" {
  description = "Current plan of each user."
  value = {
    for plan in keys(local.plans) : plan => sort([for name, u in var.users : name if u.plan == plan])
  }
}
