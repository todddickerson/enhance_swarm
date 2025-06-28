# frozen_string_literal: true

require 'open3'
require 'json'

module EnhanceSwarm
  class Orchestrator
    def initialize
      @config = EnhanceSwarm.configuration
      @task_manager = TaskManager.new
      @monitor = Monitor.new
    end
    
    def enhance(task_id: nil, dry_run: false)
      puts "🎯 ENHANCE Protocol Initiated".colorize(:green)
      
      # Step 1: Identify task
      task = task_id ? @task_manager.find_task(task_id) : @task_manager.next_priority_task
      unless task
        puts "No tasks available in backlog".colorize(:yellow)
        return
      end
      
      puts "📋 Task: #{task[:id]} - #{task[:title]}".colorize(:blue)
      
      if dry_run
        puts "\n🔍 Dry run - would execute:".colorize(:yellow)
        show_execution_plan(task)
        return
      end
      
      # Step 2: Move task to active
      @task_manager.move_task(task[:id], "active")
      puts "✅ Task moved to active".colorize(:green)
      
      # Step 3: Break down and spawn agents
      agents = break_down_task(task)
      spawn_agents(agents)
      
      # Step 4: Brief monitoring (2 minutes max)
      puts "\n👀 Monitoring for #{@config.monitor_timeout} seconds...".colorize(:yellow)
      @monitor.watch(timeout: @config.monitor_timeout)
      
      # Step 5: Continue with other work
      puts "\n💡 Agents working in background. Check back later with:".colorize(:blue)
      puts "   enhance-swarm monitor"
      puts "   enhance-swarm status"
      
      # Return control to user for other work
    end
    
    def spawn_single(task:, role:, worktree:)
      agent_prompt = build_agent_prompt(task, role)
      
      cmd = ["claude-swarm", "start", "-p", agent_prompt]
      cmd << "--worktree" if worktree && @config.worktree_enabled
      
      puts "🚀 Spawning #{role} agent...".colorize(:yellow)
      
      success = system(*cmd, "&")
      
      if success
        puts "✅ Agent spawned successfully".colorize(:green)
      else
        puts "❌ Failed to spawn agent".colorize(:red)
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
      agents << { role: "ux", task: extract_ux_work(task) } if needs_ui
      agents << { role: "backend", task: extract_backend_work(task) } if needs_backend
      agents << { role: "frontend", task: extract_frontend_work(task) } if needs_frontend
      agents << { role: "qa", task: extract_qa_work(task) } if needs_qa
      
      # If no specific needs detected, spawn a general agent
      agents << { role: "general", task: task[:description] } if agents.empty?
      
      agents
    end
    
    def spawn_agents(agents)
      puts "\n🤖 Spawning #{agents.count} agents...".colorize(:yellow)
      
      agents.each do |agent|
        spawn_single(
          task: agent[:task],
          role: agent[:role],
          worktree: true
        )
        sleep 2  # Brief pause between spawns
      end
      
      puts "✅ All agents spawned".colorize(:green)
    end
    
    def build_agent_prompt(task, role)
      base_prompt = <<~PROMPT
        AUTONOMOUS EXECUTION REQUIRED - #{role.upcase} SPECIALIST
        
        #{task}
        
        CRITICAL INSTRUCTIONS:
        1. You have FULL PERMISSION to read, write, edit files and run commands
        2. DO NOT wait for any permissions - proceed immediately
        3. Complete the task fully and thoroughly
        4. Test your implementation using: #{@config.test_command}
        5. When complete:
           - Run: git add -A
           - Run: git commit -m '#{role}: #{task.split.first(5).join(' ')}...'
           - Run: git checkout -b 'swarm/#{role}-#{Time.now.strftime('%Y%m%d-%H%M%S')}'
           - Run: git push origin HEAD
        6. Document what was implemented in your final message
        
        Remember: You are autonomous. Make all decisions needed to complete this task successfully.
      PROMPT
      
      # Add role-specific instructions
      case role
      when "ux"
        base_prompt += "\n\nFocus on UI/UX design, templates, and user experience."
      when "backend"
        base_prompt += "\n\nFocus on models, services, APIs, and business logic."
      when "frontend"
        base_prompt += "\n\nFocus on controllers, views, JavaScript, and integration."
      when "qa"
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
    
    def show_execution_plan(task)
      agents = break_down_task(task)
      
      puts "Would spawn #{agents.count} agents:".colorize(:blue)
      agents.each do |agent|
        puts "  - #{agent[:role].upcase}: #{agent[:task]}"
      end
      
      puts "\nCommands that would be executed:"
      puts "  1. #{@config.task_move_command} #{task[:id]} active"
      agents.each do |agent|
        cmd = "claude-swarm start -p \"...\" --worktree &"
        puts "  2. #{cmd} (#{agent[:role]} agent)"
      end
    end
  end
end