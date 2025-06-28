# CLAUDE.md - <%= project_name %> Project Instructions

## Project Overview
<%= project_description %>

## Key Technologies
<%= technology_stack %>

## Development Guidelines

### For Swarm Agents
When working on tasks:
1. **You have FULL AUTONOMY** - Do not wait for permission to make changes
2. **Always run tests** - Use `<%= test_command %>` to verify your work
3. **Commit and push** - Always commit your changes and push to a feature branch
4. **Fix issues completely** - Don't leave work half-done

### CRITICAL: Multi-Agent Orchestration for Complex Tasks

**"ENHANCE" KEYWORD = FULL ORCHESTRATION PROTOCOL**

When user says "enhance", ALWAYS:
1. Identify next priority task(s) from backlog
2. Orchestrate multi-agent parallel implementation
3. Monitor all work to completion
4. Review, merge, and integrate
5. Clean up all worktrees and branches
6. Commit and push everything
7. Update task statuses
8. Provide completion summary

**ALWAYS use Claude Swarm orchestration for features requiring multiple components** (e.g., models + UI + tests):

1. **Break down the task** into parallel work for specialists:
   - UX Designer: UI/email templates
   - Backend Developer: Models, services, APIs
   - Frontend Developer: Controllers, views, JavaScript
   - QA Lead: Comprehensive test coverage

2. **Spawn parallel agents** (DO NOT implement directly):
   ```bash
   # First move task to active
   <%= task_move_command %> <task-id> active
   
   # Then spawn specialists in parallel
   claude-swarm start -p "UX_TASK: [specific design work from task]" --worktree &
   claude-swarm start -p "BACKEND_TASK: [specific backend work from task]" --worktree &
   claude-swarm start -p "FRONTEND_TASK: [specific frontend work from task]" --worktree &
   claude-swarm start -p "QA_TASK: [specific testing work from task]" --worktree &
   
   sleep 5  # Wait for initialization
   ```

3. **Monitor progress** every 30 seconds:
   ```bash
   while claude-swarm ps | grep -q "running"; do
     echo "Checking status..."
     claude-swarm ps
     sleep 30
   done
   ```

4. **Review and iterate** on completed work
5. **Only mark task complete** after all agents finish and work is merged

**Single-agent tasks** (simple fixes, documentation, configuration):
- Implement directly without orchestration
- Examples: Fix typo, update config, add single method

### Code Standards
<%= code_standards %>

### Git Workflow
```bash
# Stage all changes
git add -A

# Commit with descriptive message
git commit -m "Add feature: description

- Detail 1
- Detail 2"

# Push to feature branch
git checkout -b feature/description
git push origin HEAD
```

### Common Tasks

#### Fix Failing Tests
1. Run tests to see failures: `<%= test_command %>`
2. Read error messages carefully
3. Check for missing database columns
4. Ensure test data is valid
5. Mock external services properly
6. Run tests again to verify

#### Add New Feature
1. Create necessary models/migrations
2. Add services for business logic
3. Create controllers and routes
4. Build UI components
5. Write comprehensive tests
6. Document in commit message

## Task Management Process

### Working with Tasks - Use the `<%= task_command %>` Command
```bash
# List tasks
<%= task_command %> list          # Show all tasks
<%= task_command %> list active   # Show active tasks
<%= task_command %> list backlog  # Show backlog

# Move tasks between states
<%= task_command %> move <task-id> active     # Start working on a task
<%= task_command %> move <task-id> completed  # Mark task as done

# View task details
<%= task_command %> show <task-id>

# Get statistics
<%= task_command %> stats

# Create new tasks
<%= task_command %> create "Task Title" --effort 4 --tags backend,api

# For AI agents - use JSON output
<%= task_command %> list active --json
```

### For Swarm Agents
1. **Check for tasks**: `<%= task_command %> list active --json`
2. **Start a task**: `<%= task_command %> move <task-id> active`
3. **Complete a task**: `<%= task_command %> move <task-id> completed`
4. **Commit and push changes**: 
   ```bash
   git add -A
   git commit -m "Complete task: <task-id> - <description>"
   git push origin main  # or feature branch
   ```
5. **Never use manual mv commands** - always use the <%= task_command %> gem

### Task File Format
Each task file should contain:
- **Status**: (implicit by directory location)
- **Description**: What needs to be done
- **Acceptance Criteria**: How we know it's complete
- **Time Estimate**: Hours expected
- **Actual Time**: Hours spent (update when complete)

## Important Notes
<%= important_notes %>

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.