# frozen_string_literal: true

require 'open3'
require 'tempfile'
require_relative 'command_executor'
require_relative 'session_manager'
require_relative 'logger'

module EnhanceSwarm
  class AgentSpawner
    def initialize
      @config = EnhanceSwarm.configuration
      @session_manager = SessionManager.new
    end

    def spawn_agent(role:, task:, worktree: true)
      Logger.info("Spawning #{role} agent for task: #{task}")
      
      begin
        # Create worktree if requested
        worktree_path = nil
        if worktree
          worktree_path = create_agent_worktree(role)
          return false unless worktree_path
        end

        # Generate agent prompt
        prompt = build_agent_prompt(task, role, worktree_path)
        
        # Spawn the agent process
        pid = spawn_claude_process(prompt, role, worktree_path)
        return false unless pid

        # Register agent in session
        success = @session_manager.add_agent(role, pid, worktree_path, task)
        
        if success
          Logger.info("Successfully spawned #{role} agent (PID: #{pid})")
          { pid: pid, worktree_path: worktree_path, role: role }
        else
          Logger.error("Failed to register agent in session")
          cleanup_failed_spawn(pid, worktree_path)
          false
        end

      rescue StandardError => e
        Logger.error("Failed to spawn #{role} agent: #{e.message}")
        cleanup_failed_spawn(nil, worktree_path)
        false
      end
    end

    def spawn_multiple_agents(agents)
      results = []
      
      agents.each_with_index do |agent_config, index|
        # Add jitter to prevent resource contention
        sleep(2 + rand(0..2)) if index > 0
        
        result = spawn_agent(
          role: agent_config[:role],
          task: agent_config[:task],
          worktree: agent_config.fetch(:worktree, true)
        )
        
        results << result if result
      end
      
      results
    end

    def get_running_agents
      @session_manager.check_agent_processes
    end

    def stop_agent(pid)
      begin
        Process.kill('TERM', pid.to_i)
        @session_manager.update_agent_status(pid, 'stopped', Time.now.iso8601)
        Logger.info("Stopped agent with PID: #{pid}")
        true
      rescue Errno::ESRCH
        # Process already stopped
        @session_manager.update_agent_status(pid, 'stopped', Time.now.iso8601)
        true
      rescue StandardError => e
        Logger.error("Failed to stop agent (PID: #{pid}): #{e.message}")
        false
      end
    end

    def stop_all_agents
      active_agents = @session_manager.get_active_agents
      stopped_count = 0
      
      active_agents.each do |agent|
        if stop_agent(agent[:pid])
          stopped_count += 1
        end
      end
      
      Logger.info("Stopped #{stopped_count}/#{active_agents.length} agents")
      stopped_count
    end

    def claude_cli_available?
      @claude_cli_available ||= begin
        result = `claude --version 2>/dev/null`
        $?.success? && result.strip.length > 0
      rescue StandardError
        false
      end
    end

    private

    def create_agent_worktree(role)
      timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
      worktree_name = "#{role}-#{timestamp}"
      worktree_path = File.join('.enhance_swarm', 'worktrees', worktree_name)
      
      begin
        # Ensure worktrees directory exists
        worktrees_dir = File.dirname(worktree_path)
        FileUtils.mkdir_p(worktrees_dir) unless Dir.exist?(worktrees_dir)
        
        # Create git worktree
        CommandExecutor.execute('git', 'worktree', 'add', worktree_path)
        
        Logger.info("Created worktree for #{role} agent: #{worktree_path}")
        File.expand_path(worktree_path)
        
      rescue CommandExecutor::CommandError => e
        Logger.error("Failed to create worktree for #{role}: #{e.message}")
        nil
      end
    end

    def spawn_claude_process(prompt, role, worktree_path)
      begin
        # Check if Claude CLI is available
        unless claude_cli_available?
          Logger.error("Claude CLI not available - falling back to simulation mode")
          return spawn_simulated_process(role, worktree_path)
        end

        # Prepare the enhanced prompt for the agent
        enhanced_prompt = build_enhanced_agent_prompt(prompt, role, worktree_path)
        
        # Create working directory for the agent
        agent_dir = worktree_path || Dir.pwd
        
        # Prepare environment
        env = build_agent_environment(role, agent_dir)
        
        # Create a temporary script to handle the Claude interaction
        script_file = create_agent_script(enhanced_prompt, role, agent_dir)
        
        # Ensure logs directory exists
        FileUtils.mkdir_p(File.join('.enhance_swarm', 'logs'))
        
        # Spawn the Claude process
        pid = Process.spawn(
          env,
          '/bin/bash', script_file,
          chdir: agent_dir,
          out: File.join('.enhance_swarm', 'logs', "#{role}_output.log"),
          err: File.join('.enhance_swarm', 'logs', "#{role}_error.log")
        )

        # Don't wait for the process - let it run independently
        Process.detach(pid)
        
        Logger.info("Spawned Claude agent process: #{role} (PID: #{pid})")
        pid
        
      rescue StandardError => e
        Logger.error("Failed to spawn Claude process for #{role}: #{e.message}")
        # Fall back to simulation mode
        spawn_simulated_process(role, worktree_path)
      end
    end

    def build_enhanced_agent_prompt(base_prompt, role, worktree_path)
      config = EnhanceSwarm.configuration
      
      <<~PROMPT
        You are a specialized #{role.upcase} agent working as part of an EnhanceSwarm multi-agent team.
        
        ## Your Role: #{role.capitalize}
        #{get_role_description(role)}
        
        ## Working Context:
        - Project: #{config.project_name}
        - Technology Stack: #{config.technology_stack}
        - Working Directory: #{worktree_path || Dir.pwd}
        - Code Standards: #{config.code_standards.join(', ')}
        
        ## Your Task:
        #{base_prompt}
        
        ## Important Instructions:
        1. Stay focused on your role as a #{role} specialist
        2. Follow the project's code standards and conventions
        3. Work autonomously but consider integration with other agents
        4. Create high-quality, production-ready code
        5. Include comprehensive tests where appropriate
        6. Document your changes and decisions
        
        ## Available Tools:
        You have access to all Claude Code tools for file editing, terminal commands, and project analysis.
        
        Begin working on your assigned task now.
      PROMPT
    end

    def get_role_description(role)
      case role.to_s.downcase
      when 'backend'
        'You specialize in server-side logic, APIs, database design, models, and business logic implementation.'
      when 'frontend'
        'You specialize in user interfaces, client-side code, styling, user experience, and presentation layer.'
      when 'qa'
        'You specialize in testing, quality assurance, test automation, edge case analysis, and validation.'
      when 'ux'
        'You specialize in user experience design, interaction flows, accessibility, and user-centric improvements.'
      when 'general'
        'You are a general-purpose agent capable of handling various development tasks across the full stack.'
      else
        "You are a #{role} specialist agent focusing on your area of expertise."
      end
    end

    def create_agent_script(prompt, role, working_dir)
      # Create a temporary script file that will run Claude
      script_file = Tempfile.new(['agent_script', '.sh'])
      
      begin
        script_content = <<~SCRIPT
          #!/bin/bash
          set -e
          
          # Agent script for #{role} agent
          echo "Starting #{role} agent in #{working_dir}"
          
          # Change to working directory
          cd "#{working_dir}"
          
          # Create a temporary prompt file
          PROMPT_FILE=$(mktemp /tmp/claude_prompt_XXXXXX.md)
          cat > "$PROMPT_FILE" << 'EOF'
          #{prompt}
          EOF
          
          # Run Claude with the prompt
          echo "Executing Claude for #{role} agent..."
          claude --print < "$PROMPT_FILE"
          
          # Cleanup
          rm -f "$PROMPT_FILE"
          
          echo "#{role} agent completed successfully"
        SCRIPT
        
        script_file.write(script_content)
        script_file.flush
        script_file.close
        
        # Make the script executable
        File.chmod(0755, script_file.path)
        
        script_file.path
      rescue StandardError => e
        Logger.error("Failed to create agent script: #{e.message}")
        script_file.close if script_file && !script_file.closed?
        raise e
      end
    end

    def spawn_simulated_process(role, worktree_path)
      # Fallback simulation when Claude CLI is not available
      Logger.warn("Using simulation mode for #{role} agent")
      
      # Create a simple background process that simulates agent work
      pid = Process.spawn(
        '/bin/bash', '-c', 
        "sleep 30 && echo 'Simulated #{role} agent completed' > /dev/null",
        chdir: worktree_path || Dir.pwd
      )
      
      Process.detach(pid)
      Logger.info("Spawned simulated agent: #{role} (PID: #{pid})")
      pid
    end

    def build_agent_environment(role, worktree_path)
      env = ENV.to_h
      env['ENHANCE_SWARM_ROLE'] = role
      env['ENHANCE_SWARM_WORKTREE'] = worktree_path if worktree_path
      env['ENHANCE_SWARM_SESSION'] = @session_manager.read_session&.dig(:session_id)
      env
    end

    def build_agent_prompt(task, role, worktree_path)
      # Sanitize inputs
      safe_task = sanitize_task_description(task)
      safe_role = sanitize_role(role)
      safe_test_command = sanitize_command(@config.test_command)

      timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
      task_words = safe_task.split.first(5).join(' ')
      working_dir = worktree_path || Dir.pwd

      base_prompt = <<~PROMPT
        AUTONOMOUS EXECUTION REQUIRED - #{safe_role.upcase} SPECIALIST

        TASK: #{safe_task}

        WORKING DIRECTORY: #{working_dir}

        CRITICAL INSTRUCTIONS:
        1. You have FULL PERMISSION to read, write, edit files and run commands
        2. Work in the directory: #{working_dir}
        3. DO NOT wait for any permissions - proceed immediately
        4. Complete the task fully and thoroughly
        5. Test your implementation using: #{safe_test_command}
        6. When complete:
           - Run: git add -A
           - Run: git commit -m '#{safe_role}: #{task_words}...'
           - Create completion marker: echo "completed" > .enhance_swarm/completed/#{safe_role}_completed.txt
        7. Document what was implemented in your final message

        PROJECT CONTEXT:
        - Technology stack: #{Array(@config.technology_stack).join(', ')}
        - Test command: #{safe_test_command}
        - Project type: #{@config.project_name}

        Remember: You are autonomous. Make all decisions needed to complete this task successfully.
      PROMPT

      # Add role-specific instructions
      case safe_role
      when 'ux'
        base_prompt += "\n\nFOCUS: UI/UX design, templates, user experience, styling, and accessibility."
      when 'backend'
        base_prompt += "\n\nFOCUS: Models, services, APIs, business logic, database operations, and security."
      when 'frontend'
        base_prompt += "\n\nFOCUS: Controllers, views, JavaScript, forms, user interactions, and integration."
      when 'qa'
        base_prompt += "\n\nFOCUS: Comprehensive testing, edge cases, quality assurance, and validation."
      end

      base_prompt
    end

    def cleanup_failed_spawn(pid, worktree_path)
      # Clean up process if it was started
      if pid
        begin
          Process.kill('KILL', pid.to_i)
        rescue StandardError
          # Process may not exist, ignore
        end
      end

      # Clean up worktree if it was created
      if worktree_path && Dir.exist?(worktree_path)
        begin
          CommandExecutor.execute('git', 'worktree', 'remove', '--force', worktree_path)
        rescue StandardError => e
          Logger.warn("Failed to cleanup worktree #{worktree_path}: #{e.message}")
        end
      end
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
  end
end