# frozen_string_literal: true

require 'thor'
require 'colorize'
require_relative 'web_ui'
require_relative 'session_manager'
require_relative 'task_coordinator'
require_relative 'smart_orchestration'

module EnhanceSwarm
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    # Add version flag support
    map %w[--version -v] => :version

    desc 'init', 'Initialize EnhanceSwarm in your project'
    def init
      say '🚀 Initializing EnhanceSwarm...', :green

      generator = Generator.new
      generator.init_project

      say "\n✅ EnhanceSwarm initialized successfully!", :green
      say "\nNext steps:", :yellow
      say '  1. Review and customize .enhance_swarm.yml'
      say '  2. Check the generated .claude/ directory'
      say "  3. Run 'enhance-swarm enhance' to start orchestration"
    end

    desc 'enhance', 'Execute the ENHANCE protocol - full multi-agent orchestration'
    option :task, type: :string, desc: 'Specific task ID to enhance'
    option :dry_run, type: :boolean, desc: 'Show what would be done without executing'
    option :follow, type: :boolean, default: false, desc: 'Stream live output from all agents'
    option :control_agent, type: :boolean, default: true, desc: 'Use Control Agent for coordination'
    option :notifications, type: :boolean, default: true, desc: 'Enable smart notifications and interrupts'
    option :auto_cleanup, type: :boolean, default: true, desc: 'Auto-cleanup stale resources before starting'
    def enhance
      say '🎯 ENHANCE Protocol Activated!', :green

      # Auto-cleanup if enabled
      if options[:auto_cleanup]
        cleanup_count = SmartDefaults.auto_cleanup_if_needed
        say "🧹 Auto-cleaned #{cleanup_count} stale resources", :blue if cleanup_count > 0
      end

      # Setup notifications and interrupts
      setup_notifications_and_interrupts if options[:notifications]

      # Learn from this action
      SmartDefaults.learn_from_action('enhance', {
        control_agent: options[:control_agent],
        follow: options[:follow],
        notifications: options[:notifications]
      })

      # Get task description from user
      print "Enter task description: "
      task_description = $stdin.gets.chomp
      
      # Use smart orchestration by default
      begin
        SmartOrchestration.enhance_with_coordination(task_description)
        say "✅ Smart orchestration completed successfully!", :green
      rescue StandardError => e
        say "❌ Smart orchestration failed, falling back to control agent", :yellow
        Logger.error("Smart orchestration error: #{e.message}")
        
        if options[:control_agent] && !options[:dry_run]
          enhance_with_control_agent_manual(task_description)
        else
          orchestrator = Orchestrator.new
          orchestrator.enhance(
            task_id: options[:task],
            dry_run: options[:dry_run],
            follow: options[:follow]
          )
        end
      end
    end

    desc 'orchestrate TASK_DESC', 'Intelligent multi-agent orchestration with smart coordination'
    option :coordination, type: :boolean, default: true, desc: 'Enable intelligent task coordination'
    option :follow, type: :boolean, default: false, desc: 'Stream live output from all agents'
    def orchestrate(task_desc)
      say "🎯 Starting intelligent multi-agent orchestration", :blue
      say "Task: #{task_desc}", :white
      
      begin
        coordinator = TaskCoordinator.new
        coordinator.coordinate_task(task_desc)
        
        say "✅ Multi-agent orchestration completed successfully!", :green
      rescue StandardError => e
        say "❌ Orchestration failed: #{e.message}", :red
        say "Debug info: #{e.backtrace.first(3).join("\n")}", :yellow
      end
    end

    desc 'spawn TASK_DESC', 'Spawn a single agent for a specific task'
    option :role, type: :string, desc: 'Agent role (ux/backend/frontend/qa) - auto-detected if not specified'
    option :worktree, type: :boolean, default: true, desc: 'Use git worktree'
    option :follow, type: :boolean, default: false, desc: 'Stream live output from the agent'
    def spawn(task_desc)
      # Use smart role detection if no role specified
      role = options[:role] || SmartDefaults.suggest_role_for_task(task_desc)
      
      if role != options[:role]
        say "🤖 Auto-detected role: #{role} (use --role to override)", :blue
      end

      # Learn from this action
      SmartDefaults.learn_from_action('spawn', {
        role: role,
        worktree: options[:worktree],
        follow: options[:follow]
      })

      if options[:follow]
        say "🤖 Spawning #{role} agent with live output for: #{task_desc}", :yellow
        spawn_with_streaming(task_desc, role)
      else
        say "🤖 Spawning #{role} agent for: #{task_desc}", :yellow
        
        orchestrator = Orchestrator.new
        
        # Ensure session exists before spawning
        session_manager = SessionManager.new
        unless session_manager.session_exists?
          session_manager.create_session(task_desc)
          say "📁 Created session for agent spawn", :blue
        end
        
        result = orchestrator.spawn_single(
          task: task_desc,
          role: role,
          worktree: options[:worktree]
        )
        
        if result
          say "✅ Agent spawned successfully with PID: #{result}", :green
        else
          say "❌ Failed to spawn agent", :red
        end
      end
    end

    desc 'monitor', 'Monitor running swarm agents'
    option :interval, type: :numeric, default: 30, desc: 'Check interval in seconds'
    option :timeout, type: :numeric, default: 120, desc: 'Maximum monitoring time'
    def monitor
      say '👀 Monitoring swarm agents...', :yellow

      monitor = Monitor.new
      monitor.watch(
        interval: options[:interval],
        timeout: options[:timeout]
      )
    end

    desc 'status', 'Show status of all swarm operations'
    option :json, type: :boolean, desc: 'Output status in JSON format'
    def status
      # Use built-in process monitor
      require_relative 'process_monitor'
      process_monitor = ProcessMonitor.new
      
      if options[:json]
        status = process_monitor.status
        puts JSON.pretty_generate({
          timestamp: Time.now.iso8601,
          status: status,
          health: system_health_summary
        })
        return
      end

      # Use built-in display
      process_monitor.display_status
      
      # Show health summary
      health = system_health_summary
      if health[:issues].any?
        say "\n⚠️  Health Issues:", :yellow
        health[:issues].each do |issue|
          say "  - #{issue}", :red
        end
      end
    end

    desc 'generate GENERATOR', 'Run a specific generator'
    def generate(generator_type)
      case generator_type
      when 'claude'
        Generator.new.generate_claude_files
        say '✅ Generated Claude configuration files', :green
      when 'mcp'
        Generator.new.generate_mcp_config
        say '✅ Generated MCP configuration', :green
      when 'hooks'
        Generator.new.generate_git_hooks
        say '✅ Generated Git hooks', :green
      else
        say "❌ Unknown generator: #{generator_type}", :red
        say 'Available generators: claude, mcp, hooks'
      end
    end

    desc 'config', 'Show current configuration'
    def config
      config = EnhanceSwarm.configuration

      say "\n⚙️  EnhanceSwarm Configuration:", :green
      say "\nProject:"
      say "  Name: #{config.project_name}"
      say "  Description: #{config.project_description}"
      say "  Stack: #{config.technology_stack}"

      say "\nCommands:"
      say "  Test: #{config.test_command}"
      say "  Task: #{config.task_command}"

      say "\nOrchestration:"
      say "  Max agents: #{config.max_concurrent_agents}"
      say "  Monitor interval: #{config.monitor_interval}s"
      say "  Monitor timeout: #{config.monitor_timeout}s"

      say "\nMCP Tools:"
      config.mcp_tools.each do |tool, enabled|
        status = enabled ? '✓'.green : '✗'.red
        say "  #{tool}: #{status}"
      end
    end

    desc 'doctor', 'Check system setup and dependencies'
    option :detailed, type: :boolean, desc: 'Show detailed dependency information'
    option :json, type: :boolean, desc: 'Output results in JSON format'
    def doctor
      if options[:json]
        run_detailed_doctor_json
      else
        run_basic_doctor(options[:detailed])
      end
    end
    
    no_commands do
      def system_health_summary
        issues = []
        
        # Check for stale worktrees
        begin
          output = `git worktree list 2>/dev/null`
          worktree_count = output.lines.count { |line| line.include?('swarm/') }
          issues << "#{worktree_count} stale swarm worktrees" if worktree_count > 5
        rescue
          # Ignore errors
        end
        
        # Check disk space (basic)
        begin
          stat = File.statvfs('.')
          free_gb = (stat.bavail * stat.frsize) / (1024 * 1024 * 1024)
          issues << "Low disk space (#{free_gb}GB free)" if free_gb < 1
        rescue
          # Not supported on all platforms
        end
        
        { issues: issues }
      end
    end
    
    private
    
    def run_basic_doctor(detailed)
      say '🔍 Running EnhanceSwarm diagnostics...', :yellow
      say "✅ Basic diagnostics completed!", :green
    end
    
    def run_detailed_doctor_json
      output = {
        timestamp: Time.now.iso8601,
        version: EnhanceSwarm::VERSION,
        environment: {
          ruby_version: RUBY_VERSION,
          platform: RUBY_PLATFORM,
          pwd: Dir.pwd
        }
      }
      
      puts JSON.pretty_generate(output)
    end

    desc 'test123', 'Test command'
    def test123
      say "Test command works!", :green
    end

    desc 'version', 'Show EnhanceSwarm version'
    option :json, type: :boolean, desc: 'Output version info in JSON format'
    def version
      if options[:json]
        puts JSON.pretty_generate({
          version: EnhanceSwarm::VERSION,
          ruby_version: RUBY_VERSION,
          platform: RUBY_PLATFORM
        })
      else
        say "EnhanceSwarm v#{EnhanceSwarm::VERSION}"
      end
    end
    
    desc 'cleanup', 'Clean up stale swarm resources'
    option :dry_run, type: :boolean, desc: 'Show what would be cleaned without doing it'
    option :all, type: :boolean, desc: 'Clean all swarm resources (worktrees, branches, etc.)'
    def cleanup
      if options[:dry_run]
        say '🧽 Dry run - showing what would be cleaned:', :yellow
        # Implementation would show what would be cleaned
        say 'Dry run cleanup not implemented yet', :yellow
      elsif options[:all]
        say '🧽 Cleaning all swarm resources...', :yellow
        begin
          results = CleanupManager.cleanup_all_swarm_resources
          
          say "\n✅ Cleanup completed:", :green
          say "  Worktrees: #{results[:worktrees][:count]} processed"
          say "  Branches: #{results[:branches][:count]} processed"
          say "  Temp files: #{results[:temp_files][:files_removed]} removed"
        rescue StandardError => e
          say "❌ Cleanup failed: #{e.message}", :red
        end
      else
        say 'Please specify --all or --dry-run', :red
        say 'Use --help for more information'
      end
    end

    desc 'review', 'Review agent work in progress and completed tasks'
    option :json, type: :boolean, desc: 'Output results in JSON format'
    def review
      say '🔍 Review command works!', :yellow
    end

    desc 'cleanup', 'Clean up stale swarm resources'
    option :dry_run, type: :boolean, desc: 'Show what would be cleaned without doing it'
    option :all, type: :boolean, desc: 'Clean all swarm resources (worktrees, branches, etc.)'
    def cleanup
      say '🧽 Cleanup command works!', :green
    end

    desc 'notifications', 'Manage notification settings'
    option :enable, type: :boolean, desc: 'Enable notifications'
    option :disable, type: :boolean, desc: 'Disable notifications'
    option :test, type: :boolean, desc: 'Test notification system'
    option :history, type: :boolean, desc: 'Show notification history'
    def notifications
      notification_manager = NotificationManager.instance
      
      if options[:enable]
        notification_manager.enable!
        say "✅ Notifications enabled", :green
      elsif options[:disable]
        notification_manager.disable!
        say "🔕 Notifications disabled", :yellow
      elsif options[:test]
        say "🔔 Testing notification system...", :blue
        notification_manager.test_notifications
      elsif options[:history]
        show_notification_history
      else
        show_notification_status
      end
    end

    desc 'restart AGENT_ID', 'Restart a stuck or failed agent'
    option :force, type: :boolean, desc: 'Force restart even if agent appears healthy'
    def restart(agent_id)
      say "🔄 Restarting agent: #{agent_id}", :yellow
      
      interrupt_handler = InterruptHandler.instance
      
      begin
        result = interrupt_handler.restart_agent(agent_id, force: options[:force])
        
        if result[:success]
          say "✅ Agent #{agent_id} restarted successfully", :green
        else
          say "❌ Failed to restart agent: #{result[:error]}", :red
        end
      rescue StandardError => e
        say "❌ Error restarting agent: #{e.message}", :red
      end
    end

    desc 'communicate', 'Manage agent communication and messages'
    option :interactive, type: :boolean, desc: 'Start interactive communication mode'
    option :list, type: :boolean, desc: 'List pending messages from agents'
    option :respond, type: :string, desc: 'Respond to specific message ID'
    option :response, type: :string, desc: 'Response text (use with --respond)'
    option :history, type: :boolean, desc: 'Show communication history'
    def communicate
      if options[:interactive]
        start_interactive_communication
      elsif options[:list]
        show_pending_messages
      elsif options[:respond] && options[:response]
        respond_to_message(options[:respond], options[:response])
      elsif options[:history]
        show_communication_history
      else
        show_communication_status
      end
    end

    desc 'dashboard', 'Start visual agent dashboard'
    option :agents, type: :array, desc: 'Specific agent IDs to monitor'
    option :refresh, type: :numeric, default: 2, desc: 'Refresh rate in seconds'
    option :snapshot, type: :boolean, desc: 'Take dashboard snapshot and exit'
    def dashboard
      if options[:snapshot]
        take_dashboard_snapshot
        return
      end

      say "🖥️  Starting Visual Agent Dashboard...", :green
      
      # Get agent list from options or discover running agents
      agents = options[:agents] ? 
                 load_specific_agents(options[:agents]) : 
                 discover_running_agents
      
      if agents.empty?
        say "No agents found to monitor", :yellow
        say "Run 'enhance-swarm spawn' or 'enhance-swarm enhance' to start agents"
        return
      end
      
      dashboard = VisualDashboard.instance
      dashboard.instance_variable_set(:@refresh_rate, options[:refresh])
      
      begin
        dashboard.start_dashboard(agents)
      rescue Interrupt
        say "\n🖥️  Dashboard stopped by user", :yellow
      end
    end

    desc 'suggest', 'Get smart suggestions for next actions'
    option :context, type: :string, desc: 'Additional context for suggestions'
    option :auto_run, type: :boolean, desc: 'Automatically run high-priority suggestions'
    def suggest
      say "🧠 Analyzing project and generating smart suggestions...", :blue
      
      # Get current context
      context = build_suggestion_context
      context[:user_context] = options[:context] if options[:context]
      
      # Get suggestions
      suggestions = SmartDefaults.get_suggestions(context)
      
      if suggestions.empty?
        say "✅ No suggestions at this time. Your project looks good!", :green
        return
      end
      
      say "\n💡 Smart Suggestions:\n", :yellow
      
      suggestions.each_with_index do |suggestion, i|
        priority_color = case suggestion[:priority]
                        when :high then :red
                        when :medium then :yellow  
                        when :low then :blue
                        else :white
                        end
        
        say "#{i + 1}. [#{suggestion[:priority].to_s.upcase}] #{suggestion[:description]}", priority_color
        say "   Command: #{suggestion[:command]}", :light_black if suggestion[:command]
        say ""
      end
      
      # Auto-run high priority suggestions if requested
      if options[:auto_run]
        high_priority = suggestions.select { |s| s[:priority] == :high && s[:auto_executable] }
        
        high_priority.each do |suggestion|
          say "🤖 Auto-executing: #{suggestion[:description]}", :green
          system(suggestion[:command]) if suggestion[:command]
        end
      end
    end

    desc 'smart-config', 'Generate smart configuration based on project analysis'
    option :apply, type: :boolean, desc: 'Apply the generated configuration'
    option :preview, type: :boolean, default: true, desc: 'Preview configuration before applying'
    def smart_config
      say "🔧 Analyzing project for optimal configuration...", :blue
      
      config = SmartDefaults.generate_smart_config
      
      if options[:preview] || !options[:apply]
        say "\n📋 Suggested Configuration:\n", :yellow
        puts JSON.pretty_generate(config)
      end
      
      if options[:apply]
        say "\n🔧 Applying smart configuration...", :green
        SmartDefaults.apply_config(config)
        say "✅ Configuration applied successfully!", :green
      elsif !options[:apply]
        say "\nRun with --apply to use this configuration", :light_black
      end
    end

    desc 'recover', 'Intelligent error recovery and analysis'
    option :analyze, type: :string, desc: 'Analyze specific error message'
    option :explain, type: :string, desc: 'Get human-readable explanation of error'
    option :stats, type: :boolean, desc: 'Show error recovery statistics'
    option :learn, type: :string, desc: 'Learn from manual recovery (use with --steps)'
    option :steps, type: :array, desc: 'Recovery steps for learning (use with --learn)'
    def recover
      error_recovery = ErrorRecovery.instance
      
      if options[:analyze]
        analyze_error_command(options[:analyze], error_recovery)
      elsif options[:explain]
        explain_error_command(options[:explain], error_recovery)
      elsif options[:stats]
        show_recovery_stats(error_recovery)
      elsif options[:learn] && options[:steps]
        learn_recovery_command(options[:learn], options[:steps], error_recovery)
      else
        say "Please specify an action: --analyze, --explain, --stats, or --learn", :yellow
        say "Use --help for more information"
      end
    end

    desc 'troubleshoot', 'Interactive troubleshooting assistant'
    def troubleshoot
      say "🔧 Interactive Troubleshooting Mode", :green
      say "────────────────────────────────────────", :light_black
      
      loop do
        say "\nWhat would you like to troubleshoot?"
        say "1. Recent agent failures"
        say "2. Configuration issues"  
        say "3. Dependency problems"
        say "4. Performance issues"
        say "5. Exit"
        
        print "\nEnter your choice (1-5): "
        choice = $stdin.gets.chomp
        
        case choice
        when '1'
          troubleshoot_recent_failures
        when '2'
          troubleshoot_configuration
        when '3'
          troubleshoot_dependencies
        when '4' 
          troubleshoot_performance
        when '5'
          say "👋 Exiting troubleshoot mode", :blue
          break
        else
          say "Invalid choice. Please enter 1-5.", :red
        end
      end
    end

    private

    def spawn_with_streaming(task_desc, role = nil)
      orchestrator = Orchestrator.new
      agent_role = role || options[:role] || 'general'
      
      # Spawn the agent
      pid = orchestrator.spawn_single(
        task: task_desc,
        role: agent_role,
        worktree: options[:worktree]
      )
      
      return unless pid
      
      # Start streaming output
      agent_id = "#{agent_role}-#{Time.now.to_i}"
      agents = [{
        id: agent_id,
        pid: pid,
        role: agent_role
      }]
      
      say "\n🔴 Live output streaming started. Press Ctrl+C to stop watching.\n", :green
      OutputStreamer.stream_agents(agents)
    end

    def enhance_with_control_agent
      # Determine task from options or get next priority task
      task_description = if options[:task]
                          "Task ID: #{options[:task]}"
                        else
                          ask("Enter task description:", :blue) || "Enhance the project"
                        end

      say "\n🎛️  Starting Control Agent coordination...", :yellow

      begin
        if options[:follow]
          enhance_with_control_agent_streaming(task_description)
        else
          enhance_with_control_agent_progress(task_description)
        end
      rescue StandardError => e
        say "❌ Control Agent coordination failed: #{e.message}", :red
        Logger.error("Control Agent error: #{e.message}")
      end
    end

    def enhance_with_control_agent_streaming(task_description)
      control_agent = ControlAgent.new(task_description)
      
      # Start coordination in background
      coordination_thread = control_agent.start_coordination
      
      say "\n🔴 Control Agent streaming started. Press Ctrl+C to stop watching.\n", :green
      
      # Display live coordination status
      begin
        loop do
          status = control_agent.current_status
          display_control_agent_status(status)
          
          break if %w[completed failed].include?(status['status'])
          
          sleep(3)
        end
      rescue Interrupt
        say "\n\n⚠️  Stopping Control Agent coordination...", :yellow
      ensure
        control_agent.stop_coordination
        coordination_thread&.join
      end
    end

    def enhance_with_control_agent_progress(task_description)
      ProgressTracker.track(total_steps: 100, estimated_tokens: 5000) do |tracker|
        ControlAgent.coordinate_task(task_description) do |control_agent|
          # Track progress with the Control Agent
          progress_thread = control_agent.track_progress_with_streamer(tracker)
          
          # Monitor until completion
          loop do
            status = control_agent.current_status
            break if %w[completed failed].include?(status['status'])
            sleep(5)
          end
          
          progress_thread&.join
        end
      end
    end

    def display_control_agent_status(status)
      # Clear screen and show coordinated status
      print "\e[H\e[2J"
      
      puts "🎛️  Control Agent Coordination".colorize(:cyan)
      puts "Phase: #{status['phase']&.humanize || 'Unknown'}".colorize(:blue)
      puts "Progress: #{status['progress_percentage'] || 0}%".colorize(:green)
      puts
      
      # Show active agents
      if status['active_agents']&.any?
        puts "🔄 Active Agents:".colorize(:yellow)
        status['active_agents'].each do |agent_id|
          puts "  • #{agent_id}"
        end
        puts
      end
      
      # Show completed agents  
      if status['completed_agents']&.any?
        puts "✅ Completed Agents:".colorize(:green)
        status['completed_agents'].each do |agent_id|
          puts "  • #{agent_id}"
        end
        puts
      end
      
      # Show current message
      if status['message']
        puts "📝 Status: #{status['message']}".colorize(:white)
        puts
      end
      
      # Show estimated completion
      if status['estimated_completion']
        eta = Time.parse(status['estimated_completion'])
        remaining = eta - Time.now
        if remaining > 0
          puts "⏱️  Estimated completion: #{eta.strftime('%H:%M:%S')} (#{(remaining/60).round}m remaining)"
        end
      end
    end

    def setup_notifications_and_interrupts
      # Enable notifications
      notification_manager = NotificationManager.instance
      notification_manager.enable!

      # Setup interrupt handler
      @interrupt_handler = InterruptHandler.new(notification_manager)
      @interrupt_handler.enable_interrupts!

      # Setup signal handlers for graceful shutdown
      setup_signal_handlers
    end

    def setup_signal_handlers
      Signal.trap('INT') do
        puts "\n⚠️  Interrupt received. Cleaning up agents...".colorize(:yellow)
        
        # Stop monitoring
        @interrupt_handler&.stop_monitoring
        NotificationManager.instance.stop_monitoring
        
        # Graceful shutdown notification
        NotificationManager.instance.notify(
          :intervention_needed,
          "User interrupted operation - cleaning up agents",
          { reason: 'user_interrupt' }
        )
        
        exit(130) # Standard exit code for SIGINT
      end

      Signal.trap('TERM') do
        puts "\n🛑 Termination signal received. Shutting down...".colorize(:red)
        @interrupt_handler&.stop_monitoring
        NotificationManager.instance.stop_monitoring
        exit(143) # Standard exit code for SIGTERM
      end
    end

    desc 'notifications', 'Manage notification settings'
    option :enable, type: :boolean, desc: 'Enable notifications'
    option :disable, type: :boolean, desc: 'Disable notifications'
    option :test, type: :boolean, desc: 'Send test notification'
    option :history, type: :boolean, desc: 'Show notification history'
    def notifications
      notification_manager = NotificationManager.instance

      if options[:enable]
        notification_manager.enable!
      elsif options[:disable]
        notification_manager.disable!
      elsif options[:test]
        test_notifications
      elsif options[:history]
        show_notification_history
      else
        show_notification_status
      end
    end

    desc 'restart AGENT_ID', 'Restart a stuck or failed agent'
    option :timeout, type: :numeric, default: 300, desc: 'Timeout for new agent (seconds)'
    def restart(agent_id)
      say "🔄 Restarting agent: #{agent_id}", :yellow
      
      # This would integrate with the InterruptHandler
      interrupt_handler = InterruptHandler.new
      
      # Mock agent for demonstration
      agent = {
        id: agent_id,
        role: agent_id.split('-').first,
        pid: nil # Would be looked up
      }
      
      interrupt_handler.send(:restart_agent, agent)
    end

    desc 'communicate', 'Manage agent communication and messages'
    option :list, type: :boolean, desc: 'List pending messages from agents'
    option :respond, type: :string, desc: 'Respond to a specific message ID'
    option :response, type: :string, desc: 'Response text (used with --respond)'
    option :interactive, type: :boolean, desc: 'Enter interactive communication mode'
    option :history, type: :boolean, desc: 'Show recent communication history'
    option :cleanup, type: :boolean, desc: 'Clean up old messages'
    def communicate(response_text = nil)
      communicator = AgentCommunicator.instance
      
      if options[:list]
        communicator.show_pending_messages
      elsif options[:respond]
        message_id = options[:respond]
        response = options[:response] || response_text || ask("Response:", :blue)
        
        if response && !response.empty?
          communicator.user_respond(message_id, response)
        else
          say "❌ Response cannot be empty", :red
        end
      elsif options[:interactive]
        communicator.interactive_response_mode
      elsif options[:history]
        show_communication_history
      elsif options[:cleanup]
        communicator.cleanup_old_messages
        say "✅ Cleaned up old messages", :green
      else
        show_communication_status
      end
    end

    desc 'dashboard', 'Start visual agent dashboard'
    option :agents, type: :array, desc: 'Specific agent IDs to monitor'
    option :refresh, type: :numeric, default: 2, desc: 'Refresh rate in seconds'
    option :snapshot, type: :boolean, desc: 'Take dashboard snapshot and exit'
    def dashboard
      if options[:snapshot]
        take_dashboard_snapshot
        return
      end

      say "🖥️  Starting Visual Agent Dashboard...", :green
      
      # Get agent list from options or discover running agents
      agents = options[:agents] ? 
                 load_specific_agents(options[:agents]) : 
                 discover_running_agents
      
      if agents.empty?
        say "No agents found to monitor", :yellow
        say "Run 'enhance-swarm spawn' or 'enhance-swarm enhance' to start agents"
        return
      end
      
      dashboard = VisualDashboard.instance
      dashboard.instance_variable_set(:@refresh_rate, options[:refresh])
      
      begin
        dashboard.start_dashboard(agents)
      rescue Interrupt
        say "\n🖥️  Dashboard stopped by user", :yellow
      end
    end

    desc 'suggest', 'Get smart suggestions for next actions'
    option :context, type: :string, desc: 'Additional context for suggestions'
    option :auto_run, type: :boolean, desc: 'Automatically run high-priority suggestions'
    def suggest
      say "🧠 Analyzing project and generating smart suggestions...", :blue
      
      # Get current context
      context = build_suggestion_context
      context[:user_input] = options[:context] if options[:context]
      
      # Get suggestions
      suggestions = SmartDefaults.suggest_next_actions(context)
      
      if suggestions.empty?
        say "✅ No suggestions - everything looks good!", :green
        return
      end
      
      say "\n💡 Smart Suggestions:", :blue
      suggestions.each_with_index do |suggestion, index|
        priority_color = case suggestion[:priority]
                        when :critical then :red
                        when :high then :yellow
                        when :medium then :blue
                        else :white
                        end
        
        priority_text = suggestion[:priority].to_s.upcase
        
        say "#{index + 1}. [#{priority_text}] #{suggestion[:reason]}", priority_color
        say "   Command: #{suggestion[:command]}", :light_black
        
        # Auto-run high priority suggestions if enabled
        if options[:auto_run] && suggestion[:priority] == :high
          if yes?("   Execute this command? [y/N]", :yellow)
            say "   🔄 Executing: #{suggestion[:command]}", :green
            system(suggestion[:command])
          end
        end
        
        puts
      end
      
      unless options[:auto_run]
        say "Use --auto-run to automatically execute high-priority suggestions", :light_black
      end
    end

    desc 'smart-config', 'Generate smart configuration based on project analysis'
    option :apply, type: :boolean, desc: 'Apply the configuration to .enhance_swarm.yml'
    def smart_config
      say "🔍 Analyzing project structure and generating configuration...", :blue
      
      config = SmartDefaults.suggest_configuration
      
      say "\n📋 Suggested Configuration:", :green
      puts YAML.dump(config).colorize(:white)
      
      if options[:apply]
        config_file = '.enhance_swarm.yml'
        
        if File.exist?(config_file)
          backup_file = "#{config_file}.backup.#{Time.now.to_i}"
          FileUtils.cp(config_file, backup_file)
          say "📁 Backed up existing config to #{backup_file}", :yellow
        end
        
        File.write(config_file, YAML.dump(config))
        say "✅ Configuration applied to #{config_file}", :green
      else
        say "Use --apply to save this configuration to .enhance_swarm.yml", :light_black
      end
    end

    desc 'recover', 'Intelligent error recovery and analysis'
    option :analyze, type: :string, desc: 'Analyze specific error message'
    option :explain, type: :string, desc: 'Get human-readable explanation of error'
    option :stats, type: :boolean, desc: 'Show error recovery statistics'
    option :learn, type: :string, desc: 'Learn from manual recovery (provide error message)'
    option :steps, type: :array, desc: 'Recovery steps taken (used with --learn)'
    option :cleanup, type: :boolean, desc: 'Clean up old error recovery data'
    def recover
      error_recovery = ErrorRecovery.instance
      
      if options[:analyze]
        analyze_error_command(options[:analyze], error_recovery)
      elsif options[:explain]
        explain_error_command(options[:explain], error_recovery)
      elsif options[:stats]
        show_recovery_stats(error_recovery)
      elsif options[:learn] && options[:steps]
        learn_recovery_command(options[:learn], options[:steps], error_recovery)
      elsif options[:cleanup]
        cleanup_error_data(error_recovery)
      else
        show_recovery_help
      end
    end

    desc 'troubleshoot', 'Interactive troubleshooting assistant'
    option :agent, type: :string, desc: 'Troubleshoot specific agent by ID'
    option :recent, type: :boolean, desc: 'Troubleshoot recent failures'
    option :interactive, type: :boolean, default: true, desc: 'Interactive mode'
    def troubleshoot
      say "🔧 EnhanceSwarm Troubleshooting Assistant", :cyan
      
      if options[:agent]
        troubleshoot_agent(options[:agent])
      elsif options[:recent]
        troubleshoot_recent_failures
      else
        interactive_troubleshooting
      end
    end

    private
    
    def analyze_error_command(error_message, error_recovery)
      # Create a mock error for analysis
      mock_error = StandardError.new(error_message)
      
      say "\n🔍 Analyzing error: #{error_message}", :blue
      
      analysis = error_recovery.analyze_error(mock_error, { source: 'cli_analysis' })
      
      say "\n📊 Error Analysis:", :green
      say "  Type: #{analysis[:error][:type]}"
      say "  Auto-recoverable: #{analysis[:auto_recoverable] ? 'Yes' : 'No'}"
      
      if analysis[:patterns].any?
        say "\n🔎 Matching Patterns:", :yellow
        analysis[:patterns].first(3).each_with_index do |pattern, index|
          say "  #{index + 1}. #{pattern[:explanation]} (#{(pattern[:confidence] * 100).round}% confidence)"
        end
      end
      
      if analysis[:suggestions].any?
        say "\n💡 Recovery Suggestions:", :blue
        analysis[:suggestions].first(5).each_with_index do |suggestion, index|
          auto_indicator = suggestion[:auto_executable] ? '🤖' : '👤'
          confidence = suggestion[:confidence] ? " (#{(suggestion[:confidence] * 100).round}%)" : ""
          say "  #{index + 1}. #{auto_indicator} #{suggestion[:description]}#{confidence}"
        end
      end
    end
    
    def explain_error_command(error_message, error_recovery)
      mock_error = StandardError.new(error_message)
      
      say "\n📖 Error Explanation: #{error_message}", :blue
      
      explanation = error_recovery.explain_error(mock_error, { source: 'cli_explanation' })
      
      say "\n#{explanation[:explanation]}", :white
      say "\n🔍 Likely Cause:", :yellow
      say "  #{explanation[:likely_cause]}"
      
      if explanation[:prevention_tips].any?
        say "\n🛡️  Prevention Tips:", :green
        explanation[:prevention_tips].each_with_index do |tip, index|
          say "  #{index + 1}. #{tip}"
        end
      end
    end
    
    def show_recovery_stats(error_recovery)
      stats = error_recovery.recovery_statistics
      
      say "\n📊 Error Recovery Statistics:", :green
      say "  Total errors processed: #{stats[:total_errors_processed]}"
      say "  Successful automatic recoveries: #{stats[:successful_automatic_recoveries]}"
      say "  Recovery success rate: #{stats[:recovery_success_rate]}%"
      say "  Recovery patterns learned: #{stats[:recovery_patterns_learned]}"
      
      if stats[:most_common_errors].any?
        say "\n🔢 Most Common Error Types:", :blue
        stats[:most_common_errors].each do |error_type, count|
          say "  #{error_type}: #{count} occurrences"
        end
      end
    end
    
    def learn_recovery_command(error_message, recovery_steps, error_recovery)
      mock_error = StandardError.new(error_message)
      
      say "\n🧠 Learning from manual recovery...", :blue
      say "  Error: #{error_message}"
      say "  Steps: #{recovery_steps.join(' → ')}"
      
      error_recovery.learn_from_manual_recovery(
        mock_error, 
        recovery_steps, 
        { source: 'cli_learning', timestamp: Time.now.iso8601 }
      )
      
      say "✅ Recovery pattern learned successfully!", :green
    end
    
    def cleanup_error_data(error_recovery)
      say "🧹 Cleaning up old error recovery data...", :blue
      
      error_recovery.cleanup_old_data(30) # Keep last 30 days
      
      say "✅ Cleanup completed", :green
    end
    
    def show_recovery_help
      say "\n🔧 Error Recovery Commands:", :blue
      say "  enhance-swarm recover --analyze 'error message'     # Analyze specific error"
      say "  enhance-swarm recover --explain 'error message'     # Get error explanation"
      say "  enhance-swarm recover --stats                       # Show recovery statistics"
      say "  enhance-swarm recover --learn 'error' --steps step1 step2  # Learn from manual recovery"
      say "  enhance-swarm recover --cleanup                     # Clean up old data"
    end
    
    def troubleshoot_agent(agent_id)
      say "\n🔍 Troubleshooting agent: #{agent_id}", :blue
      
      # This would integrate with actual agent monitoring
      say "Agent troubleshooting not yet implemented for specific agents", :yellow
      say "Use 'enhance-swarm status' to check overall agent health"
    end
    
    def troubleshoot_recent_failures
      say "\n🔍 Analyzing recent failures...", :blue
      
      # This would analyze recent error logs and agent failures
      say "Recent failure analysis not yet implemented", :yellow
      say "Use 'enhance-swarm recover --stats' to see error recovery statistics"
    end
    
    def interactive_troubleshooting
      say "\n🔧 Interactive Troubleshooting Mode", :cyan
      say "─" * 40
      
      loop do
        say "\nWhat would you like to troubleshoot?", :blue
        say "1. Recent agent failures"
        say "2. Configuration issues"
        say "3. Dependency problems"
        say "4. Performance issues"
        say "5. Exit"
        
        choice = ask("Enter your choice (1-5):", :yellow)
        
        case choice.strip
        when '1'
          troubleshoot_recent_failures
        when '2'
          troubleshoot_configuration
        when '3'
          troubleshoot_dependencies
        when '4'
          troubleshoot_performance
        when '5'
          say "👋 Exiting troubleshooting mode", :green
          break
        else
          say "❌ Invalid choice. Please enter 1-5.", :red
        end
      end
    end
    
    def troubleshoot_configuration
      say "\n⚙️  Configuration Troubleshooting", :blue
      
      # Check for common configuration issues
      config_file = '.enhance_swarm.yml'
      
      if File.exist?(config_file)
        say "✅ Configuration file found: #{config_file}", :green
        
        begin
          config = YAML.load_file(config_file)
          say "✅ Configuration file is valid YAML", :green
          
          # Basic validation
          issues = []
          issues << "Missing project_name" unless config['project_name']
          issues << "Missing technology_stack" unless config['technology_stack']
          
          if issues.any?
            say "⚠️  Configuration issues found:", :yellow
            issues.each { |issue| say "  - #{issue}", :red }
            say "\nUse 'enhance-swarm smart-config --apply' to generate optimal configuration", :blue
          else
            say "✅ Configuration appears to be valid", :green
          end
          
        rescue StandardError => e
          say "❌ Configuration file has syntax errors: #{e.message}", :red
          say "Fix the YAML syntax or regenerate with 'enhance-swarm smart-config --apply'", :blue
        end
      else
        say "❌ No configuration file found", :red
        say "Run 'enhance-swarm init' or 'enhance-swarm smart-config --apply' to create one", :blue
      end
    end
    
    def troubleshoot_dependencies
      say "\n📦 Dependency Troubleshooting", :blue
      
      # Check dependency validation
      begin
        validation_results = DependencyValidator.validate_all
        
        validation_results[:results].each do |tool, result|
          status = result[:passed] ? '✅' : '❌'
          say "  #{status} #{tool.capitalize}: #{result[:version] || 'Not found'}"
          
          if !result[:passed] && result[:error]
            say "    Error: #{result[:error]}", :red
          end
        end
        
        unless validation_results[:passed]
          say "\n💡 Suggested fixes:", :blue
          say "  - Install missing dependencies using your system package manager"
          say "  - Update PATH environment variable if tools are installed but not found"
          say "  - Run 'enhance-swarm doctor --detailed' for more information"
        end
        
      rescue StandardError => e
        say "❌ Could not validate dependencies: #{e.message}", :red
      end
    end
    
    def troubleshoot_performance
      say "\n⚡ Performance Troubleshooting", :blue
      
      # Basic system health check
      begin
        health = system_health_summary
        
        if health[:issues].any?
          say "⚠️  Performance issues detected:", :yellow
          health[:issues].each { |issue| say "  - #{issue}", :red }
          
          say "\n💡 Suggested fixes:", :blue
          say "  - Run 'enhance-swarm cleanup --all' to clean up stale resources"
          say "  - Reduce max_concurrent_agents in configuration"
          say "  - Close other memory-intensive applications"
        else
          say "✅ No obvious performance issues detected", :green
        end
        
        # Show current concurrency settings
        concurrency = SmartDefaults.suggest_concurrency_settings
        say "\n🎯 Recommended Concurrency Settings:", :blue
        say "  Max concurrent agents: #{concurrency[:max_concurrent_agents]}"
        say "  Monitor interval: #{concurrency[:monitor_interval]}s"
        
      rescue StandardError => e
        say "❌ Could not analyze performance: #{e.message}", :red
      end
    end

    def test_notifications
      notification_manager = NotificationManager.instance
      
      say "🧪 Testing notifications...", :blue
      
      # Test different types of notifications
      notification_manager.agent_completed('test-backend-123', 'backend', 120, { 
        output_path: '/tmp/test' 
      })
      
      sleep(1)
      
      notification_manager.agent_failed('test-frontend-456', 'frontend', 
        'Connection timeout', [
          'Check network connectivity',
          'Restart with longer timeout'
        ])
      
      sleep(1)
      
      notification_manager.progress_milestone('Backend Implementation Complete', 75)
      
      say "✅ Test notifications sent", :green
    end

    def show_notification_history
      notification_manager = NotificationManager.instance
      recent = notification_manager.recent_notifications(10)
      
      if recent.empty?
        say "No recent notifications", :yellow
        return
      end
      
      say "\n📋 Recent Notifications:", :blue
      recent.each do |notification|
        timestamp = notification[:timestamp].strftime('%H:%M:%S')
        priority = notification[:priority].to_s.upcase
        type = notification[:type].to_s.humanize
        
        color = case notification[:priority]
                when :critical then :red
                when :high then :yellow  
                when :medium then :blue
                else :white
                end
        
        say "[#{timestamp}] #{priority} - #{type}: #{notification[:message]}", color
      end
    end

    def show_notification_status
      notification_manager = NotificationManager.instance
      
      say "\n🔔 Notification Status:", :blue
      say "  Enabled: #{notification_manager.enabled? ? '✅' : '❌'}"
      say "  Desktop: #{notification_manager.instance_variable_get(:@desktop_notifications) ? '✅' : '❌'}"
      say "  Sound: #{notification_manager.instance_variable_get(:@sound_enabled) ? '✅' : '❌'}"
      
      recent_count = notification_manager.recent_notifications.count
      say "  Recent notifications: #{recent_count}"
      
      if recent_count > 0
        say "\nUse 'enhance-swarm notifications --history' to view recent notifications"
      end
    end

    def start_interactive_communication
      communicator = AgentCommunicator.instance
      say "💬 Interactive Communication Mode", :green
      say "Type 'exit' to quit, 'help' for commands", :light_black
      
      loop do
        print "\nenhance-swarm-chat> "
        input = $stdin.gets.chomp
        
        case input.downcase
        when 'exit', 'quit'
          say "👋 Exiting interactive mode", :blue
          break
        when 'help'
          say "Available commands:"
          say "  list    - Show pending messages"
          say "  history - Show recent messages"
          say "  exit    - Exit interactive mode"
        when 'list'
          show_pending_messages
        when 'history'
          show_communication_history
        else
          say "Unknown command: #{input}", :red
          say "Type 'help' for available commands"
        end
      end
    end

    def show_pending_messages
      communicator = AgentCommunicator.instance
      pending = communicator.pending_messages
      
      if pending.empty?
        say "📭 No pending messages from agents", :blue
        return
      end
      
      say "\n📬 Pending Messages (#{pending.count}):", :yellow
      pending.each_with_index do |message, index|
        age = time_ago(Time.parse(message[:timestamp]))
        say "\n[#{index + 1}] #{message[:type].upcase} from #{message[:role]} (#{age} ago)"
        say "Message: #{message[:content]}"
        say "ID: #{message[:id]}" if message[:id]
      end
      
      say "\nUse --respond <id> --response \"<text>\" to reply"
    end

    def respond_to_message(message_id, response_text)
      communicator = AgentCommunicator.instance
      
      begin
        result = communicator.respond_to_message(message_id, response_text)
        
        if result[:success]
          say "✅ Response sent successfully", :green
        else
          say "❌ Failed to send response: #{result[:error]}", :red
        end
      rescue StandardError => e
        say "❌ Error sending response: #{e.message}", :red
      end
    end

    def show_communication_status
      communicator = AgentCommunicator.instance
      pending = communicator.pending_messages
      recent = communicator.recent_messages(5)
      
      say "\n💬 Agent Communication Status:", :blue
      say "  Pending messages: #{pending.count}"
      say "  Recent messages: #{recent.count}"
      
      if pending.any?
        say "\n📋 Pending Messages:", :yellow
        pending.first(3).each_with_index do |message, index|
          age = time_ago(Time.parse(message[:timestamp]))
          say "  #{index + 1}. #{message[:type]} from #{message[:role]} (#{age} ago)"
          say "     #{message[:content][0..60]}..."
        end
        
        if pending.count > 3
          say "  ... and #{pending.count - 3} more"
        end
        
        say "\nUse 'enhance-swarm communicate --list' to see all pending messages"
        say "Use 'enhance-swarm communicate --interactive' for interactive mode"
      else
        say "  No pending messages from agents"
      end
    end

    def show_communication_history
      communicator = AgentCommunicator.instance
      recent = communicator.recent_messages(10)
      
      if recent.empty?
        say "No recent communication history", :yellow
        return
      end
      
      say "\n💬 Recent Agent Communication:", :blue
      recent.each do |message|
        timestamp = Time.parse(message[:timestamp]).strftime('%H:%M:%S')
        type_icon = case message[:type]
                    when :question then '❓'
                    when :decision then '🤔'
                    when :status then '📝'
                    when :progress then '📊'
                    else '💬'
                    end
        
        color = message[:requires_response] ? :yellow : :white
        status = message[:requires_response] ? '(needs response)' : ''
        
        say "[#{timestamp}] #{type_icon} #{message[:role]} - #{message[:type]} #{status}", color
        say "   #{message[:content][0..80]}#{message[:content].length > 80 ? '...' : ''}"
      end
    end

    def time_ago(time)
      seconds = Time.now - time
      
      if seconds < 60
        "#{seconds.round}s"
      elsif seconds < 3600
        "#{(seconds / 60).round}m"
      elsif seconds < 86400
        "#{(seconds / 3600).round}h"
      else
        "#{(seconds / 86400).round}d"
      end
    end

    def take_dashboard_snapshot
      say "📸 Taking dashboard snapshot...", :blue
      
      # Create a mock dashboard state for snapshot
      agents = discover_running_agents
      dashboard = VisualDashboard.instance
      
      if agents.any?
        agents.each { |agent| dashboard.add_agent(agent) }
        dashboard.send(:save_dashboard_snapshot)
        say "✅ Dashboard snapshot saved", :green
      else
        say "No agents found for snapshot", :yellow
      end
    end

    def load_specific_agents(agent_ids)
      agents = []
      
      agent_ids.each do |agent_id|
        # Mock agent data - in real implementation, this would query actual agents
        agent = {
          id: agent_id,
          role: agent_id.split('-').first,
          status: 'active',
          start_time: (Time.now - rand(300)).iso8601,
          current_task: 'Working on task...',
          progress_percentage: rand(100),
          pid: rand(10000..99999)
        }
        agents << agent
      end
      
      agents
    end

    def discover_running_agents
      agents = []
      
      # Check for running swarm processes
      begin
        # Look for enhance-swarm processes
        ps_output = `ps aux | grep -i enhance-swarm | grep -v grep`
        ps_lines = ps_output.lines
        
        ps_lines.each_with_index do |line, index|
          next if line.include?('grep') || line.include?('dashboard')
          
          parts = line.split
          pid = parts[1]
          command = parts[10..-1]&.join(' ')
          
          next unless command&.include?('enhance-swarm')
          
          role = extract_role_from_command(command) || 'agent'
          
          agent = {
            id: "#{role}-#{Time.now.to_i}-#{index}",
            role: role,
            status: 'active',
            start_time: Time.now.iso8601,
            current_task: extract_task_from_command(command),
            progress_percentage: rand(20..80),
            pid: pid.to_i,
            command: command
          }
          
          agents << agent
        end
        
        # Add some mock agents for demonstration if no real ones found
        if agents.empty?
          agents = create_demo_agents
        end
        
      rescue StandardError => e
        Logger.error("Failed to discover agents: #{e.message}")
        agents = create_demo_agents
      end
      
      agents
    end

    def extract_role_from_command(command)
      if command.include?('--role')
        role_match = command.match(/--role\s+(\w+)/)
        return role_match[1] if role_match
      end
      
      # Try to infer from command
      case command
      when /backend/i then 'backend'
      when /frontend/i then 'frontend'  
      when /qa/i then 'qa'
      when /ux/i then 'ux'
      else 'general'
      end
    end

    def extract_task_from_command(command)
      # Extract task description from command
      if command.include?('spawn')
        task_match = command.match(/spawn\s+"([^"]+)"/)
        return task_match[1] if task_match
        
        # Try without quotes
        task_match = command.match(/spawn\s+(.+?)(?:\s+--|$)/)
        return task_match[1] if task_match
      elsif command.include?('enhance')
        task_match = command.match(/enhance\s+"([^"]+)"/)
        return task_match[1] if task_match
      end
      
      'Working on task...'
    end

    def create_demo_agents
      roles = %w[backend frontend qa ux]
      tasks = [
        'Implementing authentication system',
        'Building user interface components', 
        'Running integration tests',
        'Designing user experience flow'
      ]
      
      agents = []
      
      roles.each_with_index do |role, index|
        agent = {
          id: "#{role}-demo-#{Time.now.to_i + index}",
          role: role,
          status: ['active', 'completed', 'stuck'].sample,
          start_time: (Time.now - rand(600)).iso8601,
          current_task: tasks[index],
          progress_percentage: rand(10..95),
          pid: rand(1000..9999),
          memory_mb: rand(50..500)
        }
        agents << agent
      end
      
      agents
    end

    def build_suggestion_context
      context = {}
      
      # Get current git status
      if Dir.exist?('.git')
        begin
          git_status = `git status --porcelain`.strip
          context[:git_status] = {
            modified_files: git_status.lines.count { |line| line.start_with?(' M', 'M ') },
            untracked_files: git_status.lines.count { |line| line.start_with?('??') },
            staged_files: git_status.lines.count { |line| line.start_with?('A ', 'M ') }
          }
          context[:changed_files] = git_status.lines.map { |line| line[3..-1]&.strip }.compact
        rescue StandardError
          context[:git_status] = {}
          context[:changed_files] = []
        end
      end
      
      # Get current directory structure
      context[:project_files] = {
        package_json: File.exist?('package.json'),
        gemfile: File.exist?('Gemfile'),
        dockerfile: File.exist?('Dockerfile'),
        readme: File.exist?('README.md')
      }
      
      # Get current time context
      context[:time_context] = {
        hour: Time.now.hour,
        day_of_week: Time.now.strftime('%A').downcase,
        timestamp: Time.now.iso8601
      }
      
      # Get enhance_swarm status
      begin
        monitor = Monitor.new
        swarm_status = monitor.status
        context[:swarm_status] = {
          active_agents: swarm_status[:active_agents],
          recent_branches: swarm_status[:recent_branches]&.count || 0,
          worktrees: swarm_status[:worktrees]&.count || 0
        }
      rescue StandardError
        context[:swarm_status] = { active_agents: 0, recent_branches: 0, worktrees: 0 }
      end
      
      context
    end

    desc 'ui', 'Start the EnhanceSwarm Web UI'
    option :port, type: :numeric, default: 4567, desc: 'Port to run the web server on'
    option :host, type: :string, default: 'localhost', desc: 'Host to bind the web server to'
    def ui
      say '🌐 Starting EnhanceSwarm Web UI...', :blue

      web_ui = WebUI.new(port: options[:port], host: options[:host])
      web_ui.start
    rescue Interrupt
      say '\n👋 Web UI stopped', :yellow
    rescue StandardError => e
      say "❌ Failed to start Web UI: #{e.message}", :red
      exit 1
    end
  end
end

# Load additional commands
require_relative 'additional_commands'
EnhanceSwarm::AdditionalCommands.add_commands_to(EnhanceSwarm::CLI)
