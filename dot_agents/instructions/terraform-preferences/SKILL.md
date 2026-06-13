---
name: terraform-preferences
description: Apply Terraform conventions for state-safe workflows, provider lock safety, and practical schema usage.
---

# Terraform preferences

Use this skill when writing or reviewing Terraform/Terragrunt configuration.

- Never delete `.terraform` directories as routine cleanup.
- Keep `.terraform` intact across normal operations; remove it only when the user explicitly requests it or when targeted troubleshooting requires a clean re-init.
- Prefer `terraform init -reconfigure` (or `terraform init -upgrade` when appropriate) before any destructive cache reset.
- Preserve `.terraform.lock.hcl`; only update it when provider changes actually require it.
- Only use `max_items` and `direction` for data where they semantically make sense.
- When using Terraform locals to build `for_each` maps, prefer `_id` for internal helper keys to avoid confusion with provider/resource schema fields.
- Clarify that helper keys in locals are Terraform-internal and not provider arguments.
