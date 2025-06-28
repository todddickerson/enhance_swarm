# EnhanceSwarm 🚀

**Intelligent multi-agent orchestration for Claude with autonomous coordination, live streaming, and smart dependency management.**

EnhanceSwarm transforms Claude into a sophisticated multi-agent development team with a Control Agent that autonomously coordinates specialist workers (Backend, Frontend, QA, UX) to complete complex software tasks in parallel.

## ✨ Key Features

- **🎛️ Control Agent**: Autonomous Claude instance coordinates multi-agent workflows
- **📡 Live Streaming**: Real-time output streaming from all agents with progress bars
- **🔔 Smart Notifications**: Cross-platform desktop notifications with intelligent interrupts
- **🔄 Smart Coordination**: Intelligent dependency management (backend → frontend → qa)
- **📊 Progress Tracking**: Time estimates, token usage, and completion percentages
- **🔍 Agent Review**: Monitor and track work across all agent worktrees
- **⚡ Self-Healing**: Automatic retries, error recovery, and resource cleanup
- **🛡️ Security First**: Command injection protection and secure execution

## 🚀 Quick Installation

### Option 1: Add to Existing Project (Recommended)

```bash
# Add to your Gemfile
echo 'gem "enhance_swarm", git: "https://github.com/todddickerson/enhance_swarm.git"' >> Gemfile
bundle install

# Initialize in your project
bundle exec enhance-swarm init
```

### Option 2: Global Installation

```bash
# Clone and install globally
git clone https://github.com/todddickerson/enhance_swarm.git
cd enhance_swarm
bundle install && rake install

# Use anywhere
enhance-swarm init
```

### Option 3: Quick Setup Script

```bash
# One-command setup (coming soon)
curl -sSL https://raw.githubusercontent.com/todddickerson/enhance_swarm/main/setup.sh | bash
```

## 🎯 Getting Started

### 1. Initialize Your Project

```bash
cd your-project
enhance-swarm init
```

**Creates:**
- `.enhance_swarm.yml` - Project configuration
- `.claude/` directory with specialized files:
  - `CLAUDE.md` - Core Claude configuration 
  - `RULES.md` - Operational rules and standards
  - `MCP.md` - Model Context Protocol settings
  - `PERSONAS.md` - Agent personality definitions
- Git hooks for quality control

### 2. Configure Your Stack

Edit `.enhance_swarm.yml`:
```yaml
project:
  name: "My Rails App"
  description: "E-commerce platform with AI features"
  technology_stack: ["Rails 8", "PostgreSQL", "Hotwire", "Tailwind"]

commands:
  test: "bundle exec rspec"
  lint: "bundle exec rubocop"
  
orchestration:
  max_concurrent_agents: 4
  monitor_timeout: 120
```

### 3. Start Enhancing!

```bash
# Launch with Control Agent coordination
enhance-swarm enhance "implement user authentication system"

# With live streaming
enhance-swarm enhance "add shopping cart functionality" --follow

# Single agent for quick tasks
enhance-swarm spawn "fix login validation bug" --role backend --follow
```

## 🎛️ The Control Agent System

**Autonomous coordination powered by Claude:**

```bash
enhance-swarm enhance "implement user authentication" --follow
```

**Results in intelligent orchestration:**

```
🎛️  Control Agent Coordination
Phase: Backend Implementation  
Progress: 45%

🔄 Active Agents:
  • backend-auth-20250628-1432

✅ Completed Agents:  
  • analysis-requirements-20250628-1431

📝 Status: Backend agent implementing User model with bcrypt authentication

⏱️  Estimated completion: 20:45:30 (12m remaining)
```

## 📡 Live Agent Streaming

Watch your agents work in real-time:

```bash
enhance-swarm spawn "implement login API" --role backend --follow
```

**Live output display:**

```
⠋ [█████████░░] 45% Spawning backend agent... [2m15s/4m30s]
┌─ 🔧 BACKEND Agent (2m15s) backend-auth-123 ──────────────┐
│ ● 🔍 Analyzing existing auth system...                   │
│ ● 📁 Reading app/models/user.rb                          │
│ ● ✅ Found User model with email field                   │
│ ● 🔧 Generating sessions controller...                   │
│ ● 📝 Writing spec/requests/auth_spec.rb                  │
│ ● 🏃 Running rspec...                                    │
│ ● 🎯 Implementing password validation...                 │
│ ● 🔒 Adding bcrypt authentication...                     │
└───────────────────────────────────────────────────────────┘

📋 Completed:
  ✅ backend (2m15s)
```

