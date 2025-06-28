# The ENHANCE Workflow

This document explains the ENHANCE protocol workflow in detail with practical examples.

## What is ENHANCE?

ENHANCE is a keyword that triggers automatic multi-agent orchestration. When you say "enhance" to Claude (with EnhanceSwarm installed), it:

1. Finds the next priority task
2. Breaks it down by specialty
3. Spawns parallel AI agents
4. Monitors briefly (2 min)
5. Returns control to you
6. Completes work in background

## Basic Usage

### In Claude Chat
Simply type:
```
enhance
```

Claude will respond with something like:
```
🎯 ENHANCE Protocol Activated!
📋 Task: 2024-06-28-user-authentication - Add user authentication system
✅ Task moved to active
🤖 Spawning 4 agents...
✅ All agents spawned

👀 Monitoring for 120 seconds...
[Check 1/4] 14:30:22
Active agents: 4
  - ux_agent (PID: 12345)
  - backend_agent (PID: 12346)
  - frontend_agent (PID: 12347)
  - qa_agent (PID: 12348)

[Check 2/4] 14:30:52
Active agents: 3
Completed: 1

💡 Agents working in background. Check back later with:
   enhance-swarm monitor
   enhance-swarm status
```

### From Command Line
```bash
# Enhance next priority task
enhance-swarm enhance

# Enhance specific task
enhance-swarm enhance --task 2024-06-28-payment-integration

# Dry run to see what would happen
enhance-swarm enhance --dry-run
```

## Task Breakdown Examples

### Example 1: E-commerce Cart Feature

Given task: "Implement shopping cart with real-time updates"

ENHANCE breaks it down to:
- **UX Agent**: Design cart UI, empty states, quantity controls
- **Backend Agent**: Cart and CartItem models, pricing service
- **Frontend Agent**: Turbo frames, Stimulus controllers
- **QA Agent**: Unit tests, system tests, edge cases

### Example 2: API Endpoint

Given task: "Add REST API for user profiles"

ENHANCE breaks it down to:
- **Backend Agent**: API controller, serializers, authentication
- **QA Agent**: API tests, documentation

(No UX or Frontend agents needed for pure API work)

### Example 3: Bug Fix

Given task: "Fix N+1 query in dashboard"

ENHANCE recognizes this as a single-agent task and runs directly without orchestration.

## Monitoring Patterns

### The 2-Minute Rule

ENHANCE monitors for exactly 2 minutes, then returns control:

```
Minute 0-2: Active monitoring
  - Shows live status
  - Updates every 30 seconds
  - Displays completed agents

After 2 minutes: Background execution
  - Agents continue working
  - You work on other tasks
  - Check back periodically
```

### Checking Status

While agents work in background:

```bash
# Quick status check
enhance-swarm status

# Output:
📊 Swarm Status:
  Active agents: 2
  Completed tasks: 2
  Worktrees: 4

📌 Recent branches:
  - swarm/ux-20240628-143022
  - swarm/backend-20240628-143025
```

### Detailed Monitoring

When you want to watch agents work:

```bash
# Watch with default settings (30s interval, 120s timeout)
enhance-swarm monitor

# Custom monitoring
enhance-swarm monitor --interval 10 --timeout 300
```

## Agent Communication

Each agent receives:

```
AUTONOMOUS EXECUTION REQUIRED - [ROLE] SPECIALIST

[Task Description]

CRITICAL INSTRUCTIONS:
1. You have FULL PERMISSION to read, write, edit files and run commands
2. DO NOT wait for any permissions - proceed immediately
3. Complete the task fully and thoroughly
4. Test your implementation using: [test command]
5. When complete:
   - Run: git add -A
   - Run: git commit -m '[role]: [description]'
   - Run: git checkout -b 'swarm/[role]-[timestamp]'
   - Run: git push origin HEAD
6. Document what was implemented in your final message
```

## Parallel Execution

Agents work simultaneously in separate git worktrees:

```
main branch
├── .worktree_ux_1234      (UX agent workspace)
├── .worktree_backend_5678  (Backend agent workspace)  
├── .worktree_frontend_9012 (Frontend agent workspace)
└── .worktree_qa_3456       (QA agent workspace)
```

Benefits:
- No conflicts between agents
- Parallel file editing
- Independent testing
- Clean merging

## Reviewing Completed Work

### Step 1: Check Branches
```bash
# See what agents created
git fetch
git branch -r | grep swarm/

# Output:
origin/swarm/backend-20240628-143025
origin/swarm/frontend-20240628-143030
origin/swarm/qa-20240628-143035
origin/swarm/ux-20240628-143022
```

### Step 2: Review Changes
```bash
# Check each branch
git checkout swarm/backend-20240628-143025
git diff main
bundle exec rails test

# If good, merge
git checkout main
git merge swarm/backend-20240628-143025
```

### Step 3: Clean Up
```bash
# Remove worktrees
git worktree remove .worktree_ux_1234
git worktree remove .worktree_backend_5678

# Delete merged branches
git branch -d swarm/backend-20240628-143025
git push origin --delete swarm/backend-20240628-143025
```

## Advanced Patterns

### Continuous Enhancement

Keep enhancing while agents work:

```
# Terminal 1
enhance-swarm enhance  # Starts first task

# Terminal 2 (2 minutes later)
enhance-swarm enhance  # Starts second task

# Terminal 3 (2 minutes later)  
enhance-swarm enhance  # Starts third task

# Check all progress
enhance-swarm status
```

### Task Chains

For dependent tasks:

```yaml
# tasks/backlog/2024-06-28-auth-chain.yml
title: Authentication System
subtasks:
  - id: auth-models
    description: Create User and Session models
    dependencies: []
  - id: auth-controllers  
    description: Create login/logout controllers
    dependencies: [auth-models]
  - id: auth-ui
    description: Create login forms and UI
    dependencies: [auth-controllers]
```

### Custom Workflows

Override default behavior in `.enhance_swarm.yml`:

```yaml
workflows:
  feature:
    agents: [ux, backend, frontend, qa]
    monitor_timeout: 120
    
  bugfix:
    agents: [general]
    monitor_timeout: 60
    
  refactor:
    agents: [backend, qa]
    monitor_timeout: 180
```

## Tips and Tricks

1. **Batch Processing**: Run enhance multiple times for parallel task execution
2. **Night Runs**: Start enhance before leaving, review completed work next day
3. **CI Integration**: Trigger enhance from GitHub Actions for automated development
4. **Task Sizing**: Break large epics into 4-8 hour tasks for best results
5. **Review Rhythm**: Check swarm status every 15-30 minutes during active development

## Common Patterns

### Morning Workflow
```bash
# Start the day
enhance-swarm enhance     # Start first task
enhance-swarm status      # Check overnight work
git pull                  # Get completed work
bundle exec rails test    # Verify everything works
```

### Continuous Development
```bash
# In a loop
while true; do
  enhance-swarm enhance
  sleep 120  # Wait 2 minutes
  
  # Do other work while agents run
  # Review PRs, write docs, etc.
  
  enhance-swarm status
done
```

### End of Day
```bash
# Before leaving
enhance-swarm enhance --task tomorrow-priority-1
enhance-swarm enhance --task tomorrow-priority-2
enhance-swarm monitor --timeout 300

# Next morning
enhance-swarm status
# Review all completed work
```

## Troubleshooting

### Agents Not Completing
```bash
# Check agent logs
enhance-swarm status
claude-swarm ps
claude-swarm show [session-id]
```

### Merge Conflicts
```bash
# Agents work in isolation, but if conflicts arise:
git checkout main
git merge --no-ff swarm/backend-branch
# Resolve conflicts
git add .
git commit
```

### Resource Limits
```yaml
# Adjust in .enhance_swarm.yml
orchestration:
  max_concurrent_agents: 2  # Reduce if system is slow
  monitor_interval: 60      # Check less frequently
  monitor_timeout: 60       # Shorter monitoring
```