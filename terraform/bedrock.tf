data "aws_caller_identity" "workload" {}

locals {
  account_id = data.aws_caller_identity.workload.account_id

  # One application inference profile per team and model role, tagged
  # with the team so Cost Explorer and Budgets can split the bill.
  team_models = {
    for pair in setproduct(var.teams, keys(var.models)) :
    "${pair[0]}-${pair[1]}" => { team = pair[0], role = pair[1], source = var.models[pair[1]] }
  }

  guardrail_version_arn = "${var.guardrail_arn}:${var.guardrail_version}"

  model_regions = distinct(concat([var.region], var.inference_destination_regions))
  foundation_model_arns = flatten([
    for r in local.model_regions : [
      for m in var.model_ids : "arn:aws:bedrock:${r}::foundation-model/${m}"
    ]
  ])

  allowed_invoke_arns = concat(
    [for p in aws_bedrock_inference_profile.team : p.arn],
    values(var.models),
    local.foundation_model_arns,
  )

  invoke_actions = [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream",
  ]
}

resource "aws_bedrock_inference_profile" "team" {
  for_each = local.team_models

  name        = "${var.name_prefix}-${each.value.team}-${each.value.role}"
  description = "Claude Code ${each.value.role} model for team ${each.value.team}"

  model_source {
    copy_from = each.value.source
  }

  tags = {
    Team = each.value.team
  }
}

# --- Permission set for the "bedrock" plan --------------------------------

data "aws_iam_policy_document" "claude_code_bedrock" {
  # Claude Code resolves profiles and checks model access at startup.
  statement {
    sid = "DiscoverProfiles"
    actions = [
      "bedrock:ListInferenceProfiles",
      "bedrock:GetInferenceProfile",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "InvokeWithPinnedGuardrail"
    actions   = local.invoke_actions
    resources = local.allowed_invoke_arns

    condition {
      test     = "StringEquals"
      variable = "bedrock:GuardrailIdentifier"
      values   = [local.guardrail_version_arn]
    }
  }

  statement {
    sid       = "ApplyGuardrail"
    actions   = ["bedrock:ApplyGuardrail"]
    resources = [var.guardrail_arn]
  }

  # Required by the Claude Code docs for first-time model subscription.
  statement {
    sid       = "MarketplaceViaBedrockOnly"
    actions   = ["aws-marketplace:ViewSubscriptions", "aws-marketplace:Subscribe"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:CalledViaLast"
      values   = ["bedrock.amazonaws.com"]
    }
  }

  statement {
    sid     = "DenyWithoutPinnedGuardrail"
    effect  = "Deny"
    actions = local.invoke_actions
    resources = [
      "arn:aws:bedrock:*::foundation-model/*",
      "arn:aws:bedrock:*:${local.account_id}:inference-profile/*",
      "arn:aws:bedrock:*:${local.account_id}:application-inference-profile/*",
    ]

    condition {
      test     = "StringNotEquals"
      variable = "bedrock:GuardrailIdentifier"
      values   = [local.guardrail_version_arn]
    }
  }

  statement {
    sid           = "DenyOtherModels"
    effect        = "Deny"
    actions       = local.invoke_actions
    not_resources = local.allowed_invoke_arns
  }
}

resource "aws_ssoadmin_permission_set" "claude_code_bedrock" {
  provider = aws.management

  name             = "ClaudeCodeBedrock"
  description      = "Claude Code through Bedrock: team inference profiles, mandatory guardrail."
  instance_arn     = local.sso_instance_arn
  session_duration = var.session_duration
}

resource "aws_ssoadmin_permission_set_inline_policy" "claude_code_bedrock" {
  provider = aws.management

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.claude_code_bedrock.arn
  inline_policy      = data.aws_iam_policy_document.claude_code_bedrock.json
}

resource "aws_ssoadmin_account_assignment" "claude_code_bedrock" {
  provider = aws.management

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.claude_code_bedrock.arn

  principal_type = "GROUP"
  principal_id   = aws_identitystore_group.plan["bedrock"].group_id

  target_type = "AWS_ACCOUNT"
  target_id   = local.account_id

  depends_on = [aws_ssoadmin_permission_set_inline_policy.claude_code_bedrock]
}
