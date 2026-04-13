---
name: skip
description: Skip the current pipeline node and advance to the next stage.
---

# /teamwork:skip

Skip the current flow engine node without completing it.

## Behavior

1. Mark the current node as `skipped` in pipeline state.
2. Advance to the next node in the flow graph.
3. Log the skip action in `stage_history`.
4. Report the new current position with flow visualization.

## Usage

```text
/teamwork:skip
```

## Notes

- Use when the current stage is blocked or unnecessary.
- Skipped stages cannot be un-skipped without `/teamwork:goto`.
- Skipping a gate node bypasses its verification.
