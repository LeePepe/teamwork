---
name: pass
description: Force the current gate node to a green (PASS) verdict.
---

# /teamwork:pass

Force-pass the current gate node regardless of evidence.

## Behavior

1. Set the current gate node's verdict to `🟢 PASS`.
2. Advance to the next node in the flow graph.
3. Log the forced pass in `stage_history` with `forced: true`.
4. Report the new current position with flow visualization.

## Usage

```text
/teamwork:pass
```

## Notes

- Use when manual verification confirms the gate should pass despite automated evidence.
- Forced passes are logged and visible in the pipeline summary.
- Only applicable to `gate` and `review` node types.
