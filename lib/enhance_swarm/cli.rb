# frozen_string_literal: true

require 'thor'
require 'colorize'

module EnhanceSwarm
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

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

      if options[:control_agent] && !options[:dry_run]
        enhance_with_control_agent
      else
        orchestrator = Orchestrator.new
        orchestrator.enhance(
          task_id: options[:task],
          dry_run: options[:dry_run],
          follow: options[:follow]
        )
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
        orchestrator.spawn_single(
          task: task_desc,
          role: role,
          worktree: options[:worktree]
        )
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
      monitor = Monitor.new
      status = monitor.status
      
      if options[:json]
        puts JSON.pretty_generate({
          timestamp: Time.now.iso8601,
          status: status,
          health: system_health_summary
        })
        return
      end

      say "\n📊 Swarm Status:", :green
      say "  Active agents: #{status[:active_agents]}", status[:active_agents] > 0 ? :yellow : :white
      say "  Completed tasks: #{status[:completed_tasks]}", :green
      say "  Worktrees: #{status[:worktrees].count}", :blue

      if status[:recent_branches].any?
        say "\n📌 Recent branches:", :yellow
        status[:recent_branches].each do |branch|
          say "  - #{branch}"
        end
      end
      
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

      validation_results = DependencyValidator.validate_all
      
      validation_results[:results].each do |tool, result|
        status = result[:passed] ? '✓'.green : '✗'.red
        
        if detailed && result[:version]
          say "  #{status} #{tool.capitalize}: #{result[:version]} (required: #{result[:required]})"
        else
          say "  #{status} #{tool.capitalize}"
        end
        
        if !result[:passed] && result[:error]
          say "    Error: #{result[:error]}", :red
        end
      end

      if validation_results[:passed]
        say "\n✅ All critical dependencies met!", :green
      else
        say "\n⚠️  Some dependencies failed. Please address the issues above.", :yellow
        exit(1) if ENV['ENHANCE_SWARM_STRICT'] == 'true'
      end
      
      # Run functional tests if requested
      if detailed
        say "\n🔧 Running functionality tests...", :yellow
        functional_results = DependencyValidator.validate_functionality
        
        functional_results.each do |test, result|
          status = result[:passed] ? '✓'.green : '✗'.red
          say "  #{status} #{test.to_s.humanize}"
          
          if !result[:passed] && result[:error]
            say "    Error: #{result[:error]}", :red
          end
        end
      end
    end
    
    def run_detailed_doctor_json
      validation_results = DependencyValidator.validate_all
      functional_results = DependencyValidator.validate_functionality
      
      output = {
        timestamp: Time.now.iso8601,
        version: EnhanceSwarm::VERSION,
        dependencies: validation_results,
        functionality: functional_results,
        environment: {
          ruby_version: RUBY_VERSION,
          platform: RUBY_PLATFORM,
          pwd: Dir.pwd
        }
      }
      
      puts JSON.pretty_generate(output)
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
        results = CleanupManager.cleanup_all_swarm_resources
        
        say "\n✅ Cleanup completed:", :green
        say "  Worktrees: #{results[:worktrees][:count]} processed"
        say "  Branches: #{results[:branches][:count]} processed"
        say "  Temp files: #{results[:temp_files][:files_removed]} removed"
      else
        say 'Please specify --all or --dry-run', :red
        say 'Use --help for more information'
      end
    end

    desc 'review', 'Review agent work in progress and completed tasks'
    option :json, type: :boolean, desc: 'Output results in JSON format'
    def review
      say '🔍 Reviewing agent work...', :yellow
      
      results = AgentReviewer.review_all_work
      
      if options[:json]
        puts JSON.pretty_generate(results)
      else
        AgentReviewer.print_review_report(results)
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

    private

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
  end
end
