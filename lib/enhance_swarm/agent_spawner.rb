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
      # Create a temporary prompt file
      prompt_file = Tempfile.new(['agent_prompt', '.txt'])
      prompt_file.write(prompt)
      prompt_file.close

      begin
        # Determine the command to run Claude
        # This could be 'claude' CLI if available, or a fallback method
        claude_command = determine_claude_command

        # Prepare environment
        env = build_agent_environment(role, worktree_path)
        
        # Spawn the process
        pid = Process.spawn(
          env,
          claude_command,
          '--role', role,
          '--file', prompt_file.path,
          '--autonomous',
          chdir: worktree_path || Dir.pwd,
          out: File.join('.enhance_swarm', 'logs', "#{role}_output.log"),
          err: File.join('.enhance_swarm', 'logs', "#{role}_error.log")
        )

        # Don't wait for the process - let it run independently
        Process.detach(pid)
        
        Logger.info("Spawned Claude process for #{role} with PID: #{pid}")
        pid

      rescue StandardError => e
        Logger.error("Failed to spawn Claude process: #{e.message}")
        # Try fallback method
        spawn_fallback_agent(prompt, role, worktree_path)
      ensure
        prompt_file.unlink if prompt_file
      end
    end

    def determine_claude_command
      # Check for available Claude CLI tools
      claude_commands = ['claude', 'claude-cli', 'npx claude']
      
      claude_commands.each do |cmd|
        begin
          # Test if command exists
          Open3.capture3("which #{cmd.split.first}")
          return cmd
        rescue StandardError
          next
        end
      end
      
      # If no Claude CLI found, we'll use a fallback
      raise StandardError, "No Claude CLI found - using fallback method"
    end

    def spawn_fallback_agent(prompt, role, worktree_path)
      # Fallback: Create a script that the user can run manually
      # or integrate with existing Claude Code session
      
      Logger.warn("Using fallback agent spawning for #{role}")
      
      # Create a script file that contains the prompt and instructions
      script_path = File.join('.enhance_swarm', 'agent_scripts', "#{role}_agent.md")
      FileUtils.mkdir_p(File.dirname(script_path))
      
      script_content = <<~SCRIPT
        # #{role.upcase} Agent Task
        
        **Working Directory:** #{worktree_path || Dir.pwd}
        **Role:** #{role}
        **Spawned:** #{Time.now}
        
        ## Instructions
        
        #{prompt}
        
        ## Status
        
        To mark this agent as completed, create a file: `.enhance_swarm/completed/#{role}_completed.txt`
      SCRIPT
      
      File.write(script_path, script_content)
      
      # Return a pseudo-PID (timestamp) for tracking
      pseudo_pid = Time.now.to_i
      Logger.info("Created fallback agent script: #{script_path} (tracking ID: #{pseudo_pid})")
      pseudo_pid
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