# EnhanceSwarm v1.0 Deployment Guide

## 🚀 Production Deployment

### Prerequisites

1. **Claude CLI**: Install from [Claude Code](https://claude.ai/code)
   ```bash
   # Verify installation
   claude --version
   # Should show: 1.0.x (Claude Code)
   ```

2. **Ruby Environment**: Ruby 3.0+ required
   ```bash
   ruby --version
   # Should show: ruby 3.x.x
   ```

3. **Git**: For project management and agent worktrees
   ```bash
   git --version
   # Should show: git version 2.x.x
   ```

### Installation Methods

#### Option 1: Project-Specific Installation (Recommended)

```bash
# Add to existing project
echo 'gem "enhance_swarm", git: "https://github.com/todddickerson/enhance_swarm.git", tag: "v1.0.0"' >> Gemfile
bundle install

# Initialize in project
bundle exec enhance-swarm init

# Verify installation
bundle exec enhance-swarm doctor
```

#### Option 2: Global Installation

```bash
# Clone and install globally
git clone https://github.com/todddickerson/enhance_swarm.git
cd enhance_swarm
git checkout v1.0.0
bundle install && rake install

# Verify global installation
enhance-swarm --version
enhance-swarm doctor
```

#### Option 3: Gem Installation (when published)

```bash
# Install from RubyGems (future release)
gem install enhance_swarm

# Verify installation
enhance-swarm --version
enhance-swarm doctor
```

### Initial Configuration

1. **Project Initialization**
   ```bash
   cd your-project
   enhance-swarm init
   ```

2. **Verify Configuration**
   ```bash
   # Check generated configuration
   cat .enhance_swarm.yml
   
   # Validate configuration
   enhance-swarm config
   ```

3. **Test Integration**
   ```bash
   # Comprehensive system check
   enhance-swarm doctor --detailed
   
   # Test Claude CLI integration
   enhance-swarm spawn "echo 'Hello from EnhanceSwarm v1.0'" --role general
   ```

### Framework-Specific Setup

#### Rails Projects

```yaml
# .enhance_swarm.yml for Rails
project:
  name: "MyRailsApp"
  technology_stack: ["Rails 8", "PostgreSQL", "Hotwire", "Tailwind"]
  
commands:
  test: "bundle exec rspec"
  lint: "bundle exec rubocop"
  build: "bundle exec rake assets:precompile"
  
orchestration:
  max_concurrent_agents: 3
  preferred_agents: ["backend", "frontend", "qa"]
```

#### React/Node Projects

```yaml
# .enhance_swarm.yml for React
project:
  name: "MyReactApp"
  technology_stack: ["React 18", "TypeScript", "Vite", "TailwindCSS"]
  
commands:
  test: "npm test"
  lint: "npm run lint"
  build: "npm run build"
  type_check: "npx tsc --noEmit"
  
orchestration:
  max_concurrent_agents: 4
  preferred_agents: ["frontend", "ux", "qa"]
```

#### Python/Django Projects

```yaml
# .enhance_swarm.yml for Django
project:
  name: "MyDjangoApp"
  technology_stack: ["Django 5", "PostgreSQL", "React", "pytest"]
  
commands:
  test: "pytest"
  lint: "ruff check ."
  format: "black ."
  type_check: "mypy ."
  
orchestration:
  max_concurrent_agents: 3
  preferred_agents: ["backend", "frontend", "qa"]
```

### Production Usage

#### Starting the Web Dashboard

```bash
# Start web interface for monitoring and control
enhance-swarm ui

# Custom port and host
enhance-swarm ui --port 8080 --host 0.0.0.0
```

#### Multi-Agent Workflows

```bash
# Full feature development with coordination
enhance-swarm enhance "implement user authentication system"

# Single specialized agent
enhance-swarm spawn "optimize database queries" --role backend

# Web-based task management
enhance-swarm ui  # Use kanban board for task creation
```

#### Monitoring and Management

```bash
# Check system status
enhance-swarm status

# Monitor running agents
enhance-swarm status --json | jq '.agents'

# Clean up stale resources
enhance-swarm cleanup --all
```

### Environment Configuration

#### Environment Variables

```bash
# Logging
export ENHANCE_SWARM_LOG_LEVEL=info
export ENHANCE_SWARM_JSON_LOGS=false

# Performance
export ENHANCE_SWARM_MAX_AGENTS=4
export ENHANCE_SWARM_TIMEOUT=300

# Debugging
export ENHANCE_SWARM_DEBUG=false
export ENHANCE_SWARM_VERBOSE=false
```

#### System Limits

```bash
# Recommended system resources
# RAM: 4GB+ (8GB+ for large projects)
# CPU: 2+ cores
# Disk: 1GB+ free space for worktrees
```

### Security Considerations

#### File Permissions

```bash
# Ensure proper permissions for generated files
chmod 644 .enhance_swarm.yml
chmod -R 644 .claude/

# Git hooks should be executable
chmod +x .git/hooks/*
```

#### Input Validation

- All configuration values are automatically sanitized
- Shell commands use secure `Open3.capture3` execution
- Command injection protection is enabled by default
- Path traversal attacks are prevented

### Troubleshooting

#### Common Issues

1. **Claude CLI Not Found**
   ```bash
   # Install Claude CLI from https://claude.ai/code
   # Verify with: claude --version
   ```

2. **Permission Errors**
   ```bash
   # Fix git hooks permissions
   chmod +x .git/hooks/pre-commit
   
   # Fix worktree permissions
   chmod -R 755 .enhance_swarm/worktrees/
   ```

3. **Agent Spawning Failures**
   ```bash
   # Check Claude CLI integration
   enhance-swarm doctor --detailed
   
   # Enable debug logging
   ENHANCE_SWARM_LOG_LEVEL=debug enhance-swarm spawn "test task"
   ```

#### Diagnostic Commands

```bash
# Comprehensive system validation
enhance-swarm doctor --detailed --json

# Test real Claude CLI integration
enhance-swarm spawn "echo 'Test successful'" --role general

# Validate project analysis
enhance-swarm config --analyze
```

### Performance Optimization

#### Agent Configuration

```yaml
# Optimize for your system
orchestration:
  max_concurrent_agents: 2  # Start conservative
  monitor_interval: 30      # Seconds between status checks
  agent_timeout: 300        # Maximum agent execution time
```

#### Resource Management

```bash
# Regular cleanup to prevent resource leaks
enhance-swarm cleanup --all

# Monitor system resources
enhance-swarm status --resources
```

### Upgrading

#### From v0.x to v1.0

1. **Backup Configuration**
   ```bash
   cp .enhance_swarm.yml .enhance_swarm.yml.backup
   ```

2. **Update Gem**
   ```bash
   # In Gemfile
   gem "enhance_swarm", git: "https://github.com/todddickerson/enhance_swarm.git", tag: "v1.0.0"
   bundle install
   ```

3. **Reinitialize Configuration**
   ```bash
   enhance-swarm init --force
   ```

4. **Validate Upgrade**
   ```bash
   enhance-swarm doctor
   enhance-swarm --version  # Should show 1.0.0
   ```

### Support and Documentation

- **README**: Comprehensive feature documentation
- **CHANGELOG**: Detailed release notes and migration guide
- **Issues**: [GitHub Issues](https://github.com/todddickerson/enhance_swarm/issues)
- **Discussions**: [GitHub Discussions](https://github.com/todddickerson/enhance_swarm/discussions)

### Validation Checklist

- [ ] Claude CLI installed and working (`claude --version`)
- [ ] Ruby 3.0+ available (`ruby --version`)
- [ ] Git configured and working (`git --version`)
- [ ] Project initialized (`enhance-swarm init`)
- [ ] Configuration validated (`enhance-swarm config`)
- [ ] System check passed (`enhance-swarm doctor`)
- [ ] Test agent spawned successfully
- [ ] Web dashboard accessible (`enhance-swarm ui`)

EnhanceSwarm v1.0 is production-ready and validated across multiple project types and environments. Follow this guide for reliable deployment and optimal performance.