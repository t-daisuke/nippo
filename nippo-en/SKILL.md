---
name: nippo
description: Generate a daily report from Claude Code session logs.
allowed-tools: Bash
---

# Daily Report Skill

Create a daily report from the session data below.

## Session Data

!`~/.claude/skills/nippo-en/scripts/collect-logs.sh $ARGUMENTS`

## Output Format

Analyze the data above and create a report in this format:

```markdown
# Daily Report - YYYY-MM-DD

## What I Did Today

### [Project Name]
- Task summary (inferred from user messages)

## Details (Optional)

Session details only if needed

## Tomorrow's Tasks (if any ongoing work)
- Task list
```

### Notes

- Infer work content from user messages
- Do not include sensitive information (passwords, tokens, etc.)
- Group work by project

## Arguments

- `/nippo` - Today's report
- `/nippo yesterday` - Yesterday's report
- `/nippo 2026-01-20` - Report for a specific date
