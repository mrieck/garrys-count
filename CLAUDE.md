# Garry's Count

A parody project that tracks how many lines of code Claude Code writes per day, displayed in the Claude Code status bar.

## How it works

1. **PostToolUse hook** (`scripts/count-hook.sh`) fires after every Write/Edit/MultiEdit tool call, counts lines in the new content, and appends to a daily tally file at `~/.claude/garryscount/YYYY-MM-DD.json`
2. **Status line** (`scripts/statusline.sh`) reads the tally file and displays `Garry's Count: X loc` in the status bar
3. **Report skill** (`skills/garryscount/SKILL.md`) — type `/garryscount` to get a breakdown report by file type with 7-day history

## Architecture

- Hook receives JSON on stdin with `tool_name` and `tool_input` (file_path, content/new_string/old_string)
- Daily tally files stored as JSON: `{"date":"...","total_lines":N,"count_mode":"...","last_updated":"...","by_extension":{".py":N,...}}`
- Report script (`scripts/report.sh`) aggregates daily tally files into a JSON report for the skill
- Config at `~/.claude/garryscount/config.json` with `reset_hour` (default 5) and `count_mode` ("default" or "yc-mode")
- Day boundary is at `reset_hour` (5am default), not midnight
- Atomic file writes via temp + mv for concurrent session safety

## Two counting modes

- `"default"`: net new lines only. For Edit, counts `new_string` lines minus `old_string` lines.
- `"yc-mode"`: every line Claude writes counts, even rewrites. Inflated numbers are the point.

## Installation

- `install.sh` copies scripts to `~/.claude/garryscount/`, adds hooks and statusLine to `~/.claude/settings.json`, installs `/garryscount` skill to `~/.claude/skills/garryscount/`
