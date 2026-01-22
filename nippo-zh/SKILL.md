---
name: nippo
description: 从Claude Code会话日志生成日报。
allowed-tools: Bash
---

# 日报生成技能

根据以下会话数据创建日报。

## 会话数据

!`~/.claude/skills/nippo-zh/scripts/collect-logs.sh $ARGUMENTS`

## 输出格式

分析上述数据，按以下格式创建日报：

```markdown
# 日报 - YYYY-MM-DD

## 今日完成的工作

### [项目名称]
- 任务摘要（从用户消息推断）

## 详情（可选）

仅在需要时记录会话详情

## 明天的任务（如有未完成的工作）
- 任务列表
```

### 注意事项

- 从用户消息推断工作内容
- 不要包含敏感信息（密码、令牌等）
- 按项目分组工作内容

## 参数

- `/nippo` - 今天的日报
- `/nippo yesterday` - 昨天的日报
- `/nippo 2026-01-20` - 指定日期的日报
