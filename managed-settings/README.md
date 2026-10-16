# Claude Code managed settings

Two policies, one per plan. Terraform renders them with the real ARNs (`terraform output managed_settings_bedrock` / `managed_settings_claudeai`); the files here are annotated examples.

| File | Plan | Effect |
|---|---|---|
| `bedrock.example.json` | `bedrock` | Claude Code calls Bedrock through the team's inference profile, with the guardrail headers on every request, and refreshes SSO credentials automatically |
| `claudeai.example.json` | `team` | Claude Code can only log in with a claude.ai account in your organization |

Both disable `--dangerously-skip-permissions`.

## Where the file goes

| OS | Path |
|---|---|
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux / WSL | `/etc/claude-code/managed-settings.json` |
| Windows | `C:\Program Files\ClaudeCode\managed-settings.json` |

Deliver it with your MDM (Jamf, Intune, ...), scoped by the same group as in Identity Center: `claude-bedrock` (per team) or `claude-team`. Users can't override managed settings.

## User setup for the bedrock plan (once)

```bash
aws configure sso --profile claude-bedrock   # pick the ClaudeCodeBedrock permission set
aws sso login --profile claude-bedrock
claude
```

After that, Claude Code runs `aws sso login` by itself when the session expires.
