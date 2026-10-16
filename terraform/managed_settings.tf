# Claude Code managed settings, rendered with the real ARNs.
# Write them out with:
#   terraform output -json managed_settings_bedrock | jq -r '.platform' > managed-settings.json
# and deliver per team through MDM (see ../managed-settings/README.md).

locals {
  guardrail_id = element(split("/", var.guardrail_arn), length(split("/", var.guardrail_arn)) - 1)

  common_policy = {
    permissions = {
      disableBypassPermissionsMode = "disable"
    }
  }

  # Every alias (/model opus, sonnet, haiku) must resolve to a team profile:
  # built-in model IDs are denied by IAM. Roles not defined fall back to primary.
  profile_arn = {
    for team in var.teams : team => {
      for role in ["primary", "opus", "sonnet", "background"] : role =>
      aws_bedrock_inference_profile.team["${team}-${contains(keys(var.models), role) ? role : "primary"}"].arn
    }
  }

  bedrock_settings = {
    for team in var.teams : team => jsonencode(merge(local.common_policy, {
      awsAuthRefresh = "aws sso login --profile ${var.sso_profile_name}"
      env = {
        CLAUDE_CODE_USE_BEDROCK        = "1"
        AWS_PROFILE                    = var.sso_profile_name
        AWS_REGION                     = var.region
        ANTHROPIC_MODEL                = local.profile_arn[team].primary
        ANTHROPIC_DEFAULT_OPUS_MODEL   = local.profile_arn[team].opus
        ANTHROPIC_DEFAULT_SONNET_MODEL = local.profile_arn[team].sonnet
        ANTHROPIC_DEFAULT_HAIKU_MODEL  = local.profile_arn[team].background
        ANTHROPIC_CUSTOM_HEADERS       = "X-Amzn-Bedrock-GuardrailIdentifier: ${local.guardrail_id}\nX-Amzn-Bedrock-GuardrailVersion: ${var.guardrail_version}"
      }
    }))
  }

  claudeai_settings = jsonencode(merge(local.common_policy, {
    forceLoginMethod  = "claudeai"
    forceLoginOrgUUID = var.claude_org_uuid
  }))
}
