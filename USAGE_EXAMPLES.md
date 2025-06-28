# EnhanceSwarm UX Features - Usage Examples

This document shows how to use the 6 major UX improvements in EnhanceSwarm, both via CLI commands and programmatically.

## ✅ Confirmed Working Features

### 🎯 UX #1: Live Agent Output Streaming

**CLI Usage:**
```bash
# Stream live output during orchestration
enhance-swarm enhance "implement user auth" --follow

# Stream output from single agent
enhance-swarm spawn "fix login bug" --role backend --follow
```

**Programmatic Usage:**
```ruby
# Create output streamer
streamer = EnhanceSwarm::OutputStreamer.new(agent_id: 'backend-123')

# Stream with progress tracking
streamer.stream_with_progress do |progress|
  puts "Progress: #{progress[:percentage]}% - #{progress[:current_task]}"
end

# Custom streaming with callbacks
streamer.start_streaming(
  on_output: ->(line) { puts "[AGENT] #{line}" },
  on_progress: ->(pct) { puts "Progress: #{pct}%" },
  on_complete: -> { puts "Agent completed!" }
)
```

### 🔔 UX #2: Smart Notifications & Interrupts  

**CLI Usage:**
```bash
# Test notification system
enhance-swarm notifications --test

# Enable/disable notifications
enhance-swarm notifications --enable
enhance-swarm notifications --disable

# Show notification status
enhance-swarm notifications
```

**Programmatic Usage:**
```ruby
# Get notification manager
nm = EnhanceSwarm::NotificationManager.instance

# Send different types of notifications
nm.agent_completed('backend-123', 'backend', 300)
nm.agent_failed('frontend-456', 'Connection timeout', { retry_count: 3 })
nm.progress_milestone('system', 'Backend tests passing', 75)

# Configure notification preferences
nm.configure(
  desktop_notifications: true,
  sound_alerts: true,
  priority_filter: :medium  # :low, :medium, :high, :critical
)

# Set up interrupt handling
interrupt_handler = EnhanceSwarm::InterruptHandler.new(nm)
interrupt_handler.enable_interrupts!

# Handle stuck agents
result = interrupt_handler.handle_agent_stuck(agent)
# => { action: :restart, success: true }
```

### 💬 UX #3: Quick Agent Communication

**CLI Usage:**
```bash
# Demo agent communication
enhance-swarm communicate --demo

# Show communication status
enhance-swarm communicate --status
enhance-swarm communicate
```

**Programmatic Usage:**
```ruby
# Get communicator
comm = EnhanceSwarm::AgentCommunicator.instance

# Agent asks questions with quick actions
comm.agent_question(
  'backend-auth', 
  'Should I use Devise or build custom auth?',
  ['Devise', 'Custom', 'Research both'],
  priority: :high,
  timeout: 300
)

# Agent sends status updates
comm.agent_status('frontend-ui', 'Components 80% complete')

# Agent reports progress
comm.agent_progress('qa-tests', 'Running integration tests...', 65)

# Agent requests decisions
comm.agent_decision(
  'backend-db',
  'Database schema migration needed. Proceed?',
  ['Yes', 'No', 'Review first']
)

# Check for pending messages
pending = comm.pending_messages
recent = comm.recent_messages(10)

# Respond to messages
comm.respond_to_message('msg_123', 'Use Devise for faster development')
```

### 🖥️ UX #4: Visual Agent Dashboard

**CLI Usage:**
```bash
# Start dashboard with running agents
enhance-swarm dashboard

# Take a snapshot
enhance-swarm dashboard --snapshot

# Monitor specific agents
enhance-swarm dashboard --agents backend-123 frontend-456

# Custom refresh rate
enhance-swarm dashboard --refresh 1
```

**Programmatic Usage:**
```ruby
# Get dashboard instance
dashboard = EnhanceSwarm::VisualDashboard.instance

# Start dashboard with agents
agents = [
  { id: 'backend-123', role: 'backend', status: 'running', progress: 75 },
  { id: 'frontend-456', role: 'frontend', status: 'completed', progress: 100 }
]

dashboard.start_dashboard(agents)

# Display snapshot
dashboard.display_snapshot(agents)

# Configure dashboard
dashboard.configure(
  refresh_rate: 2,
  show_system_resources: true,
  color_scheme: :dark
)

# Get dashboard status
status = dashboard.get_status
# => {
#   active_agents: 2,
#   total_memory: "8.2GB",
#   system_load: 0.45
# }
```

