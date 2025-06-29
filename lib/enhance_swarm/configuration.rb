# frozen_string_literal: true

require 'psych'
require_relative 'project_analyzer'

module EnhanceSwarm
  class Configuration
    attr_accessor :project_name, :project_description, :technology_stack,
                  :test_command, :task_command, :task_move_command,
                  :code_standards, :important_notes,
                  :max_concurrent_agents, :monitor_interval,
                  :monitor_timeout, :worktree_enabled,
                  :mcp_tools, :gemini_enabled, :desktop_commander_enabled,
                  :max_memory_mb, :max_disk_mb

    def initialize
      # Apply smart defaults from project analysis if no config exists
      if config_file_exists?
        apply_hardcoded_defaults
        load_from_file
      else
        apply_smart_defaults
      end
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

    def apply_hardcoded_defaults
      # Project defaults
      @project_name = 'Project'
      @project_description = 'A project managed by EnhanceSwarm'
      @technology_stack = 'Ruby on Rails'

      # Commands
      @test_command = 'bundle exec rails test'
      @task_command = 'bundle exec swarm-tasks'
      @task_move_command = 'bundle exec swarm-tasks move'

      # Standards
      @code_standards = default_code_standards
      @important_notes = []

      # Orchestration settings
      @max_concurrent_agents = 4
      @monitor_interval = 30
      @monitor_timeout = 120 # 2 minutes max per monitoring session
      @worktree_enabled = true

      # Resource limits
      @max_memory_mb = 2048  # 2GB max memory for all agents
      @max_disk_mb = 1024    # 1GB max disk usage

      # MCP settings
      @mcp_tools = {
        context7: true,
        sequential: true,
        magic_ui: true,
        puppeteer: true
      }
      @gemini_enabled = true
      @desktop_commander_enabled = true
    end

    def apply_smart_defaults
      Logger.info("No configuration file found, applying smart defaults based on project analysis")
      
      # Analyze the current project
      analyzer = ProjectAnalyzer.new
      analyzer.analyze
      smart_defaults = analyzer.generate_smart_defaults

      # Apply smart defaults with fallbacks
      @project_name = smart_defaults[:project_name] || File.basename(Dir.pwd)
      @project_description = smart_defaults[:project_description] || 'A project managed by EnhanceSwarm'
      @technology_stack = smart_defaults[:technology_stack]&.join(', ') || 'Multiple Technologies'

      # Smart command detection
      @test_command = smart_defaults[:test_command] || detect_test_command_fallback
      @task_command = 'bundle exec swarm-tasks'
      @task_move_command = 'bundle exec swarm-tasks move'

      # Code standards based on project type
      @code_standards = generate_smart_code_standards(analyzer.analysis_results[:project_type])
      @important_notes = generate_smart_notes(analyzer.analysis_results)

      # Orchestration settings based on project size
      @max_concurrent_agents = smart_defaults[:max_concurrent_agents] || 3
      @monitor_interval = 30
      @monitor_timeout = 120
      @worktree_enabled = true

      # MCP settings - enable all by default for smart detection
      @mcp_tools = {
        context7: true,
        sequential: true,
        magic_ui: analyzer.analysis_results[:frontend_framework] ? true : false,
        puppeteer: analyzer.analysis_results[:testing_framework]&.any? { |f| f.include?('Cypress') || f.include?('Playwright') } || false
      }
      @gemini_enabled = true
      @desktop_commander_enabled = smart_defaults[:has_documentation] || false

      Logger.info("Applied smart defaults for #{@project_name} (#{@technology_stack})")
    end

    def detect_test_command_fallback
      return 'bundle exec rspec' if File.exist?('spec')
      return 'bundle exec rails test' if File.exist?('test')
      return 'npm test' if File.exist?('package.json')
      return 'pytest' if File.exist?('pytest.ini') || File.exist?('conftest.py')
      
      'echo "No test command configured"'
    end

    def generate_smart_code_standards(project_type)
      base_standards = [
        'Follow framework conventions',
        'Write tests for all new features',
        'Use clear, descriptive naming'
      ]

      case project_type
      when 'rails'
        base_standards + [
          'Use service objects for business logic',
          'Keep controllers thin',
          'Use strong validations in models'
        ]
      when 'react', 'vue', 'angular', 'nextjs'
        base_standards + [
          'Use functional components with hooks',
          'Implement proper state management',
          'Optimize for performance and accessibility'
        ]
      when 'django', 'flask'
        base_standards + [
          'Follow MVC patterns',
          'Use proper authentication and authorization',
          'Implement comprehensive API documentation'
        ]
      else
        base_standards + [
          'Maintain consistent code style',
          'Document complex logic',
          'Use version control best practices'
        ]
      end
    end

    def generate_smart_notes(analysis_results)
      notes = []

      if analysis_results[:documentation]&.dig(:has_docs)
        notes << "Project has documentation in #{analysis_results[:documentation][:primary_path]} - consider this context for changes"
      end

      if analysis_results[:testing_framework]&.any?
        frameworks = analysis_results[:testing_framework].join(', ')
        notes << "Testing framework(s) detected: #{frameworks} - ensure new features include tests"
      end

      if analysis_results[:deployment]&.any?
        deployments = analysis_results[:deployment].join(', ')
        notes << "Deployment configurations found: #{deployments} - consider deployment impact for changes"
      end

      if analysis_results[:database]&.any?
        databases = analysis_results[:database].join(', ')
        notes << "Database(s) in use: #{databases} - consider data migration needs"
      end

      notes
    end

    def config_file_path
      File.join(EnhanceSwarm.root, '.enhance_swarm.yml')
    end

    def config_file_exists?
      File.exist?(config_file_path)
    end

    def load_from_file
      config = Psych.safe_load(File.read(config_file_path), permitted_classes: [Symbol])

      # Project settings with validation
      @project_name = validate_string(config.dig('project', 'name')) || @project_name
      @project_description = validate_string(config.dig('project', 'description')) || @project_description
      @technology_stack = validate_string(config.dig('project', 'technology_stack')) || @technology_stack

      # Commands with validation
      @test_command = validate_command(config.dig('commands', 'test')) || @test_command
      @task_command = validate_command(config.dig('commands', 'task')) || @task_command
      @task_move_command = validate_command(config.dig('commands', 'task_move')) || @task_move_command

      # Orchestration with validation
      @max_concurrent_agents = validate_positive_integer(config.dig('orchestration',
                                                                    'max_concurrent_agents')) || @max_concurrent_agents
      @monitor_interval = validate_positive_integer(config.dig('orchestration',
                                                               'monitor_interval')) || @monitor_interval
      @monitor_timeout = validate_positive_integer(config.dig('orchestration', 'monitor_timeout')) || @monitor_timeout
      @worktree_enabled = config.dig('orchestration', 'worktree_enabled') != false

      # MCP
      @mcp_tools = validate_hash(config.dig('mcp', 'tools')) || @mcp_tools
      @gemini_enabled = config.dig('mcp', 'gemini_enabled') != false
      @desktop_commander_enabled = config.dig('mcp', 'desktop_commander_enabled') != false

      # Standards
      @code_standards = validate_array(config.dig('standards', 'code')) || @code_standards
      @important_notes = validate_array(config.dig('standards', 'notes')) || @important_notes
    rescue Psych::SyntaxError => e
      puts "Configuration file has invalid YAML syntax: #{e.message}"
      # Use defaults
    rescue StandardError => e
      puts "Error loading configuration: #{e.message}"
      # Use defaults
    end

    def default_code_standards
      [
        'Follow framework conventions',
        'Use service objects for business logic',
        'Keep controllers thin',
        'Write tests for all new features',
        'Use strong validations in models'
      ]
    end

    # Validation methods
    def validate_string(value)
      return nil unless value.is_a?(String)

      # Remove dangerous characters
      sanitized = value.gsub(/[`$\\;|&]/, '').strip
      sanitized.empty? ? nil : sanitized
    end

    def validate_command(value)
      return nil unless value.is_a?(String)

      # Only allow safe command characters
      sanitized = value.gsub(/[;|&`$\\]/, '').strip
      return nil if sanitized.empty?

# Check for common dangerous patterns but allow 'exec' in normal contexts
      dangerous_patterns = [/\brm\s+-rf/, /\|\s*sh\b/, /\beval\s*\(/, /\bexec\s*\(/]
      dangerous_patterns.each do |pattern|
        return nil if sanitized.match?(pattern)
      end

      sanitized
    end

    def validate_positive_integer(value)
      return nil unless value.is_a?(Integer) || (value.is_a?(String) && value.match?(/\A\d+\z/))

      int_value = value.to_i
      int_value.positive? ? int_value : nil
    end

    def validate_array(value)
      return nil unless value.is_a?(Array)

      # Validate each element as a string
      validated = value.map { |item| validate_string(item) }.compact
      validated.empty? ? nil : validated
    end

    def validate_hash(value)
      return nil unless value.is_a?(Hash)

      # Ensure all keys are strings or symbols and values are safe
      validated = {}
      value.each do |k, v|
        next unless k.is_a?(String) || k.is_a?(Symbol)

        validated[k] = case v
                       when String
                         validate_string(v)
                       when TrueClass, FalseClass
                         v
                       when Integer
                         validate_positive_integer(v)
                       end
      end

      validated.empty? ? nil : validated
    end
  end
end
