---
name: flow
description: Select or display the current flow template.
---

# /teamwork:flow

Select a flow template or display the current flow state.

## Behavior

### Without arguments
Display the current flow template and pipeline position:
- Show the selected template name
- Render ASCII flow visualization with current position
- Show completed/pending/skipped nodes

### With template name
Select a flow template for the current pipeline:
1. Load the specified template from `templates/flow-<name>.yaml`.
2. If pipeline is already in progress, warn about template change implications.
3. Update pipeline state with new template.
4. Report the new flow structure.

## Usage

```text
/teamwork:flow                  # show current flow
/teamwork:flow standard         # select standard template
/teamwork:flow pre-release      # select pre-release template
```

## Available Templates

- `standard` — full research→plan→review→execute→verify→final-review pipeline (default)
- `review` — review-only flow for existing code
- `build-verify` — quick build-and-verify for confident changes
- `pre-release` — extended pipeline with security and performance review gates

## Notes

- Template can only be changed before execution begins.
- Default template is `standard` unless overridden in `.claude/team.md`.
