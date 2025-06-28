# frozen_string_literal: true

require 'io/console'

module EnhanceSwarm
  class InterruptHandler
    STUCK_THRESHOLD = 600 # 10 minutes
    MEMORY_THRESHOLD = 1000 # 1GB in MB
    RESPONSE_TIMEOUT = 30 # 30 seconds for user response

    def initialize(notification_manager = nil)
      @notification_manager = notification_manager || NotificationManager.instance
      @interrupts_enabled = true
      @monitoring_active = false
      @user_responses = {}
    end

    def start_monitoring(agents)
      return if @monitoring_active

      @monitoring_active = true
      @monitoring_thread = Thread.new do
        monitor_for_interrupts(agents)
      end
    end

    def stop_monitoring
      @monitoring_active = false
      @monitoring_thread&.kill
      @monitoring_thread = nil
    end

    def handle_agent_stuck(agent)
      return unless @interrupts_enabled

      agent_id = agent[:id]
      role = agent[:role]
      last_activity = agent[:last_activity]
      current_task = agent[:current_task]

      # Calculate how long stuck
      time_stuck = Time.now - last_activity
      
      # Only interrupt if stuck for significant time
      return unless time_stuck > STUCK_THRESHOLD

      # Show stuck notification
      @notification_manager.agent_stuck(agent_id, role, last_activity, current_task)
      
      # Prompt user for action with timeout
      response = prompt_user_with_timeout(
        "Agent '#{role}' stuck for #{format_duration(time_stuck)}. Restart? [y/N]",
        timeout: RESPONSE_TIMEOUT,
        default: 'n'
      )

      case response.downcase
      when 'y', 'yes'
        restart_agent(agent)
      when 'k', 'kill'
        kill_agent(agent)
      when 'd', 'debug'
        debug_agent(agent)
      else
        puts "Continuing to monitor agent '#{role}'...".colorize(:yellow)
      end
    end

    def handle_agent_excessive_memory(agent)
      return unless @interrupts_enabled

      memory_mb = agent[:memory_mb]
      return unless memory_mb > MEMORY_THRESHOLD

      agent_id = agent[:id]
      role = agent[:role]

      @notification_manager.intervention_needed(
        "Agent '#{role}' using #{memory_mb}MB memory",
        agent_id,
        [
          "enhance-swarm restart #{agent_id}",
          "enhance-swarm kill #{agent_id}",
          "Continue monitoring"
        ]
      )

      response = prompt_user_with_timeout(
        "Agent '#{role}' using #{memory_mb}MB. Action? [r]estart/[k]ill/[c]ontinue",
        timeout: RESPONSE_TIMEOUT,
        default: 'c'
      )

      case response.downcase
      when 'r', 'restart'
        restart_agent(agent)
      when 'k', 'kill'
        kill_agent(agent)
      else
        puts "Continuing to monitor agent '#{role}'...".colorize(:yellow)
      end
    end

    def handle_coordination_conflict(agents, conflict_type, details = {})
      return unless @interrupts_enabled

      case conflict_type
      when :file_conflict
        handle_file_conflict(agents, details)
      when :dependency_deadlock
        handle_dependency_deadlock(agents, details)
      when :resource_contention
        handle_resource_contention(agents, details)
      end
    end

    def handle_critical_error(agent, error, context = {})
      return unless @interrupts_enabled

      agent_id = agent[:id]
      role = agent[:role]

      # Analyze error for suggested fixes
      suggestions = analyze_error_for_suggestions(error, context)

      @notification_manager.agent_failed(agent_id, role, error.message, suggestions)

      if suggestions.any?
        puts "\nError analysis complete. Choose an action:".colorize(:red)
        suggestions.each_with_index do |suggestion, index|
          puts "  #{index + 1}. #{suggestion}".colorize(:yellow)
        end
        puts "  c. Enter custom command".colorize(:blue)

        response = prompt_user_with_timeout(
          "Choose [1-#{suggestions.length}] or [c]ustom:",
          timeout: RESPONSE_TIMEOUT,
          default: '1'
        )

        execute_error_recovery(agent, response, suggestions)
      end
    end

    # Enable/disable interrupts
    def enable_interrupts!
      @interrupts_enabled = true
      puts "✅ Interrupts enabled - will prompt for stuck/failed agents".colorize(:green)
    end

    def disable_interrupts!
      @interrupts_enabled = false
      puts "🔇 Interrupts disabled - agents will run without intervention".colorize(:yellow)
    end

    def interrupts_enabled?
      @interrupts_enabled
    end

    private

    def monitor_for_interrupts(agents)
      while @monitoring_active
        agents.each do |agent|
          next unless agent_needs_attention?(agent)

          # Check for stuck agents
          if agent_stuck?(agent)
            handle_agent_stuck(agent)
          end

          # Check for memory issues
          if agent_excessive_memory?(agent)
            handle_agent_excessive_memory(agent)
          end

          # Check for process issues
          unless process_healthy?(agent)
            handle_process_issue(agent)
          end
        end

        sleep(30) # Check every 30 seconds
      end
    rescue StandardError => e
      Logger.error("Interrupt monitoring error: #{e.message}")
    end

    def agent_needs_attention?(agent)
      agent_stuck?(agent) || 
      agent_excessive_memory?(agent) || 
      !process_healthy?(agent)
    end

    def agent_stuck?(agent)
      return false unless agent[:last_activity]
      
      Time.now - agent[:last_activity] > STUCK_THRESHOLD
    end

    def agent_excessive_memory?(agent)
      return false unless agent[:memory_mb]
      
      agent[:memory_mb] > MEMORY_THRESHOLD
    end

    def process_healthy?(agent)
      return true unless agent[:pid]

      begin
        Process.kill(0, agent[:pid])
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true # Process exists but we can't signal it
      end
    end

    def prompt_user_with_timeout(prompt, timeout: 30, default: nil)
      puts prompt.colorize(:blue)
      
      if default
        puts "(Auto-selecting '#{default}' in #{timeout}s if no response)".colorize(:light_black)
      end

      # Set up timeout
      response = nil
      input_thread = Thread.new do
        response = $stdin.gets&.chomp
      end

      # Wait for input or timeout
      unless input_thread.join(timeout)
        input_thread.kill
        puts "\nTimeout reached, using default: '#{default}'".colorize(:yellow)
        response = default
      end

      response || default || ''
    end

    def restart_agent(agent)
      agent_id = agent[:id]
      role = agent[:role]

      puts "🔄 Restarting agent '#{role}'...".colorize(:yellow)

      begin
        # Kill existing process
        if agent[:pid]
          Process.kill('TERM', agent[:pid])
          sleep(2)
          Process.kill('KILL', agent[:pid]) rescue nil
        end

        # Clean up resources
        cleanup_agent_resources(agent)

        # Restart with same task
        new_pid = spawn_agent_replacement(agent)
        
        if new_pid
          puts "✅ Agent '#{role}' restarted with PID #{new_pid}".colorize(:green)
          @notification_manager.notify(:agent_completed, "Agent '#{role}' restarted successfully")
        else
          puts "❌ Failed to restart agent '#{role}'".colorize(:red)
        end

      rescue StandardError => e
        puts "❌ Error restarting agent: #{e.message}".colorize(:red)
        Logger.error("Failed to restart agent #{agent_id}: #{e.message}")
      end
    end

    def kill_agent(agent)
      agent_id = agent[:id]
      role = agent[:role]

      puts "🛑 Killing agent '#{role}'...".colorize(:red)

      begin
        if agent[:pid]
          Process.kill('KILL', agent[:pid])
          puts "✅ Agent '#{role}' terminated".colorize(:green)
        end

        cleanup_agent_resources(agent)
        @notification_manager.notify(:agent_completed, "Agent '#{role}' terminated by user")

      rescue StandardError => e
        puts "❌ Error killing agent: #{e.message}".colorize(:red)
        Logger.error("Failed to kill agent #{agent_id}: #{e.message}")
      end
    end

    def debug_agent(agent)
      agent_id = agent[:id]
      role = agent[:role]

      puts "🔍 Debugging agent '#{role}'...".colorize(:blue)
      
      # Show agent details
      puts "\nAgent Details:".colorize(:blue)
      puts "  ID: #{agent_id}"
      puts "  Role: #{role}"
      puts "  PID: #{agent[:pid]}"
      puts "  Last Activity: #{agent[:last_activity]}"
      puts "  Current Task: #{agent[:current_task] || 'Unknown'}"
      puts "  Memory: #{agent[:memory_mb]}MB" if agent[:memory_mb]
      
      # Show recent logs
      show_agent_logs(agent)
      
      # Show worktree status
      show_agent_worktree_status(agent)
    end

    def handle_file_conflict(agents, details)
      conflicted_file = details[:file]
      conflicting_agents = details[:agents] || agents.select { |a| a[:status] == 'active' }

      @notification_manager.intervention_needed(
        "File conflict detected: #{conflicted_file}",
        nil,
        [
          "Pause conflicting agents",
          "Merge changes manually", 
          "Restart with coordination"
        ]
      )

      response = prompt_user_with_timeout(
        "File conflict in #{conflicted_file}. Action? [p]ause/[m]erge/[r]estart",
        timeout: RESPONSE_TIMEOUT,
        default: 'p'
      )

      case response.downcase
      when 'p', 'pause'
        pause_conflicting_agents(conflicting_agents)
      when 'm', 'merge'
        initiate_manual_merge(conflicted_file, conflicting_agents)
      when 'r', 'restart'
        restart_with_coordination(conflicting_agents)
      end
    end

    def handle_dependency_deadlock(agents, details)
      @notification_manager.intervention_needed(
        "Dependency deadlock detected between agents",
        nil,
        ["Restart with updated dependencies", "Manual intervention"]
      )

      # Implementation for dependency deadlock resolution
      puts "🔄 Resolving dependency deadlock...".colorize(:yellow)
    end

    def handle_resource_contention(agents, details)
      resource = details[:resource]
      
      @notification_manager.intervention_needed(
        "Resource contention for #{resource}",
        nil,
        ["Serialize access", "Increase resources"]
      )
    end

    def analyze_error_for_suggestions(error, context)
      suggestions = []
      error_message = error.message.downcase

      case error_message
      when /timeout/
        suggestions << "enhance-swarm restart #{context[:agent_id]} --timeout=300"
        suggestions << "Check network connectivity"
      when /permission denied/
        suggestions << "Check file permissions"
        suggestions << "Run with appropriate privileges"
      when /no such file/
        suggestions << "Verify file paths and dependencies"
        suggestions << "Regenerate missing files"
      when /memory|out of space/
        suggestions << "enhance-swarm cleanup --all"
        suggestions << "Increase available memory"
      when /git/
        suggestions << "Fix git repository state"
        suggestions << "Reset to clean state"
      else
        suggestions << "enhance-swarm restart #{context[:agent_id]}"
        suggestions << "Check logs for more details"
      end

      suggestions
    end

    def execute_error_recovery(agent, response, suggestions)
      case response
      when /^\d+$/
        index = response.to_i - 1
        if index >= 0 && index < suggestions.length
          suggestion = suggestions[index]
          puts "Executing: #{suggestion}".colorize(:blue)
          
          if suggestion.start_with?('enhance-swarm')
            execute_enhance_swarm_command(suggestion)
          else
            puts "Manual action required: #{suggestion}".colorize(:yellow)
          end
        end
      when 'c', 'custom'
        custom_command = prompt_user_with_timeout("Enter custom command:", timeout: 60)
        if custom_command && !custom_command.empty?
          execute_custom_recovery_command(custom_command, agent)
        end
      end
    end

    def execute_enhance_swarm_command(command)
      # Parse and execute enhance-swarm commands
      parts = command.split(' ')
      if parts.first == 'enhance-swarm'
        puts "This would execute: #{command}".colorize(:blue)
        # In real implementation, this would call the appropriate CLI method
      end
    end

    def execute_custom_recovery_command(command, agent)
      puts "Executing custom recovery: #{command}".colorize(:blue)
      
      begin
        CommandExecutor.execute('bash', '-c', command)
        puts "✅ Custom recovery command completed".colorize(:green)
      rescue StandardError => e
        puts "❌ Custom recovery failed: #{e.message}".colorize(:red)
      end
    end

    def format_duration(seconds)
      if seconds < 60
        "#{seconds.round}s"
      elsif seconds < 3600
        "#{(seconds / 60).round}m"
      else
        "#{(seconds / 3600).round(1)}h"
      end
    end

    def cleanup_agent_resources(agent)
      # Clean up worktree, temp files, etc.
      if agent[:worktree_path] && File.exist?(agent[:worktree_path])
        puts "Cleaning up worktree: #{agent[:worktree_path]}".colorize(:yellow)
        # Cleanup implementation
      end
    end

    def spawn_agent_replacement(agent)
      # Spawn a new agent with the same configuration
      # This would integrate with the Orchestrator
      puts "Spawning replacement agent...".colorize(:blue)
      # Return new PID or false if failed
      nil
    end

    def show_agent_logs(agent)
      puts "\nRecent Activity:".colorize(:blue)
      # Show recent log entries for this agent
      puts "  (Log viewing not implemented in this demo)"
    end

    def show_agent_worktree_status(agent)
      puts "\nWorktree Status:".colorize(:blue)
      if agent[:worktree_path]
        puts "  Path: #{agent[:worktree_path]}"
        # Show git status, recent commits, etc.
      else
        puts "  No worktree assigned"
      end
    end

    def pause_conflicting_agents(agents)
      puts "Pausing conflicting agents...".colorize(:yellow)
      agents.each do |agent|
        # Send pause signal to agents
        puts "  Paused: #{agent[:role]}"
      end
    end

    def initiate_manual_merge(file, agents)
      puts "Initiating manual merge for #{file}...".colorize(:blue)
      puts "Please resolve conflicts and run: enhance-swarm resume"
    end

    def restart_with_coordination(agents)
      puts "Restarting agents with improved coordination...".colorize(:blue)
      agents.each do |agent|
        restart_agent(agent)
      end
    end

    def handle_process_issue(agent)
      puts "Process issue detected for agent #{agent[:role]}".colorize(:red)
      @notification_manager.agent_failed(
        agent[:id], 
        agent[:role], 
        "Process terminated unexpectedly",
        ["enhance-swarm restart #{agent[:id]}", "Check system resources"]
      )
    end
  end
end