### 🧠 UX #5: Smart Defaults & Auto-Actions

**CLI Usage:**
```bash
# Get smart suggestions
enhance-swarm suggest

# Get suggestions with context
enhance-swarm suggest --context "need better performance"
```

**Programmatic Usage:**
```ruby
# Get smart defaults instance
sd = EnhanceSwarm::SmartDefaults.instance

# Get suggestions for current context
context = {
  git_status: { modified_files: 5, untracked_files: 2 },
  project_files: { ruby_files: 20, test_files: 15 },
  recent_actions: ['enhance', 'spawn backend']
}

suggestions = sd.get_suggestions(context)
# => [
#   { priority: :high, description: "Run tests before commit", command: "rspec" },
#   { priority: :medium, description: "Clean up stale worktrees", command: "enhance-swarm cleanup --all" }
# ]

# Auto-detect role for task
role = sd.suggest_role_for_task("implement payment API endpoints")
# => "backend"

# Generate smart configuration
config = sd.generate_smart_config
sd.apply_config(config)

# Learn from user actions
sd.learn_from_action('enhance', { 
  task: 'implement auth',
  role_used: 'backend',
  success: true 
})

# Auto-cleanup with intelligence
cleanup_count = sd.auto_cleanup_if_needed
# => 3 (number of resources cleaned)
```

### 🔧 UX #6: Better Error Recovery

**CLI Usage:**
```bash
# Analyze specific error
enhance-swarm recover --analyze "Connection timeout after 30 seconds"

# Show recovery statistics
enhance-swarm recover --stats

# Demo error recovery features
enhance-swarm recover --demo
```

**Programmatic Usage:**
```ruby
# Get error recovery instance
er = EnhanceSwarm::ErrorRecovery.instance

# Analyze an error
begin
  # Some operation that might fail
  result = risky_operation()
rescue StandardError => e
  analysis = er.analyze_error(e, { agent_id: 'backend-123', context: 'database_operation' })
  
  # => {
  #   error: { type: 'StandardError', message: '...', timestamp: '...' },
  #   patterns: [...],
  #   suggestions: [
  #     { description: 'Retry with exponential backoff', auto_executable: true },
  #     { description: 'Check network connectivity', auto_executable: false }
  #   ],
  #   auto_recoverable: true
  # }
  
  # Attempt automatic recovery
  if analysis[:auto_recoverable]
    recovery_result = er.attempt_recovery(analysis, {
      retry_block: -> { risky_operation() },
      timeout: 60
    })
    
    if recovery_result[:success]
      puts "✅ Automatically recovered!"
    else
      puts "❌ Recovery failed, manual intervention needed"
    end
  end
end

# Get human-readable error explanation
explanation = er.explain_error(error, context: { operation: 'database_query' })
# => {
#   explanation: "Connection timeout typically occurs when...",
#   likely_cause: "Network latency or server overload",
#   prevention_tips: ["Implement retry logic", "Monitor connectivity", ...]
# }

# Learn from manual recovery
er.learn_from_manual_recovery(
  error,
  ['restart database service', 'clear connection pool', 'retry operation'],
  { success: true, time_taken: 45 }
)

# Get recovery statistics
stats = er.recovery_statistics
# => {
#   total_errors_processed: 25,
#   successful_automatic_recoveries: 18,
#   recovery_success_rate: 72.0,
#   most_common_errors: { "ConnectionError" => 8, "TimeoutError" => 5 }
# }

# Clean up old data
er.cleanup_old_data(30) # Keep last 30 days
```

## 🎛️ Integrated Workflows

### Complete Development Workflow

