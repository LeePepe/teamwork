# Retro Collection and Optimization Process

## Overview

The retro optimizer is a feedback loop that collects retrospective data from all projects using the teamwork pipeline, analyzes patterns, and generates optimization suggestions.

## Process

### 1. Write Retros

After each teamwork pipeline run, create a retro file in your project:

```
your-project/docs/retro/YYYY-MM-DD-description.md
```

Use the template at `templates/retro-template.md`.

### 2. Collect Retros

Run the collection script to gather retros from all projects:

```bash
bash scripts/collect-retros.sh
```

This scans `~/Development/*/docs/retro/*.md` and copies files to `docs/retro-findings/collected/`.

### 3. Analyze

Run the analysis script:

```bash
python3 scripts/analyze-retros.py
```

Outputs:
- `docs/retro-findings/analysis-report.md` — human-readable report
- `docs/retro-findings/analysis-report.json` — machine-readable data

### 4. Review and Apply

The retro-optimizer agent sends a WeChat notification (`weixin:o9cq800VL1anWwX_mjwnvFkFOkLo@im.wechat`) before applying any changes. Changes are only applied after explicit user confirmation.

## Optimization Focus

| Principle | How It's Enforced |
|-----------|-------------------|
| Content needs review | Retro tracks whether outputs were reviewed before acceptance |
| Plan+docs as source of truth | Retro tracks whether plan/docs drove execution |
| Layered plan/docs to reduce context | Retro tracks context usage and identifies bloat |

## File Locations

| File | Purpose |
|------|---------|
| `agents/retro-optimizer.md` | Agent definition |
| `templates/retro-template.md` | Template for project retros |
| `scripts/collect-retros.sh` | Collection script |
| `scripts/analyze-retros.py` | Analysis script |
| `docs/retro-findings/` | Analysis output directory |
| `test/test_analyze_retros.py` | Unit tests |
