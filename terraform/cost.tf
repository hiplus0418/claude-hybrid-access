# Per-team budgets use the Team tag on the application inference profiles.
# Activate "Team" as a cost allocation tag in the management account first
# (Billing > Cost allocation tags); it appears there after the first usage.
resource "aws_budgets_budget" "team" {
  for_each = toset(var.teams)

  name         = "${var.name_prefix}-${each.key}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.team_monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:Team$%s", each.key)]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }
}

# Who uses the most? Identity Center sessions are named after the user,
# so identity.arn ends with the user name:
#   arn:aws:sts::<acct>:assumed-role/AWSReservedSSO_ClaudeCodeBedrock_<id>/<user>
resource "aws_cloudwatch_query_definition" "usage_by_user" {
  name            = "${var.name_prefix}/usage-by-user"
  log_group_names = [var.invocation_log_group_name]

  query_string = <<-EOT
    fields identity.arn, modelId, input.inputTokenCount, output.outputTokenCount
    | filter identity.arn like /AWSReservedSSO_ClaudeCodeBedrock_/
    | parse identity.arn "assumed-role/*/*" as role, user
    | stats sum(input.inputTokenCount) as input_tokens,
            sum(output.outputTokenCount) as output_tokens,
            count(*) as calls
            by user, modelId
    | sort output_tokens desc
  EOT
}

resource "aws_cloudwatch_query_definition" "daily_active_users" {
  name            = "${var.name_prefix}/daily-active-users"
  log_group_names = [var.invocation_log_group_name]

  query_string = <<-EOT
    fields identity.arn
    | filter identity.arn like /AWSReservedSSO_ClaudeCodeBedrock_/
    | parse identity.arn "assumed-role/*/*" as role, user
    | stats count_distinct(user) as active_users by bin(1d)
  EOT
}
