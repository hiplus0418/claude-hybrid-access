# Claude Team plan SSO with IAM Identity Center

IAM Identity Center can't create customer-managed SAML applications through the API or Terraform, so this part is manual. Terraform only manages *who* is assigned (`aws_ssoadmin_application_assignment`, via `claude_saml_application_arn`).

Claude's SSO setup runs through a guided portal (WorkOS) opened from Claude's admin settings. It shows the exact values to copy; use those rather than anything hard-coded here.

## 1. Verify your domain in Claude

1. claude.ai → **Admin settings → Identity and access**.
2. Start domain verification and add the TXT record it shows to your DNS.
3. Wait until the domain shows as verified.

## 2. Create the SAML application in Identity Center

1. Identity Center console → **Applications → Add application → I have an application I want to set up → SAML 2.0**.
2. Display name: `Claude`.
3. From Claude's SSO setup portal, copy the **ACS URL** and **Entity ID** into *Application ACS URL* and *Application SAML audience*.
4. Download the **IAM Identity Center SAML metadata file** — the portal asks for it in step 4.
5. Save. Then **Actions → Edit attribute mappings**:

   | Attribute | Maps to | Format |
   |---|---|---|
   | `Subject` | `${user:email}` | `emailAddress` |
   | other attributes the portal lists (e.g. email, first/last name) | `${user:email}`, `${user:givenName}`, `${user:familyName}` | `unspecified` |

   The email must be identical everywhere: a mismatch is the most common cause of login failures.

## 3. Assign the group

Either set `claude_saml_application_arn` in `terraform.tfvars` and run `terraform apply` (assigns the `claude-team` group), or assign `claude-team` in the console under the application's **Assigned users and groups**.

## 4. Finish in Claude

1. Upload the Identity Center metadata in the portal and run its test login.
2. In Claude admin settings, turn on **just-in-time provisioning**, so a `claude-team` member gets a seat on first SSO login.
3. Test with a second admin account, then turn on **Require SSO**.

> **Lockout warning:** with Require SSO on, anyone not assigned in Identity Center can't log in — including admins. Keep the owner account assigned before you enable it.

## What the Team plan does *not* do

There is no SCIM on the Team plan, and Identity Center can't push users to SaaS apps anyway. Removing someone from `claude-team` **blocks their login** (Require SSO), but **their seat stays** until an admin removes it in Claude. See [migration.md](migration.md) for the checklist.

## References

- Claude SSO setup: https://support.claude.com/en/articles/13132885
- Claude provisioning (JIT / SCIM by plan): https://support.claude.com/en/articles/13133195
- Identity Center customer managed applications: https://docs.aws.amazon.com/singlesignon/latest/userguide/customermanagedapps.html
