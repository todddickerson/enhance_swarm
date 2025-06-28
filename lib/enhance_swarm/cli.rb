# frozen_string_literal: true

require 'thor'
require 'colorize'

module EnhanceSwarm
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc 'init', 'Initialize EnhanceSwarm in your project'
    def init
      say '🚀 Initializing EnhanceSwarm...', :green

      generator = Generator.new
      generator.init_project

      say "\n✅ EnhanceSwarm initialized successfully!", :green
      say "\nNext steps:", :yellow
      say '  1. Review and customize .enhance_swarm.yml'
      say '  2. Check the generated .claude/ directory'
      say "  3. Run 'enhance-swarm enhance' to start orchestration"
    end

    desc 'enhance', 'Execute the ENHANCE protocol - full multi-agent orchestration'
    option :task, type: :string, desc: 'Specific task ID to enhance'
    option :dry_run, type: :boolean, desc: 'Show what would be done without executing'
    def enhance
      say '🎯 ENHANCE Protocol Activated!', :green

      orchestrator = Orchestrator.new
      orchestrator.enhance(
        task_id: options[:task],
        dry_run: options[:dry_run]
      )
    end

    desc 'spawn TASK_DESC', 'Spawn a single agent for a specific task'
    option :role, type: :string, default: 'general', desc: 'Agent role (ux/backend/frontend/qa)'
    option :worktree, type: :boolean, default: true, desc: 'Use git worktree'
    def spawn(task_desc)
      say "🤖 Spawning agent for: #{task_desc}", :yellow

      orchestrator = Orchestrator.new
      orchestrator.spawn_single(
        task: task_desc,
        role: options[:role],
        worktree: options[:worktree]
      )
    end

    desc 'monitor', 'Monitor running swarm agents'
    option :interval, type: :numeric, default: 30, desc: 'Check interval in seconds'
    option :timeout, type: :numeric, default: 120, desc: 'Maximum monitoring time'
    def monitor
      say '👀 Monitoring swarm agents...', :yellow

      monitor = Monitor.new
      monitor.watch(
        interval: options[:interval],
        timeout: options[:timeout]
      )
    end

    desc 'status', 'Show status of all swarm operations'
    def status
      monitor = Monitor.new
      status = monitor.status

      say "\n📊 Swarm Status:", :green
      say "  Active agents: #{status[:active_agents]}", status[:active_agents] > 0 ? :yellow : :white
      say "  Completed tasks: #{status[:completed_tasks]}", :green
      say "  Worktrees: #{status[:worktrees].count}", :blue

      return unless status[:recent_branches].any?

      say "\n📌 Recent branches:", :yellow
      status[:recent_branches].each do |branch|
        say "  - #{branch}"
      end
    end

    desc 'generate GENERATOR', 'Run a specific generator'
    def generate(generator_type)
      case generator_type
      when 'claude'
        Generator.new.generate_claude_files
        say '✅ Generated Claude configuration files', :green
      when 'mcp'
        Generator.new.generate_mcp_config
        say '✅ Generated MCP configuration', :green
      when 'hooks'
        Generator.new.generate_git_hooks
        say '✅ Generated Git hooks', :green
      else
        say "❌ Unknown generator: #{generator_type}", :red
        say 'Available generators: claude, mcp, hooks'
      end
    end

    desc 'config', 'Show current configuration'
    def config
      config = EnhanceSwarm.configuration

      say "\n⚙️  EnhanceSwarm Configuration:", :green
      say "\nProject:"
      say "  Name: #{config.project_name}"
      say "  Description: #{config.project_description}"
      say "  Stack: #{config.technology_stack}"

      say "\nCommands:"
      say "  Test: #{config.test_command}"
      say "  Task: #{config.task_command}"

      say "\nOrchestration:"
      say "  Max agents: #{config.max_concurrent_agents}"
      say "  Monitor interval: #{config.monitor_interval}s"
      say "  Monitor timeout: #{config.monitor_timeout}s"

      say "\nMCP Tools:"
      config.mcp_tools.each do |tool, enabled|
        status = enabled ? '✓'.green : '✗'.red
        say "  #{tool}: #{status}"
      end
    end

    desc 'doctor', 'Check system setup and dependencies'
    def doctor
      say '🔍 Running EnhanceSwarm diagnostics...', :yellow

      checks = {
        "Ruby version": -> { RUBY_VERSION >= '3.0.0' },
        "Git installed": -> { system('which git > /dev/null 2>&1') },
        "Claude Swarm installed": -> { system('which claude-swarm > /dev/null 2>&1') },
        "Swarm Tasks gem": -> { system('gem list swarm_tasks -i > /dev/null 2>&1') },
        "Git worktree support": -> { system('git worktree list > /dev/null 2>&1') },
        "Gemini CLI": -> { system('which gemini > /dev/null 2>&1') }
      }

      all_good = true
      checks.each do |check, test|
        result = test.call
        all_good &&= result
        status = result ? '✓'.green : '✗'.red
        say "  #{status} #{check}"
      end

      if all_good
        say "\n✅ All checks passed!", :green
      else
        say "\n⚠️  Some checks failed. Please install missing dependencies.", :yellow
      end
    end

    desc 'version', 'Show EnhanceSwarm version'
    def version
      say "EnhanceSwarm v#{EnhanceSwarm::VERSION}"
    end
  end
end
