# frozen_string_literal: true

require 'psych'

module EnhanceSwarm
  class Configuration
    attr_accessor :project_name, :project_description, :technology_stack,
                  :test_command, :task_command, :task_move_command,
                  :code_standards, :important_notes,
                  :max_concurrent_agents, :monitor_interval,
                  :monitor_timeout, :worktree_enabled,
                  :mcp_tools, :gemini_enabled, :desktop_commander_enabled

    def initialize
      # Project defaults
      @project_name = "Project"
      @project_description = "A project managed by EnhanceSwarm"
      @technology_stack = "Ruby on Rails"
      
      # Commands
      @test_command = "bundle exec rails test"
      @task_command = "bundle exec swarm-tasks"
      @task_move_command = "bundle exec swarm-tasks move"
      
      # Standards
      @code_standards = default_code_standards
      @important_notes = []
      
      # Orchestration settings
      @max_concurrent_agents = 4
      @monitor_interval = 30
      @monitor_timeout = 120  # 2 minutes max per monitoring session
      @worktree_enabled = true
      
      # MCP settings
      @mcp_tools = {
        context7: true,
        sequential: true,
        magic_ui: true,
        puppeteer: true
      }
      @gemini_enabled = true
      @desktop_commander_enabled = true
      
      load_from_file if config_file_exists?
    end
    
    def to_h
      {
        project: {
          name: @project_name,
          description: @project_description,
          technology_stack: @technology_stack
        },
        commands: {
          test: @test_command,
          task: @task_command,
          task_move: @task_move_command
        },
        orchestration: {
          max_concurrent_agents: @max_concurrent_agents,
          monitor_interval: @monitor_interval,
          monitor_timeout: @monitor_timeout,
          worktree_enabled: @worktree_enabled
        },
        mcp: {
          tools: @mcp_tools,
          gemini_enabled: @gemini_enabled,
          desktop_commander_enabled: @desktop_commander_enabled
        },
        standards: {
          code: @code_standards,
          notes: @important_notes
        }
      }
    end
    
    def save!
      File.write(config_file_path, Psych.dump(to_h))
    end
    
    private
    
    def config_file_path
      File.join(EnhanceSwarm.root, ".enhance_swarm.yml")
    end
    
    def config_file_exists?
      File.exist?(config_file_path)
    end
    
    def load_from_file
      config = Psych.safe_load(File.read(config_file_path), permitted_classes: [Symbol])
      
      # Project settings
      @project_name = config.dig("project", "name") || @project_name
      @project_description = config.dig("project", "description") || @project_description
      @technology_stack = config.dig("project", "technology_stack") || @technology_stack
      
      # Commands
      @test_command = config.dig("commands", "test") || @test_command
      @task_command = config.dig("commands", "task") || @task_command
      @task_move_command = config.dig("commands", "task_move") || @task_move_command
      
      # Orchestration
      @max_concurrent_agents = config.dig("orchestration", "max_concurrent_agents") || @max_concurrent_agents
      @monitor_interval = config.dig("orchestration", "monitor_interval") || @monitor_interval
      @monitor_timeout = config.dig("orchestration", "monitor_timeout") || @monitor_timeout
      @worktree_enabled = config.dig("orchestration", "worktree_enabled") != false
      
      # MCP
      @mcp_tools = config.dig("mcp", "tools") || @mcp_tools
      @gemini_enabled = config.dig("mcp", "gemini_enabled") != false
      @desktop_commander_enabled = config.dig("mcp", "desktop_commander_enabled") != false
      
      # Standards
      @code_standards = config.dig("standards", "code") || @code_standards
      @important_notes = config.dig("standards", "notes") || @important_notes
    end
    
    def default_code_standards
      [
        "Follow framework conventions",
        "Use service objects for business logic",
        "Keep controllers thin",
        "Write tests for all new features",
        "Use strong validations in models"
      ]
    end
  end
end