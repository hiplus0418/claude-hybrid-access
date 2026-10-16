# Moving people between plans

Everyone starts on `bedrock` (pay per token). Move a person to `team` when a Claude Team seat costs less than their Bedrock usage — or when they want claude.ai features (web, desktop, projects).

## Deciding who to move

1. Run the saved CloudWatch Logs Insights query **`claude/usage-by-user`** for the last 30 days.
2. Estimate each heavy user's cost: tokens × your Bedrock price for that model (check AWS pricing; prompt caching lowers it).
3. Compare with the Team seat price for the plan you buy. Users clearly above it are candidates.
4. For team totals, use Cost Explorer grouped by the **Team** tag, or the per-team budgets.

## Bedrock → Team

| Step | Where | Change |
|---|---|---|
| 1 | `terraform.tfvars` | `plan = "bedrock"` → `plan = "team"`, then `terraform apply` (moves the group membership: Bedrock permission set off, Claude SAML app on). The plan shows the membership as replaced — 1 to destroy, 1 to add — which is expected |
| 2 | MDM | Deliver `managed_settings_claudeai` instead of the team's Bedrock settings |
| 3 | User | Run `claude`, log in with claude.ai SSO. Just-in-time provisioning creates the seat |

## Team → Bedrock

| Step | Where | Change |
|---|---|---|
| 1 | `terraform.tfvars` | `plan = "team"` → `plan = "bedrock"`, `terraform apply` |
| 2 | MDM | Deliver the team's Bedrock settings |
| 3 | **Claude admin settings** | **Remove the member to free the seat** (manual — no SCIM on Team) |
| 4 | User | `aws configure sso --profile claude-bedrock`, `aws sso login`, `claude` |

## Offboarding

| Step | Where | Effect |
|---|---|---|
| 1 | Identity Center | Disable the user (or remove from `users` and apply). AWS sessions end at expiry, Claude SSO login stops working |
| 2 | Claude admin settings | Remove the member — **the seat is still billed until you do** |
| 3 | MDM | The device leaves the MDM scope; the managed settings go with it |

## Monthly reconciliation (Team plan)

Because nothing syncs seats automatically, compare once a month:

```bash
terraform output -json users_by_plan | jq -r '.team[]' | sort > idc-team.txt
# Export the member list from Claude admin settings to claude-members.txt (one email per line)
comm -13 idc-team.txt <(sort claude-members.txt)   # seats to remove
```
