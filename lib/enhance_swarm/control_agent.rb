# frozen_string_literal: true

require 'json'
require 'tempfile'

module EnhanceSwarm
  class ControlAgent
    attr_reader :task, :config, :status, :worker_agents, :start_time

    def initialize(task_description, config = nil)
      @task = task_description
      @config = config || EnhanceSwarm.configuration
      @status = 'initializing'
      @worker_agents = {}
      @start_time = Time.now
      @communication_file = create_communication_file
      @control_process = nil
    end

    def start_coordination
      Logger.info("Starting Control Agent for task: #{@task}")
      @status = 'starting'
      
      # Spawn the Control Agent as a Claude process
      spawn_control_agent
      
      # Monitor and coordinate
      coordinate_agents
    end

    def stop_coordination
      Logger.info("Stopping Control Agent coordination")
      @status = 'stopping'
      
      # Terminate control agent process
      if @control_process
        begin
          Process.kill('TERM', @control_process)
          Process.wait(@control_process)
        rescue Errno::ESRCH, Errno::ECHILD
          # Process already terminated
        end
      end
      
      # Cleanup
      cleanup_resources
    end

    def current_status
      return default_status unless File.exist?(@communication_file)
      
      begin
        content = File.read(@communication_file)
        return default_status if content.strip.empty?
        
        # Parse the latest status update from Control Agent
        lines = content.split("\n").reject(&:empty?)
        latest_status = lines.last
        
        JSON.parse(latest_status)
      rescue JSON::ParserError, StandardError => e
        Logger.warn("Failed to parse control agent status: #{e.message}")
        default_status
      end
    end

    def worker_agent_summary
      status = current_status
      {
        total: status['active_agents'].length + status['completed_agents'].length,
        active: status['active_agents'].length,
        completed: status['completed_agents'].length,
        progress: status['progress_percentage'] || 0,
        phase: status['phase'] || 'unknown',
        estimated_completion: status['estimated_completion']
      }
    end

    private

    def spawn_control_agent
      prompt = build_control_agent_prompt
      
      # Create a temporary prompt file
      prompt_file = Tempfile.new(['control_prompt', '.txt'])
      prompt_file.write(prompt)
      prompt_file.close
      
      begin
        # Spawn Control Agent using claude command
        @control_process = RetryHandler.with_retry(max_retries: 2) do
          CommandExecutor.execute_async(
            'claude', 
            '--role=control',
            '--file', prompt_file.path,
            '--output', @communication_file,
            '--continuous'
          )
        end
        
        Logger.info("Control Agent spawned with PID: #{@control_process}")
        @status = 'coordinating'
        
      rescue RetryHandler::RetryError, CommandExecutor::CommandError => e
        Logger.error("Failed to spawn Control Agent: #{e.message}")
        @status = 'failed'
        raise
      ensure
        prompt_file.unlink
      end
    end

    def coordinate_agents
      coordination_thread = Thread.new do
        while @status == 'coordinating'
          begin
            # Read latest status from Control Agent
            agent_status = current_status
            
            # Update our internal state
            update_worker_agents(agent_status)
            
            # Check if coordination is complete
            if agent_status['status'] == 'completed'
              @status = 'completed'
              break
            elsif agent_status['status'] == 'failed'
              @status = 'failed'
              break
            end
            
            sleep(5) # Check every 5 seconds
            
          rescue StandardError => e
            Logger.error("Control Agent coordination error: #{e.message}")
            sleep(10) # Back off on errors
          end
        end
        
        Logger.info("Control Agent coordination finished with status: #{@status}")
      end
      
      coordination_thread
    end

    def update_worker_agents(agent_status)
      # Track active agents
      agent_status['active_agents']&.each do |agent_id|
        unless @worker_agents[agent_id]
          @worker_agents[agent_id] = {
            id: agent_id,
            status: 'active',
            start_time: Time.now
          }
        end
      end
      
      # Track completed agents
      agent_status['completed_agents']&.each do |agent_id|
        if @worker_agents[agent_id]
          @worker_agents[agent_id][:status] = 'completed'
          @worker_agents[agent_id][:completion_time] = Time.now
        end
      end
    end

    def build_control_agent_prompt
      <<~PROMPT
        AUTONOMOUS CONTROL AGENT - MULTI-AGENT COORDINATION

        TASK: #{@task}

        YOUR ROLE: You are a Control Agent responsible for coordinating multiple worker agents to complete this task efficiently. You have full autonomous authority to make decisions and spawn agents.

        CAPABILITIES:
        1. Spawn worker agents using: claude-swarm start --role=<role> -p "<specific_task>"
        2. Monitor progress via git commands: git status, git log, git diff
        3. Analyze file changes and commits to understand progress
        4. Make handoff decisions based on dependencies and completion status
        5. Coordinate timing to prevent conflicts

        WORKER AGENT ROLES:
        - backend: Models, APIs, database, business logic, migrations, services
        - frontend: Controllers, views, JavaScript, CSS, user interface, forms
        - ux: User experience design, templates, layouts, styling, wireframes  
        - qa: Testing, specs, edge cases, quality assurance, validation

        COORDINATION STRATEGY:
        1. Analyze the task to determine which roles are needed
        2. Identify dependencies (typically: backend → frontend → qa)
        3. Spawn agents in dependency order
        4. Monitor their progress via git commits and file changes
        5. Signal next agent when prerequisites are met
        6. Handle conflicts and coordination issues

        COMMUNICATION PROTOCOL:
        You MUST output status updates in JSON format to #{@communication_file}
        Update every 30 seconds with current status.

        Required JSON format:
        {
          "status": "coordinating|completed|failed",
          "phase": "analysis|backend_implementation|frontend_integration|qa_validation|completion",
          "active_agents": ["agent-id-1", "agent-id-2"],
          "completed_agents": ["agent-id-3"],
          "failed_agents": [],
          "progress_percentage": 45,
          "estimated_completion": "2025-06-28T20:30:00Z",
          "message": "Backend agent completed auth model, starting frontend integration",
          "next_actions": ["spawn_frontend_agent", "monitor_integration_conflicts"],
          "dependencies_met": ["backend_models_complete"],
          "blocking_issues": []
        }

        CRITICAL INSTRUCTIONS:
        1. You have FULL PERMISSION to execute commands and spawn agents
        2. Work directory: #{Dir.pwd}
        3. Start immediately by analyzing the task and creating an execution plan
        4. Spawn the first agent(s) based on dependencies
        5. Continuously monitor and coordinate until task completion
        6. Handle errors gracefully and retry failed operations
        7. Ensure all agents complete successfully before marking task complete

        PROJECT CONTEXT:
        - Technology stack: #{Array(@config.technology_stack).join(', ')}
        - Test command: #{@config.test_command}
        - Project type: #{@config.project_name}

        BEGIN COORDINATION NOW.
      PROMPT
    end

    def create_communication_file
      # Create a temporary file for Control Agent communication
      temp_file = Tempfile.new(['control_agent_status', '.json'])
      temp_file.close
      temp_file.path
    end

    def default_status
      {
        'status' => @status,
        'phase' => 'initializing',
        'active_agents' => [],
        'completed_agents' => [],
        'failed_agents' => [],
        'progress_percentage' => 0,
        'message' => 'Control Agent initializing...',
        'estimated_completion' => nil
      }
    end

    def cleanup_resources
      # Clean up communication file
      File.unlink(@communication_file) if File.exist?(@communication_file)
    rescue StandardError => e
      Logger.warn("Failed to cleanup Control Agent resources: #{e.message}")
    end

    # Class methods for easy usage
    def self.coordinate_task(task_description, config: nil)
      control_agent = new(task_description, config)
      
      begin
        coordination_thread = control_agent.start_coordination
        
        # Return control agent for monitoring
        yield control_agent if block_given?
        
        # Wait for coordination to complete
        coordination_thread.join if coordination_thread
        
        control_agent.current_status
      ensure
        control_agent.stop_coordination
      end
    end

    # Enhanced progress tracking integration
    def track_progress_with_streamer(streamer = nil)
      return unless streamer
      
      Thread.new do
        while @status == 'coordinating'
          status = current_status
          
          # Update progress tracker
          progress = status['progress_percentage'] || 0
          message = status['message'] || 'Coordinating agents...'
          
          streamer.set_progress(progress,
                              message: message,
                              operation: 'control_coordination',
                              details: {
                                phase: status['phase'],
                                active_agents: status['active_agents']&.length || 0,
                                completed_agents: status['completed_agents']&.length || 0
                              })
          
          break if %w[completed failed].include?(status['status'])
          
          sleep(2)
        end
      end
    end
  end
end