```ruby
# 1. Enable notifications and smart features
nm = EnhanceSwarm::NotificationManager.instance
nm.enable!

sd = EnhanceSwarm::SmartDefaults.instance
sd.auto_cleanup_if_needed

# 2. Start with smart suggestions
suggestions = sd.get_suggestions({})
high_priority = suggestions.select { |s| s[:priority] == :high }

# 3. Execute enhancement with full monitoring
orchestrator = EnhanceSwarm::Orchestrator.new
orchestrator.enhance(
  task: "implement user dashboard",
  follow: true,
  notifications: true
)

# 4. Monitor via dashboard
dashboard = EnhanceSwarm::VisualDashboard.instance
dashboard.start_dashboard(orchestrator.active_agents)

# 5. Handle any errors automatically
EnhanceSwarm::ErrorRecovery.instance.enable_auto_recovery!
```

### Agent Communication Workflow

```ruby
comm = EnhanceSwarm::AgentCommunicator.instance

# Agent asks for user input
response = comm.agent_question(
  'backend-db',
  'Database migration will modify user table. Proceed?',
  ['Yes', 'No', 'Review SQL first'],
  timeout: 300
)

# User responds
comm.respond_to_message(response[:message_id], 'Review SQL first')

# Agent provides more details
comm.agent_status('backend-db', 'Generating migration preview...')

# Continue workflow based on response
case response[:text]
when 'Yes'
  comm.agent_status('backend-db', 'Running migration...')
when 'Review SQL first'
  comm.agent_question('backend-db', 'Migration SQL: ALTER TABLE users ADD COLUMN role VARCHAR(50); Proceed?', ['Yes', 'No'])
end
```

## 🚀 Integration with Existing Tools

### Rails Integration

```ruby
# In your Rails app
class ApplicationController < ActionController::Base
  before_action :setup_enhance_swarm
  
  private
  
  def setup_enhance_swarm
    if Rails.env.development?
      @enhancer = EnhanceSwarm::SmartDefaults.instance
      @notifier = EnhanceSwarm::NotificationManager.instance
      @notifier.enable! if params[:enhance_notifications]
    end
  end
end

# In rake tasks
task enhance_and_test: :environment do
  orchestrator = EnhanceSwarm::Orchestrator.new
  
  # Run enhancement with error recovery
  begin
    result = orchestrator.enhance(task: "optimize database queries")
    
    if result[:success]
      # Run tests to verify
      system('bundle exec rspec')
    end
  rescue => e
    recovery = EnhanceSwarm::ErrorRecovery.instance
    recovery.analyze_error(e, context: { task: 'optimization', environment: 'test' })
  end
end
```

### CI/CD Integration

```yaml
# .github/workflows/enhance-swarm.yml
name: EnhanceSwarm Integration
on: [push]

jobs:
  enhance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3.0
      - name: Install EnhanceSwarm
        run: |
          bundle add enhance_swarm
          bundle exec enhance-swarm init
      - name: Run Enhancement
        run: |
          bundle exec enhance-swarm enhance "optimize performance" --notifications=false
      - name: Verify Results
        run: |
          bundle exec enhance-swarm troubleshoot
          bundle exec rspec
```

## 📊 Monitoring and Analytics

```ruby
# Custom monitoring setup
class EnhanceSwarmMonitor
  def initialize
    @dashboard = EnhanceSwarm::VisualDashboard.instance
    @notifications = EnhanceSwarm::NotificationManager.instance
    @recovery = EnhanceSwarm::ErrorRecovery.instance
  end
  
  def daily_report
    stats = @recovery.recovery_statistics
    
    report = {
      date: Date.current,
      enhancements_run: count_enhancements_today,
      success_rate: stats[:recovery_success_rate],
      common_errors: stats[:most_common_errors],
      agent_usage: @dashboard.get_usage_stats
    }
    
    # Send notification with daily summary
    @notifications.daily_summary(report)
    
    report
  end
  
  def health_check
    {
      notifications: @notifications.enabled?,
      dashboard: @dashboard.available?,
      error_recovery: @recovery.recovery_statistics[:total_errors_processed],
      last_enhancement: File.mtime('.enhance_swarm.yml') rescue nil
    }
  end
end
```

## 🎯 Best Practices

1. **Always enable notifications for long-running enhancements**
2. **Use the dashboard to monitor multiple agents**
3. **Let error recovery handle transient failures automatically**
4. **Use smart suggestions to optimize your workflow**
5. **Set up agent communication for complex decisions**
6. **Run troubleshooting when issues arise**

For more examples and advanced usage, see the main README.md file.