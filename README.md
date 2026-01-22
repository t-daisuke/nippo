# nippo

Claude Code Agent Skill for generating daily reports from session logs.

## Overview

`/nippo` is a Claude Code skill that analyzes your Claude Code session logs and generates a daily report summarizing what you worked on.

## Features

- Extracts user messages from Claude Code session logs
- Filters sessions by date (today, yesterday, or specific date)
- Groups work by project/repository
- Excludes subagent logs (focuses on main sessions only)
- Pre-filters by file modification time for performance
- Outputs a structured daily report in Markdown format

## Installation

Copy the skill to your Claude Code skills directory:

```bash
cp -r . ~/.claude/skills/nippo
```

Or clone directly:

```bash
git clone https://github.com/t-daisuke/nippo.git ~/.claude/skills/nippo
```

## Usage

```
/nippo              # Today's report
/nippo yesterday    # Yesterday's report
/nippo 2026-01-22   # Specific date
```

## Requirements

- macOS (uses `stat -f` and `date -j` which are macOS-specific)
- `jq` command for JSON parsing
- Claude Code with Agent Skills support

## Output Example

```markdown
# Daily Report - 2026-01-22

## What I Did Today

### my-webapp
- Implemented user authentication with JWT
- Fixed login form validation bug
- Added unit tests for auth middleware

### api-server
- Refactored database connection pooling
- Updated API documentation

## Details

### Session: my-webapp
- Working Directory: /Users/alice/projects/my-webapp
- Branch: feature/user-auth

### User Messages
- Add JWT authentication to the login endpoint
- The form validation is not working, please fix it
- Write tests for the auth middleware

### Session: api-server
- Working Directory: /Users/alice/projects/api-server
- Branch: refactor/db-pool

### User Messages
- Optimize the database connection pool settings
- Update the README with new API endpoints
```

## How It Works

1. **collect-logs.sh** scans `~/.claude/projects/` for session logs
2. Filters by modification time (±1 day) for performance
3. Extracts timestamp from first user message to determine session date
4. Outputs session metadata and user messages
5. **SKILL.md** instructs Claude to summarize the data into a daily report

## License

MIT
