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
    def enhance
      say '🎯 ENHANCE Protocol Activated!', :green

      # Setup notifications and interrupts
      setup_notifications_and_interrupts if options[:notifications]

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
    option :role, type: :string, default: 'general', desc: 'Agent role (ux/backend/frontend/qa)'
    option :worktree, type: :boolean, default: true, desc: 'Use git worktree'
    option :follow, type: :boolean, default: false, desc: 'Stream live output from the agent'
    def spawn(task_desc)
      if options[:follow]
        say "🤖 Spawning agent with live output for: #{task_desc}", :yellow
        spawn_with_streaming(task_desc)
      else
        say "🤖 Spawning agent for: #{task_desc}", :yellow
        
        orchestrator = Orchestrator.new
        orchestrator.spawn_single(
          task: task_desc,
          role: options[:role],
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

    def spawn_with_streaming(task_desc)
      orchestrator = Orchestrator.new
      
      # Spawn the agent
      pid = orchestrator.spawn_single(
        task: task_desc,
        role: options[:role],
        worktree: options[:worktree]
      )
      
      return unless pid
      
      # Start streaming output
      agent_id = "#{options[:role]}-#{Time.now.to_i}"
      agents = [{
        id: agent_id,
        pid: pid,
        role: options[:role]
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
  end
end
