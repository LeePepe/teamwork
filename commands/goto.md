---
name: goto
description: Jump to a specific node in the flow graph.
---

# /teamwork:goto

Jump to a specific node in the current flow graph.

## Behavior

1. Validate the target node exists in the current flow template.
2. Mark all intermediate nodes as `skipped`.
3. Set the target node as current in pipeline state.
4. Log the jump in `stage_history` with `jumped_from` and `jumped_to`.
5. Warn about any skipped gate/review nodes.
6. Report the new current position with flow visualization.

## Usage

```text
/teamwork:goto <node-id>
```

Example: `/teamwork:goto verify` to jump directly to verification.

## Notes

- Use with caution — skipping stages may produce incomplete results.
- Cannot jump to a node that doesn't exist in the current flow template.
- Jumping backward is allowed but resets completed status of intermediate nodes.
