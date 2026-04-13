---
name: stop
description: Gracefully stop the pipeline and preserve state for later resume.
---

# /teamwork:stop

Gracefully halt the pipeline, saving current state for later resume.

## Behavior

1. Save current pipeline state to `.claude/pipeline-state.json` via `save_pipeline_state()`.
2. Mark current stage as `paused` in state.
3. Report saved state location and resume instructions.
4. Exit the pipeline without cleanup.

## Usage

```text
/teamwork:stop
```

## Notes

- State is preserved for cross-session resume.
- Resume by running `/teamwork:task` again — the pipeline will detect saved state and offer to continue.
- Use `/teamwork:stop` when you need to pause work and return later.
