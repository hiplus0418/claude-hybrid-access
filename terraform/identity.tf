# Groups and memberships live in the Identity Center directory.
# If your identity source is an external IdP (SCIM), manage these
# groups there instead and switch the resources below to data sources.

data "aws_ssoadmin_instances" "this" {
  provider = aws.management
}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  plans = {
    bedrock = "Claude Code through Amazon Bedrock, billed per token"
    team    = "Claude Team plan seat (claude.ai and Claude Code)"
  }
}

resource "aws_identitystore_group" "plan" {
  provider = aws.management
  for_each = local.plans

  identity_store_id = local.identity_store_id
  display_name      = "${var.name_prefix}-${each.key}"
  description       = each.value
}

data "aws_identitystore_user" "this" {
  provider = aws.management
  for_each = var.users

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = each.key
    }
  }
}

resource "aws_identitystore_group_membership" "plan" {
  provider = aws.management
  for_each = var.users

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.plan[each.value.plan].group_id
  member_id         = data.aws_identitystore_user.this[each.key].user_id
}

# Team plan: the Claude SAML app itself is console-only (no API for
# customer-managed SAML apps), but the group assignment can be managed here.
resource "aws_ssoadmin_application_assignment" "claude_team" {
  provider = aws.management
  count    = var.claude_saml_application_arn == null ? 0 : 1

  application_arn = var.claude_saml_application_arn
  principal_id    = aws_identitystore_group.plan["team"].group_id
  principal_type  = "GROUP"
}