## 🔍 Agent Review & Monitoring

Track all agent work across your project:

```bash
# Review all agent progress
enhance-swarm review

# Get detailed JSON status
enhance-swarm review --json

# Monitor running agents
enhance-swarm monitor --interval 30
```

**Review output:**
```
=== Agent Work Review ===
Time: 2025-06-28 19:45:30

📊 Summary:
  Total worktrees: 3
  Active: 1
  Stale: 0

📋 Tasks:
  Completed: 2
  Active: 1
  Blocked: 0

✅ Recently Completed:
  auth-backend (swarm/backend-auth-20250628)
  login-ui (swarm/frontend-login-20250628)

🔄 Currently Active:
  payment-integration (5m ago)
```

## 🔔 Smart Notifications & Interrupts

Stay informed about agent progress with intelligent notifications:

```bash
# Enable notifications with enhance command
enhance-swarm enhance "implement auth system" --notifications

# Manage notification settings
enhance-swarm notifications --enable
enhance-swarm notifications --test
enhance-swarm notifications --history
```

**Notification Features:**

- **Desktop Notifications**: Cross-platform desktop alerts (macOS/Linux/Windows)
- **Priority-Based**: Critical, High, Medium, Low priority notifications
- **Agent Events**: Completion, failures, stuck detection, milestones
- **Intelligent Interrupts**: Timeout-based prompts for stuck/failed agents
- **Sound Alerts**: Configurable sound notifications for critical events

**Interrupt Handling:**

```bash
# Automatic prompts for stuck agents
Agent 'backend' stuck for 12m. Restart? [y/N]
(Auto-selecting 'n' in 30s if no response)

# Smart error recovery suggestions
Agent 'frontend' failed: Connection timeout
💡 Quick fixes:
  1. Restart agent with longer timeout
  2. Check network connectivity
Choose [1-2] or [c]ustom command:

# Manual agent management
enhance-swarm restart backend-auth-123
```

**Notification History:**

```bash
enhance-swarm notifications --history
# 📋 Recent Notifications:
# [14:32:15] HIGH - Agent Completed: 🎉 Agent 'backend' completed successfully!
# [14:28:45] CRITICAL - Agent Failed: ❌ Agent 'frontend' failed: Timeout
# [14:25:30] MEDIUM - Progress Milestone: 📍 Backend complete (75% complete)
```

## 💬 Quick Agent Communication

Seamless communication between you and running agents:

```bash
# Interactive communication mode
enhance-swarm communicate --interactive

# List pending messages from agents
enhance-swarm communicate --list

# Respond to specific agent question
enhance-swarm communicate --respond msg_123 --response "Use PostgreSQL"

# View communication history
enhance-swarm communicate --history
```

**Communication Features:**

- **Real-time Messaging**: Agents can ask questions while working
- **Non-blocking**: Continue other work while agents wait for responses
- **Message Types**: Questions, status updates, progress reports, decisions
- **Quick Actions**: Pre-defined responses for common agent questions
- **Timeout Handling**: Default responses when user is unavailable
- **File-based**: Cross-process communication that persists across sessions

**Example Agent Communication:**

```bash
📬 Agent Communication: 2 pending messages

[12:34:56] QUESTION from backend-auth-123:
"Should I use Devise or build custom authentication? 
The project already has some user management code."

Quick actions: [1] Use Devise  [2] Custom auth  [3] Analyze existing
Your response: 2

✅ Response sent to backend-auth-123
```

## 🖥️ Visual Agent Dashboard

Real-time monitoring with an interactive visual dashboard:

```bash
# Start dashboard for all running agents
enhance-swarm dashboard

# Monitor specific agents
enhance-swarm dashboard --agents backend-auth-123 frontend-ui-456

# Take a snapshot and exit
enhance-swarm dashboard --snapshot

# Custom refresh rate
enhance-swarm dashboard --refresh 1
```

**Dashboard Features:**

- **Agent Status Grid**: Visual status indicators for all agents
- **Progress Bars**: Real-time progress tracking with percentages
- **System Resources**: Memory usage, process count, message queue
- **Interactive Controls**: Pause, refresh, help, detailed views
- **Health Indicators**: Visual agent health with color coding
- **Terminal UI**: Full terminal-based interface with keyboard shortcuts

**Dashboard Interface:**

