# frozen_string_literal: true

require 'open3'
require 'json'
require_relative 'command_executor'
require_relative 'retry_handler'
require_relative 'logger'
require_relative 'cleanup_manager'

module EnhanceSwarm
  class Orchestrator
    def initialize
      @config = EnhanceSwarm.configuration
      @task_manager = TaskManager.new
      @monitor = Monitor.new
    end

    def enhance(task_id: nil, dry_run: false)
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

      # Step 2: Move task to active
      @task_manager.move_task(task[:id], 'active')
      puts '✅ Task moved to active'.colorize(:green)

      # Step 3: Break down and spawn agents
      agents = break_down_task(task)
      spawn_agents(agents)

      # Step 4: Brief monitoring (2 minutes max)
      puts "\n👀 Monitoring for #{@config.monitor_timeout} seconds...".colorize(:yellow)
      @monitor.watch(timeout: @config.monitor_timeout)

      # Step 5: Continue with other work
      puts "\n💡 Agents working in background. Check back later with:".colorize(:blue)
      puts '   enhance-swarm monitor'
      puts '   enhance-swarm status'

      # Return control to user for other work
    end

    def spawn_single(task:, role:, worktree:)
      operation_id = "spawn_#{role}_#{Time.now.to_i}"
      Logger.log_operation(operation_id, 'started', { role: role, worktree: worktree })
      
      agent_prompt = build_agent_prompt(task, role)
      args = ['start', '-p', agent_prompt]
      args << '--worktree' if worktree && @config.worktree_enabled

      puts "🚀 Spawning #{role} agent...".colorize(:yellow)

      begin
        pid = RetryHandler.with_retry(max_retries: 3) do
          CommandExecutor.execute_async('claude-swarm', *args)
        end
        
        puts '✅ Agent spawned successfully'.colorize(:green)
        Logger.log_operation(operation_id, 'success', { role: role, pid: pid })
        pid
      rescue RetryHandler::RetryError, CommandExecutor::CommandError => e
        puts "❌ Failed to spawn agent: #{e.message}".colorize(:red)
        Logger.log_operation(operation_id, 'failed', { role: role, error: e.message })
        
        # Attempt cleanup on failure
        CleanupManager.cleanup_failed_operation(operation_id, {
          role: role,
          worktree_path: worktree ? generate_worktree_path(role) : nil
        })
        
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

    def spawn_agents(agents)
      puts "\n🤖 Spawning #{agents.count} agents...".colorize(:yellow)
      spawned_agents = []
      failed_agents = []

      agents.each_with_index do |agent, index|
        # Add jitter to prevent resource contention
        sleep(2 + rand(0..2)) if index > 0
        
        result = spawn_single(
          task: agent[:task],
          role: agent[:role],
          worktree: true
        )
        
        if result
          spawned_agents << { **agent, pid: result }
        else
          failed_agents << agent
        end
      end

      if failed_agents.empty?
        puts '✅ All agents spawned'.colorize(:green)
      else
        puts "⚠️ #{spawned_agents.size}/#{agents.size} agents spawned successfully".colorize(:yellow)
        Logger.warn("Failed to spawn agents: #{failed_agents.map { |a| a[:role] }.join(', ')}")
      end
      
      { spawned: spawned_agents, failed: failed_agents }
    end

    def build_agent_prompt(task, role)
      # Sanitize inputs
      safe_task = sanitize_task_description(task)
      safe_role = sanitize_role(role)
      safe_test_command = sanitize_command(@config.test_command)

      timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
      task_words = safe_task.split.first(5).join(' ')

      base_prompt = <<~PROMPT
        AUTONOMOUS EXECUTION REQUIRED - #{safe_role.upcase} SPECIALIST

        #{safe_task}

        CRITICAL INSTRUCTIONS:
        1. You have FULL PERMISSION to read, write, edit files and run commands
        2. DO NOT wait for any permissions - proceed immediately
        3. Complete the task fully and thoroughly
        4. Test your implementation using: #{safe_test_command}
        5. When complete:
           - Run: git add -A
           - Run: git commit -m '#{safe_role}: #{task_words}...'
           - Run: git checkout -b 'swarm/#{safe_role}-#{timestamp}'
           - Run: git push origin HEAD
        6. Document what was implemented in your final message

        Remember: You are autonomous. Make all decisions needed to complete this task successfully.
      PROMPT

      # Add role-specific instructions
      case safe_role
      when 'ux'
        base_prompt += "\n\nFocus on UI/UX design, templates, and user experience."
      when 'backend'
        base_prompt += "\n\nFocus on models, services, APIs, and business logic."
      when 'frontend'
        base_prompt += "\n\nFocus on controllers, views, JavaScript, and integration."
      when 'qa'
        base_prompt += "\n\nFocus on comprehensive testing, edge cases, and quality assurance."
      end

      base_prompt
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

    def sanitize_task_description(task)
      # Remove potentially dangerous characters while preserving readability
      task.to_s.gsub(/[`$\\]/, '').strip
    end

    def sanitize_role(role)
      # Only allow known safe roles
      allowed_roles = %w[ux backend frontend qa general]
      role = role.to_s.downcase.strip
      allowed_roles.include?(role) ? role : 'general'
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
    
    def generate_worktree_path(role)
      timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
      File.join(EnhanceSwarm.root, 'worktrees', "swarm-#{role}-#{timestamp}")
    end

    def show_execution_plan(task)
      agents = break_down_task(task)

      puts "Would spawn #{agents.count} agents:".colorize(:blue)
      agents.each do |agent|
        puts "  - #{agent[:role].upcase}: #{agent[:task]}"
      end

      puts "\nCommands that would be executed:"
      puts "  1. #{sanitize_command(@config.task_move_command)} #{sanitize_argument(task[:id])} active"
      agents.each do |agent|
        cmd = 'claude-swarm start -p "..." --worktree'
        puts "  2. #{cmd} (#{sanitize_role(agent[:role])} agent)"
      end
    end
  end
end
