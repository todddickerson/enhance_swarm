# frozen_string_literal: true

require 'erb'
require 'fileutils'
require_relative 'command_executor'

module EnhanceSwarm
  class Generator
    def initialize
      @config = EnhanceSwarm.configuration
      @template_dir = File.expand_path('../../templates', __dir__)
    end

    def init_project
      create_directories
      create_config_file
      generate_claude_files
      generate_git_hooks
      setup_task_management

      puts '✅ Project initialized with EnhanceSwarm'
    end

    def generate_claude_files
      claude_dir = File.join(EnhanceSwarm.root, '.claude')
      FileUtils.mkdir_p(claude_dir)

      # Generate main Claude files
      %w[CLAUDE.md RULES.md MCP.md PERSONAS.md].each do |file|
        generate_from_template(
          "claude/#{file}",
          File.join(claude_dir, file)
        )
      end

      puts '✅ Generated Claude configuration files in .claude/'
    end

    def generate_mcp_config
      mcp_dir = File.join(EnhanceSwarm.root, '.mcp')
      FileUtils.mkdir_p(mcp_dir)

      # Generate MCP configuration
      config = {
        'tools' => {
          'gemini' => {
            'enabled' => @config.gemini_enabled,
            'command' => 'gemini',
            'description' => 'Large context analysis with Gemini CLI'
          },
          'desktop_commander' => {
            'enabled' => @config.desktop_commander_enabled,
            'description' => 'File operations outside project directory'
          }
        }
      }

      File.write(
        File.join(mcp_dir, 'config.json'),
        JSON.pretty_generate(config)
      )

      puts '✅ Generated MCP configuration'
    end

    def generate_git_hooks
      hooks_dir = File.join(EnhanceSwarm.root, '.git', 'hooks')
      FileUtils.mkdir_p(hooks_dir)

      # Pre-commit hook with sanitized command
      safe_test_command = sanitize_shell_command(@config.test_command)
      pre_commit = <<~HOOK
        #!/bin/bash
        # EnhanceSwarm pre-commit hook

        # Run tests before committing
        echo "Running tests..."
        #{safe_test_command}

        if [ $? -ne 0 ]; then
          echo "❌ Tests failed! Please fix before committing."
          exit 1
        fi

        echo "✅ All tests passed!"
      HOOK

      hook_path = File.join(hooks_dir, 'pre-commit')
      File.write(hook_path, pre_commit)
      File.chmod(0o755, hook_path)

      puts '✅ Generated Git hooks'
    end

    def setup_task_management
      # Check if swarm-tasks is available

      CommandExecutor.execute('gem', 'list', 'swarm_tasks', '-i')
      puts '✅ swarm_tasks gem detected'
    rescue CommandExecutor::CommandError
      # Create basic task directories
      %w[backlog active completed].each do |state|
        FileUtils.mkdir_p(File.join(EnhanceSwarm.root, 'tasks', state))
      end

      puts '⚠️  swarm_tasks gem not found. Created basic task directories.'
      puts '   Install with: gem install swarm_tasks'
    end

    private

    def create_directories
      dirs = [
        '.claude',
        '.claude/agents',
        '.claude/automation',
        '.mcp',
        'tasks/backlog',
        'tasks/active',
        'tasks/completed'
      ]

      dirs.each do |dir|
        FileUtils.mkdir_p(File.join(EnhanceSwarm.root, dir))
      end
    end

    def create_config_file
      config_path = File.join(EnhanceSwarm.root, '.enhance_swarm.yml')

      return if File.exist?(config_path)

      @config.save!
      puts '✅ Created .enhance_swarm.yml configuration file'
    end

    def generate_from_template(template_name, output_path)
      template_path = File.join(@template_dir, template_name)

      unless File.exist?(template_path)
        puts "⚠️  Template not found: #{template_name}"
        return
      end

      # Read template
      template_content = File.read(template_path)
      erb = ERB.new(template_content)

      # Render with configuration
      rendered = erb.result(binding)

      # Write output
      File.write(output_path, rendered)
    end

    # Helper methods for ERB templates
    def project_name
      @config.project_name
    end

    def project_description
      @config.project_description
    end

    def technology_stack
      @config.technology_stack
    end

    def test_command
      @config.test_command
    end

    def task_command
      @config.task_command
    end

    def task_move_command
      @config.task_move_command
    end

    def code_standards
      @config.code_standards.join("\n")
    end

    def important_notes
      @config.important_notes.join("\n")
    end

    def sanitize_shell_command(command)
      # Remove dangerous shell metacharacters while preserving basic functionality
      command.to_s.gsub(/[;&|`$\\]/, '').strip
    end
  end
end