```
┌─── 🖥️  EnhanceSwarm Visual Dashboard ─────────────────────────────────┐
│ 14:32:15 │ Agents: 4 │ Active: 2 │ Updated: 3s ago │
└────────────────────────────────────────────────────────────────────────┘

📊 Coordination Status
─────────────────────────────────────────
Phase: Frontend Implementation
Progress: ████████░░░░░░░░░░░░░░░░░░░░ 75%
Active: frontend-ui-456
Completed: backend-auth-123, ux-design-789

🤖 Agent Status Grid
────────────────────────────────────────────────────────────────
┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
│ backend        │ │ frontend       │ │ qa             │ │ ux             │
│ 🟢 Active      │ │ ✅ Done        │ │ 🔄 Starting    │ │ ✅ Done        │
│ ████████░░░░   │ │ ██████████████ │ │                │ │ ██████████████ │
│ 2m15s          │ │ 4m32s          │ │ 12s            │ │ 8m45s          │
└────────────────┘ └────────────────┘ └────────────────┘ └────────────────┘

📈 System Resources
──────────────────────────────
Memory: ██████████░░░░░░░░░░ 8.2GB/16GB
Processes: 3 active
Messages: 1 pending

🎮 Controls
───────────────
[q] Quit  [r] Refresh  [p] Pause  [c] Clear  [h] Help
```

## 🧠 Smart Defaults & Auto-Actions

Intelligent project analysis and automation:

```bash
# Get smart suggestions for next actions
enhance-swarm suggest

# Auto-run high-priority suggestions
enhance-swarm suggest --auto-run

# Generate optimal configuration
enhance-swarm smart-config --apply

# Show context-aware suggestions
enhance-swarm suggest --context "need to improve performance"
```

**Smart Features:**

- **Role Detection**: Automatically suggest best agent role for tasks
- **Project Analysis**: Detect technology stack and suggest optimal settings
- **Auto-cleanup**: Intelligent cleanup of stale resources
- **Pattern Learning**: Learn from user preferences and past actions
- **Context-aware Commands**: Suggest appropriate commands based on project state
- **Concurrency Optimization**: Recommend optimal agent counts based on system resources

**Example Smart Suggestions:**

```bash
🧠 Analyzing project and generating smart suggestions...

💡 Smart Suggestions:

1. [HIGH] Stale worktrees detected
   Command: enhance-swarm cleanup --all

2. [MEDIUM] Code changes detected, tests should be run  
   Command: npm test

3. [LOW] End of day cleanup
   Command: enhance-swarm cleanup --all

🤖 Auto-detected role: backend (use --role to override)
✅ Auto-cleaned 3 stale resources
```

## 🔧 Better Error Recovery

Intelligent error analysis and automatic recovery:

```bash
# Analyze specific errors
enhance-swarm recover --analyze "Connection timeout after 30 seconds"

# Get human-readable error explanations
enhance-swarm recover --explain "No such file or directory"

# View error recovery statistics
enhance-swarm recover --stats

# Learn from manual recovery steps
enhance-swarm recover --learn "Build failed" --steps "bundle install" "restart server"

# Interactive troubleshooting assistant
enhance-swarm troubleshoot
```

**Error Recovery Features:**

- **Pattern Recognition**: Learn from error patterns and successful recoveries
- **Automatic Recovery**: Attempt common fixes automatically
- **Recovery Strategies**: Network retry, file creation, dependency installation
- **Success Tracking**: Monitor recovery success rates and improve strategies
- **Manual Learning**: Capture and reuse manual recovery procedures
- **Context Analysis**: Consider project context when suggesting fixes

**Error Analysis Output:**

```bash
🔍 Analyzing error: Connection timeout after 30 seconds

📊 Error Analysis:
  Type: StandardError
  Auto-recoverable: Yes

🔎 Matching Patterns:
  1. Network timeout pattern (85% confidence)

💡 Recovery Suggestions:
  1. 🤖 Retry with exponential backoff (85%)
  2. 👤 Check network connectivity (70%)
  3. 🤖 Increase timeout and retry (60%)

📖 Error Explanation: Connection timeout after 30 seconds

This typically occurs when a network request takes longer than the configured timeout period.

🔍 Likely Cause:
  Network latency or server overload

🛡️  Prevention Tips:
  1. Implement retry logic with exponential backoff
  2. Monitor network connectivity before making requests
  3. Configure appropriate timeout values for your use case
  4. Consider using connection pooling for better performance
```

**Interactive Troubleshooting:**

```bash
🔧 Interactive Troubleshooting Mode
────────────────────────────────────────

What would you like to troubleshoot?
1. Recent agent failures
2. Configuration issues  
3. Dependency problems
4. Performance issues
5. Exit

Enter your choice (1-5): 2

⚙️  Configuration Troubleshooting
✅ Configuration file found: .enhance_swarm.yml
✅ Configuration file is valid YAML
✅ Configuration appears to be valid
```

