# Retro Process

## Overview

Teamwork retro 系统整合了两种分析维度：

- **定性分析**：基于项目团队手写的 retro markdown 文件
- **定量分析**：基于 `.claude/last-run-*.md` 执行日志的自动化指标

所有数据集中存储在 `~/Development/teamwork/data/`。

## Data Directory

```
data/
├── runs.jsonl              ← 结构化执行日志（自动采集，增量去重）
└── retros/
    └── collected/          ← 手写 retro 汇总（从各项目复制）
        ├── epichain-mac--2026-04-15-xxx.md
        └── MonitorSelf--2026-04-20-xxx.md
```

## Data Flow

```
各项目/.claude/last-run-*.md  ─┐
                                ├──  collect-retros.sh  →  data/
各项目/docs/retro/*.md        ─┘        (一键收集)

data/runs.jsonl  ──┐
                    ├──  analyze-retros.py  →  docs/retro-findings/analysis-report.md
data/retros/       ──┘     (统一分析)                    ↓
                                              定量 + 定性 + 交叉分析
```

## Running

### 1. 收集数据

```bash
cd ~/Development/teamwork
bash scripts/collect-retros.sh
```

这会同时收集：
- 手写 retro：`~/Development/*/docs/retro/*.md` → `data/retros/collected/`
- 执行日志：`~/Development/*/.claude/last-run-*.md` → `data/runs.jsonl`

### 2. 分析

```bash
python3 scripts/analyze-retros.py
```

输出统一报告到 `docs/retro-findings/analysis-report.md`，包含：
- **定量**：成功率、agent 效率、瓶颈排名、效率评分
- **定性**：准确性问题、不必要步骤、原则遵守情况
- **交叉分析**：定量瓶颈 × 定性反馈关联

### 3. 单独运行定量 eval

```bash
python3 scripts/eval_runs.py
```

### 4. 单独收集 run logs

```bash
python3 scripts/collect_runs.py
```

## Cron Job

`teamwork-eval` cron job（每周一 08:00）自动执行 collect + eval，
结果同步到 agent-ops dashboard。

## Hand-Written Retro Template

各项目在 `docs/retro/YYYY-MM-DD-<slug>.md` 按模板写 retro。
模板见 `templates/retro-template.md`。

## Scripts

| Script | Purpose |
|--------|---------|
| `collect-retros.sh` | 一键收集所有数据源 |
| `collect_runs.py` | 增量采集 last-run → runs.jsonl |
| `parse_runs.py` | 解析 last-run-*.md 为 JSON |
| `eval_runs.py` | 定量分析 + 报告 |
| `analyze-retros.py` | 统一分析（定量+定性+交叉） |

## Core Principles

1. **Content needs review** — never auto-apply without human gate
2. **Plan+docs as source of truth** — optimize plan accuracy
3. **Layered plan/docs** — reduce context window usage
4. **WeChat confirmation** before applying changes to skills/agents
