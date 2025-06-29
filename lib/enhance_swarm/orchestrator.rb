# frozen_string_literal: true

require 'open3'
require 'json'
require_relative 'command_executor'
require_relative 'retry_handler'
require_relative 'logger'
require_relative 'cleanup_manager'
require_relative 'session_manager'
require_relative 'agent_spawner'
require_relative 'process_monitor'

module EnhanceSwarm
  class Orchestrator
    def initialize
      @config = EnhanceSwarm.configuration
      @task_manager = TaskManager.new
      @session_manager = SessionManager.new
      @agent_spawner = AgentSpawner.new
      @process_monitor = ProcessMonitor.new
    end

    def enhance(task_id: nil, dry_run: false, follow: false)
      puts '🎯 ENHANCE Protocol Initiated'.colorize(:green)

      # Step 1: Identify task
      task = task_id ? @task_manager.find_task(task_id) : @task_manager.next_priority_task
      unless task
        puts 'No tasks available in backlog'.colorize(:yellow)
        return
      end

      puts "📋 Task: #{task[:id]} - #{task[:title]}".colorize(:blue)

      if dry_run
        puts "\n🔍 Dry run - would execute:".colorize(:yellow)
        show_execution_plan(task)
        return
      end

      # Step 2: Create or resume session
      unless @session_manager.session_exists?
        @session_manager.create_session(task[:description])
        puts '📁 Created new session'.colorize(:green)
      else
        puts '📁 Resuming existing session'.colorize(:blue)
      end

      # Step 3: Move task to active
      @task_manager.move_task(task[:id], 'active')
      puts '✅ Task moved to active'.colorize(:green)

      # Step 4: Break down and spawn agents with progress tracking
      agents = break_down_task(task)
      total_tokens = agents.sum { |agent| ProgressTracker.estimate_tokens_for_operation('spawn_agent') }
      
      if follow
        spawn_agents_with_streaming(agents)
      else
        ProgressTracker.track(total_steps: 100, estimated_tokens: total_tokens) do |tracker|
          # Spawn agents (0-50% progress)
          spawn_result = spawn_agents(agents, tracker)
          
          # Brief monitoring (50-100% progress)
          monitor_with_progress(tracker, @config.monitor_timeout)
        end
      end

      # Step 5: Continue with other work
      puts "\n💡 Agents working in background. Check back later with:".colorize(:blue)
      puts '   enhance-swarm status'
      puts '   enhance-swarm monitor'

      # Return control to user for other work
    end

    def monitor_with_progress(tracker, timeout_seconds)
      start_time = Time.now
      last_check = start_time
      check_interval = 5 # Check every 5 seconds
      
      while (Time.now - start_time) < timeout_seconds
        elapsed = Time.now - start_time
        progress = 50 + (elapsed / timeout_seconds * 50).to_i # 50-100% progress
        
        # Get current status using built-in monitor
        status = @process_monitor.status
        active_count = status[:active_agents]
        
        tracker.set_progress(progress,
                           message: "Monitoring #{active_count} active agents...",
                           operation: 'monitor',
                           details: { 
                             active_agents: active_count,
                             elapsed: "#{elapsed.round}s"
                           })
        
        sleep(check_interval)
      end
      
      tracker.set_progress(100, message: "Monitoring complete - agents running in background")
    end

    def spawn_agents_with_streaming(agents)
      puts "\n🤖 Spawning #{agents.count} agents with live output...".colorize(:yellow)
      
      # Use built-in agent spawner
      spawned_agents = @agent_spawner.spawn_multiple_agents(agents)
      
      return if spawned_agents.empty?
      
      puts "\n🔴 Live output streaming started for #{spawned_agents.count} agents. Press Ctrl+C to stop watching.\n".colorize(:green)
      
      # Start streaming output for all agents
      begin
        OutputStreamer.stream_agents(spawned_agents)
      rescue NameError
        # Fallback: Use built-in monitoring if OutputStreamer doesn't exist
        puts "🔍 Switching to built-in monitoring...".colorize(:blue)
        @process_monitor.watch(interval: 3)
      end
    end

    def spawn_single(task:, role:, worktree:)
      operation_id = "spawn_#{role}_#{Time.now.to_i}"
      Logger.log_operation(operation_id, 'started', { role: role, worktree: worktree })

      puts "🚀 Spawning #{role} agent...".colorize(:yellow)

      begin
        # Use built-in agent spawner
        result = @agent_spawner.spawn_agent(
          role: role,
          task: task,
          worktree: worktree && @config.worktree_enabled
        )
        
        if result
          puts '✅ Agent spawned successfully'.colorize(:green)
          Logger.log_operation(operation_id, 'success', { role: role, pid: result[:pid] })
          result[:pid]
        else
          puts "❌ Failed to spawn agent".colorize(:red)
          Logger.log_operation(operation_id, 'failed', { role: role, error: 'Spawn failed' })
          false
        end
      rescue StandardError => e
        puts "❌ Failed to spawn agent: #{e.message}".colorize(:red)
        Logger.log_operation(operation_id, 'failed', { role: role, error: e.message })
        false
      end
    end

    private

    def break_down_task(task)
      agents = []

      # Analyze task description to determine needed agents
      desc = task[:description].downcase

      # Always include QA for any feature work
      needs_qa = desc.match?(/feature|implement|add|create|build/)

      # Check what types of work are needed
      needs_ui = desc.match?(/ui|interface|design|template|email|view|component/)
      needs_backend = desc.match?(/model|database|api|service|migration|business logic/)
      needs_frontend = desc.match?(/controller|javascript|turbo|stimulus|form/)

      # Build agent list based on analysis
      agents << { role: 'ux', task: extract_ux_work(task) } if needs_ui
      agents << { role: 'backend', task: extract_backend_work(task) } if needs_backend
      agents << { role: 'frontend', task: extract_frontend_work(task) } if needs_frontend
      agents << { role: 'qa', task: extract_qa_work(task) } if needs_qa

      # If no specific needs detected, spawn a general agent
      agents << { role: 'general', task: task[:description] } if agents.empty?

      agents
    end

    def spawn_agents(agents, tracker = nil)
      if tracker
        tracker.update_status("Spawning #{agents.count} agents...", operation: 'spawn_agents')
      else
        puts "\n🤖 Spawning #{agents.count} agents...".colorize(:yellow)
      end
      
      spawned_agents = []
      failed_agents = []
      total_estimated_tokens = agents.sum { |agent| ProgressTracker.estimate_tokens_for_operation('spawn_agent') }

      agents.each_with_index do |agent, index|
        # Update progress if tracker available
        if tracker
          progress = (index.to_f / agents.count * 50).to_i # First 50% for spawning
          tracker.set_progress(progress, 
                              message: "Spawning #{agent[:role]} agent...",
                              agent: agent[:role],
                              operation: 'spawn')
        end

        # Add jitter to prevent resource contention
        sleep(2 + rand(0..2)) if index > 0
        
        # Use built-in agent spawner
        result = @agent_spawner.spawn_agent(
          role: agent[:role],
          task: agent[:task],
          worktree: true
        )
        
        if result
          spawned_agents << { **agent, pid: result[:pid] }
          tracker&.add_tokens(ProgressTracker.estimate_tokens_for_operation('spawn_agent'))
        else
          failed_agents << agent
        end
      end

      if tracker
        tracker.set_progress(50, 
                           message: "All agents spawned, monitoring...",
                           operation: 'monitor')
      elsif failed_agents.empty?
        puts '✅ All agents spawned'.colorize(:green)
      else
        puts "⚠️ #{spawned_agents.size}/#{agents.size} agents spawned successfully".colorize(:yellow)
        Logger.warn("Failed to spawn agents: #{failed_agents.map { |a| a[:role] }.join(', ')}")
      end
      
      { spawned: spawned_agents, failed: failed_agents }
    end


    def extract_ux_work(task)
      "Design and implement UI/UX for: #{task[:description]}"
    end

    def extract_backend_work(task)
      "Implement backend logic for: #{task[:description]}"
    end

    def extract_frontend_work(task)
      "Implement frontend integration for: #{task[:description]}"
    end

    def extract_qa_work(task)
      "Write comprehensive tests for: #{task[:description]}"
    end

    def sanitize_command(command)
      # Basic command sanitization - remove shell metacharacters
      command.to_s.gsub(/[;&|`$\\]/, '').strip
    end

    def sanitize_argument(arg)
      # Escape shell metacharacters in arguments
      require 'shellwords'
      Shellwords.escape(arg.to_s)
    end
    
    def sanitize_role(role)
      # Only allow known safe roles
      allowed_roles = %w[ux backend frontend qa general]
      role = role.to_s.downcase.strip
      allowed_roles.include?(role) ? role : 'general'
    end

    def show_execution_plan(task)
      agents = break_down_task(task)

      puts "Would spawn #{agents.count} agents:".colorize(:blue)
      agents.each do |agent|
        puts "  - #{agent[:role].upcase}: #{agent[:task]}"
      end

      puts "\nActions that would be executed:"
      puts "  1. Create or resume agent session"
      puts "  2. #{sanitize_command(@config.task_move_command)} #{sanitize_argument(task[:id])} active"
      agents.each_with_index do |agent, index|
        puts "  #{index + 3}. Spawn #{sanitize_role(agent[:role])} agent with git worktree"
      end
      puts "  #{agents.count + 3}. Monitor agent progress"
    end
  end
end