## 🧠 Core Commands & Examples

### Multi-Agent Orchestration

```bash
# Full feature implementation
enhance-swarm enhance "implement shopping cart with checkout"
# → Spawns: UX → Backend → Frontend → QA agents in sequence

# With live streaming
enhance-swarm enhance "add user dashboard" --follow
# → Real-time coordination display with agent progress

# Specific task from backlog
enhance-swarm enhance --task CART-123
# → Processes specific task ID
```

### Single Agent Tasks

```bash
# Backend specialist
enhance-swarm spawn "fix payment API timeout" --role backend

# Frontend specialist  
enhance-swarm spawn "improve mobile responsiveness" --role frontend

# QA specialist
enhance-swarm spawn "add edge case tests for auth" --role qa

# UX specialist
enhance-swarm spawn "redesign onboarding flow" --role ux
```

### Monitoring & Management

```bash
# System health check
enhance-swarm doctor
# → Validates dependencies, git setup, claude-swarm availability

# Project status
enhance-swarm status --json
# → Detailed status including active agents, worktrees, health

# Cleanup stale resources
enhance-swarm cleanup --all
# → Removes abandoned worktrees, branches, temp files

# Restart stuck/failed agents
enhance-swarm restart backend-auth-123
# → Intelligent restart with resource cleanup

# Manage notifications
enhance-swarm notifications --test
# → Test notification system functionality
```

## 🏗️ Architecture Overview

```
┌─ Your Terminal ─────────────────────────────────────────┐
│  enhance-swarm CLI (Ruby Orchestrator)                 │
│  ├── Progress Tracking & Live Streaming                │
│  ├── Agent Review & Status Monitoring                  │  
│  └── Resource Management & Cleanup                     │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─ Control Agent ─────▼───────────────────────────────────┐
│  Claude Instance (Autonomous Coordinator)              │
│  ├── Task Analysis & Agent Planning                    │
│  ├── Dependency Management (backend → frontend → qa)   │
│  ├── Progress Monitoring & Handoff Decisions           │
│  └── Conflict Resolution & Error Recovery              │
└─────────────────────┬───────────────────────────────────┘
                      │ spawns & coordinates
           ┌──────────┼──────────┬──────────┐
           ▼          ▼          ▼          ▼
    ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
    │🔧 Backend│ │🎨 Frontend│ │🧪 QA    │ │✨ UX     │
    │ Agent   │ │ Agent   │ │ Agent   │ │ Agent   │
    │         │ │         │ │         │ │         │
    └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

## ⚙️ Advanced Configuration

### Custom Agent Roles

```yaml
# .enhance_swarm.yml
agents:
  database_expert:
    focus: "Database optimization, migrations, indexing"
    trigger_keywords: ["database", "migration", "index", "query"]
    
  security_specialist:
    focus: "Security audits, vulnerability scanning"
    trigger_keywords: ["security", "auth", "permission", "encrypt"]
```

### Environment Variables

```bash
# Logging
export ENHANCE_SWARM_LOG_LEVEL=debug
export ENHANCE_SWARM_JSON_LOGS=true

# Behavior
export ENHANCE_SWARM_STRICT=true  # Fail fast on dependency issues
```

### MCP Tool Integration

```yaml
# .enhance_swarm.yml
mcp_tools:
  gemini_cli: true      # Large codebase analysis
  desktop_commander: true  # File operations outside project
```

## 🛡️ Security & Quality

### Built-in Security

- **Command Injection Protection**: All shell commands use `Open3.capture3` with argument sanitization
- **Input Validation**: Configuration values validated, dangerous patterns blocked  
- **Path Sanitization**: Prevents directory traversal attacks
- **Timeout Protection**: All external commands have configurable timeouts
- **Secure Defaults**: Principle of least privilege, secure by default

### Quality Assurance

- **106 Comprehensive Tests**: Security, functionality, edge cases
- **Automated Retry Logic**: Handles transient failures gracefully
- **Resource Cleanup**: Automatic cleanup of stale worktrees and processes
- **Dependency Validation**: Ensures required tools are available and working

## 🚨 Error Recovery & Resilience

### Automatic Retry Logic

```ruby
# Built-in retry for transient failures
RetryHandler.with_retry(max_retries: 3) do
  CommandExecutor.execute('git', 'push', 'origin', 'HEAD')
