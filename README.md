# EnhanceSwarm 🚀

Comprehensive Claude Swarm orchestration framework that extracts and automates multi-agent orchestration patterns, including the ENHANCE protocol, task management, MCP integrations, and token optimization strategies.

## What is EnhanceSwarm?

EnhanceSwarm encapsulates production-tested patterns for orchestrating Claude Swarm agents to work on complex software development tasks. It implements the **ENHANCE protocol** - a battle-tested approach for breaking down features into parallel work streams handled by specialized AI agents.

## Key Features

- **🎯 ENHANCE Protocol**: Automatic multi-agent orchestration with a single command
- **🤖 Specialized Agents**: UX, Backend, Frontend, and QA specialists working in parallel
- **📋 Task Management**: Seamless integration with swarm-tasks or file-based task systems
- **🔧 MCP Integration**: Built-in support for Gemini CLI and Desktop Commander
- **⚡ Smart Monitoring**: Brief 2-minute checks with background execution
- **🛠️ Project Setup**: Auto-generates Claude configuration files and Git hooks
- **📊 Token Optimization**: Efficient context management strategies

## Installation

### From RubyGems (Coming Soon)
```bash
gem install enhance_swarm
```

### From GitHub
```bash
git clone https://github.com/todddickerson/enhance_swarm.git
cd enhance_swarm
bundle install
rake install
```

### Quick Setup in Any Project
```bash
# Clone and run setup script
curl -sSL https://raw.githubusercontent.com/todddickerson/enhance_swarm/main/setup.sh | bash
```

## Quick Start

### 1. Initialize in Your Project
```bash
cd your-project
enhance-swarm init
```

This creates:
- `.enhance_swarm.yml` - Configuration file
- `.claude/` - Claude-specific files (CLAUDE.md, RULES.md, MCP.md, PERSONAS.md)
- Git hooks for quality control
- Task directories (if not using swarm-tasks)

### 2. Configure Your Project
Edit `.enhance_swarm.yml`:
```yaml
project:
  name: "Your Project"
  description: "AI-powered project"
  technology_stack: "Rails 8, PostgreSQL, Hotwire"

commands:
  test: "bundle exec rails test"
  task: "bundle exec swarm-tasks"
  task_move: "bundle exec swarm-tasks move"

orchestration:
  max_concurrent_agents: 4
  monitor_interval: 30
  monitor_timeout: 120  # 2 minutes
  worktree_enabled: true
```

### 3. Use the ENHANCE Protocol
Simply say "enhance" in Claude, or run:
```bash
enhance-swarm enhance
```

This will:
1. Find the next priority task
2. Break it down for specialist agents
3. Spawn parallel workers
4. Monitor briefly (2 min)
5. Let you continue other work
6. Complete the task autonomously

## Core Commands

### `enhance-swarm init`
Initialize EnhanceSwarm in your project.

### `enhance-swarm enhance`
Execute the full ENHANCE protocol - finds next task and orchestrates agents.

Options:
- `--task TASK_ID` - Enhance a specific task
- `--dry-run` - Show what would be done without executing

### `enhance-swarm spawn "TASK_DESCRIPTION"`
Spawn a single agent for a specific task.

Options:
- `--role ROLE` - Agent role (ux/backend/frontend/qa)
- `--no-worktree` - Disable git worktree

### `enhance-swarm monitor`
Monitor running swarm agents.

Options:
- `--interval SECONDS` - Check interval (default: 30)
- `--timeout SECONDS` - Max monitoring time (default: 120)

### `enhance-swarm status`
Show current swarm status including active agents and worktrees.

### `enhance-swarm doctor`
Check system dependencies and setup.

## The ENHANCE Protocol

When you say "enhance" to Claude with this gem installed:

1. **Task Selection**: Automatically picks the next priority task from backlog
2. **Task Breakdown**: Analyzes task and determines which specialists are needed
3. **Parallel Execution**: Spawns UX, Backend, Frontend, and QA agents as needed
4. **Brief Monitoring**: Checks status for 2 minutes then returns control
5. **Background Work**: Agents continue working autonomously
6. **Completion**: Each agent commits to a feature branch when done

## MCP Tool Integration

### Gemini CLI
For large codebase analysis:
```bash
# One-time setup
gemini auth login

# The gem will use Gemini automatically for large context analysis
```

### Desktop Commander
Enables file operations outside project directory. Configure in Claude Desktop settings.

## Best Practices

### Task Sizing
- **Multi-agent tasks**: Features requiring UI + backend + tests
- **Single-agent tasks**: Bug fixes, config updates, documentation

### Git Workflow
- Each agent works in its own worktree
- Commits to feature branches
- You review and merge completed work

### Monitoring Pattern
- Brief 2-minute initial check
- Continue with other work
- Check back periodically with `enhance-swarm status`

## Architecture

```
enhance_swarm/
├── lib/
│   └── enhance_swarm/
│       ├── cli.rb           # Thor-based CLI
│       ├── orchestrator.rb  # ENHANCE protocol implementation
│       ├── monitor.rb       # Agent monitoring
│       ├── task_manager.rb  # Task system integration
│       ├── generator.rb     # File generators
│       └── mcp_integration.rb # MCP tool support
├── templates/               # ERB templates for generated files
└── exe/
    └── enhance-swarm       # Executable
```

## Advanced Configuration

### Custom Agent Roles
Define specialized agents in `.enhance_swarm.yml`:
```yaml
agents:
  database_expert:
    focus: "Database optimization and migrations"
    trigger_keywords: ["database", "migration", "index"]
```

### Token Optimization
The gem implements several strategies:
- Specialized prompts for each agent role
- Minimal context sharing between agents
- Efficient monitoring patterns

## Troubleshooting

Run diagnostics:
```bash
enhance-swarm doctor
```

Common issues:
- **claude-swarm not found**: Install from the swarm repo
- **Git worktree errors**: Ensure Git 2.5+ is installed
- **Task system not found**: Install swarm_tasks gem

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

Built from production experience with Claude Swarm on Rails 8 applications. Special thanks to the Anthropic team for Claude and the swarm orchestration patterns.

---

**Ready to enhance your development workflow? Get started with `enhance-swarm init`!** 🚀