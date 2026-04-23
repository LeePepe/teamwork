#!/usr/bin/env python3
"""Unit tests for scripts/analyze-retros.py"""

import sys
import os
import unittest

# Add scripts dir to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

# Import functions directly from the module
import importlib.util
spec = importlib.util.spec_from_file_location("analyze_retros",
    os.path.join(os.path.dirname(__file__), "..", "scripts", "analyze-retros.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

parse_retro = mod.parse_retro
analyze_retros = mod.analyze_retros
generate_report = mod.generate_report


SAMPLE_RETRO = """# Retrospective: TestProject — 2025-04-20

## Run Summary

- **Date**: 2025-04-20
- **Project**: TestProject
- **Task**: Add login feature
- **Pipeline stages run**: plan → execute → verify → review
- **Duration**: 30 min

## What Worked

- Planning stage was thorough
- Verification caught a bug

## What Didn't Work

- Designer stage was slow
- Context window exceeded limits

## Accuracy Issues

- **Stage**: execute
- **Issue**: Generated code had wrong import paths
- **Impact**: high

## Unnecessary Steps

- **Stage**: designer
- **Why unnecessary**: No UI changes needed for this task

## Context Usage

- **Total context consumed**: large
- **Context bottlenecks**: planner output was verbose
- **Suggestions for reduction**: Summarize plan before passing to executor

## Core Principles Compliance

- [x] Content was reviewed before acceptance
- [ ] Plan + docs used as source of truth
- [x] Layered plan/docs kept context minimal

## Action Items

- Fix import path resolution in executor
"""


class TestParseRetro(unittest.TestCase):
    def test_parse_date(self):
        r = parse_retro(SAMPLE_RETRO)
        self.assertIn("2025-04-20", r["date"])

    def test_parse_project(self):
        r = parse_retro(SAMPLE_RETRO)
        self.assertIn("TestProject", r["project"])

    def test_parse_what_worked(self):
        r = parse_retro(SAMPLE_RETRO)
        self.assertEqual(len(r["what_worked"]), 2)

    def test_parse_what_didnt(self):
        r = parse_retro(SAMPLE_RETRO)
        self.assertEqual(len(r["what_didnt"]), 2)

    def test_parse_accuracy_issues(self):
        r = parse_retro(SAMPLE_RETRO)
        self.assertTrue(len(r["accuracy_issues"]) >= 1)

    def test_parse_unnecessary_steps(self):
        r = parse_retro(SAMPLE_RETRO)
        self.assertTrue(len(r["unnecessary_steps"]) >= 1)

    def test_parse_principles(self):
        r = parse_retro(SAMPLE_RETRO)
        self.assertTrue(r["principles_compliance"]["reviewed"])
        self.assertFalse(r["principles_compliance"]["plan_as_truth"])
        self.assertTrue(r["principles_compliance"]["layered"])

    def test_parse_action_items(self):
        r = parse_retro(SAMPLE_RETRO)
        self.assertTrue(len(r["action_items"]) >= 1)


class TestAnalyzeRetros(unittest.TestCase):
    def test_empty_input(self):
        result = analyze_retros([])
        self.assertIn("No retros", result["summary"])

    def test_single_retro(self):
        r = parse_retro(SAMPLE_RETRO)
        result = analyze_retros([r])
        self.assertGreater(len(result["suggestions"]), 0)
        self.assertEqual(result["total_retros"], 1)

    def test_accuracy_suggestion_generated(self):
        r = parse_retro(SAMPLE_RETRO)
        result = analyze_retros([r])
        areas = [s["area"] for s in result["suggestions"]]
        self.assertIn("accuracy", areas)

    def test_unnecessary_steps_suggestion(self):
        r = parse_retro(SAMPLE_RETRO)
        result = analyze_retros([r])
        areas = [s["area"] for s in result["suggestions"]]
        self.assertIn("unnecessary_steps", areas)

    def test_principle_violation_detected(self):
        r = parse_retro(SAMPLE_RETRO)
        result = analyze_retros([r])
        areas = [s["area"] for s in result["suggestions"]]
        self.assertIn("principles", areas)


class TestGenerateReport(unittest.TestCase):
    def test_report_contains_summary(self):
        r = parse_retro(SAMPLE_RETRO)
        analysis = analyze_retros([r])
        report = generate_report(analysis)
        self.assertIn("Summary", report)

    def test_report_markdown_format(self):
        r = parse_retro(SAMPLE_RETRO)
        analysis = analyze_retros([r])
        report = generate_report(analysis)
        self.assertIn("# Retro Analysis Report", report)

    def test_empty_analysis_report(self):
        analysis = analyze_retros([])
        report = generate_report(analysis)
        self.assertIn("No optimization suggestions", report)


if __name__ == "__main__":
    unittest.main()