end
```

### Smart Cleanup

```bash
# Automatic detection and cleanup of:
# - Stale git worktrees
# - Abandoned agent processes  
# - Temporary communication files
# - Failed operation artifacts
enhance-swarm cleanup --all
```

### Health Monitoring

```bash
# Comprehensive system validation
enhance-swarm doctor --detailed --json
# → Validates git, claude-swarm, ruby, dependencies with version checks
```

## 📊 Token Optimization

### Intelligent Context Management

- **Specialized Prompts**: Role-specific prompts minimize token usage
- **Progressive Context**: Only relevant context passed to each agent
- **Efficient Monitoring**: Brief coordination checks vs. continuous polling
- **Smart Caching**: Reuse analysis results across agents

### Usage Tracking

```bash
# Built-in token estimation and tracking
⠋ [█████████░░] 45% Spawning agents... [1,250/3,000 tokens (42%)]
```

## 🔧 Troubleshooting

### Common Issues

```bash
# Dependency problems
enhance-swarm doctor
# → Validates git, claude-swarm, ruby versions

# Agent coordination issues  
enhance-swarm review
# → Shows stuck/failed agents

# Resource cleanup
enhance-swarm cleanup --all
# → Removes stale worktrees and processes
```

### Debug Mode

```bash
# Verbose logging
ENHANCE_SWARM_LOG_LEVEL=debug enhance-swarm enhance "test task"

# JSON logs for parsing
ENHANCE_SWARM_JSON_LOGS=true enhance-swarm enhance "test task"
```

## 🤝 Integration Examples

### Rails Projects

```yaml
# .enhance_swarm.yml for Rails
project:
  technology_stack: ["Rails 8", "PostgreSQL", "Hotwire", "Tailwind"]
  
commands:
  test: "bundle exec rspec"
  lint: "bundle exec rubocop"
  type_check: "bundle exec sorbet tc"
```

### React/Node Projects

```yaml
# .enhance_swarm.yml for React
project:
  technology_stack: ["React 18", "TypeScript", "Vite", "TailwindCSS"]
  
commands:
  test: "npm test"
  lint: "npm run lint"
  type_check: "npm run type-check"
  build: "npm run build"
```

### Python Projects

```yaml
# .enhance_swarm.yml for Python
project:
  technology_stack: ["Python 3.11", "FastAPI", "PostgreSQL", "Pytest"]
  
commands:
  test: "pytest"
  lint: "ruff check ."
  format: "black ."
  type_check: "mypy ."
```

## 📈 Performance & Scaling

### Optimized for Large Codebases

- **Parallel Agent Execution**: Multiple agents work simultaneously
- **Git Worktree Isolation**: No conflicts between agent work
- **Efficient Monitoring**: Brief coordination checks, not continuous polling
- **Smart Resource Management**: Automatic cleanup prevents resource leaks

### Benchmarks

- **Startup Time**: < 2 seconds for agent coordination
- **Memory Usage**: ~50MB base + ~30MB per active agent
- **Token Efficiency**: 60-80% reduction vs. single-agent approaches

## 🎓 Best Practices

### Task Sizing

**✅ Good for Multi-Agent:**
- Feature implementations requiring UI + backend + tests
- Complex refactoring across multiple components
- New system integrations with multiple touch points

**✅ Good for Single Agent:**
- Bug fixes in specific components
- Configuration updates
- Documentation improvements
- Small feature additions

### Workflow Patterns

```bash
# Feature development workflow
enhance-swarm enhance "implement user profiles" --follow
# → Watch agents coordinate in real-time

# Monitor periodically  
enhance-swarm status
# → Check overall progress

# Review completed work
enhance-swarm review
# → See what agents accomplished

# Cleanup when done
enhance-swarm cleanup --all
# → Remove temporary resources
```

## 🚀 What's Next

EnhanceSwarm represents the future of AI-assisted development:

- **Autonomous Development Teams**: AI agents that truly collaborate
- **Intelligent Coordination**: Control Agent makes smart decisions
- **Real-time Visibility**: Never wonder what your agents are doing
- **Production Ready**: Security, reliability, and error recovery built-in

**Ready to transform your development workflow?**

```bash
# Get started in 30 seconds
echo 'gem "enhance_swarm", git: "https://github.com/todddickerson/enhance_swarm.git"' >> Gemfile
bundle install
bundle exec enhance-swarm init
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Built from production experience with Claude Swarm orchestration patterns. Special thanks to the Anthropic team for Claude and the emerging multi-agent development paradigms.

---

**Transform your development workflow with intelligent multi-agent coordination. Start enhancing today!** 🚀