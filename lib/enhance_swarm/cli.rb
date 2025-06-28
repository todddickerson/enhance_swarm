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
    option :json, type: :boolean, desc: 'Output status in JSON format'
    def status
      monitor = Monitor.new
      status = monitor.status
      
      if options[:json]
        puts JSON.pretty_generate({
          timestamp: Time.now.iso8601,
          status: status,
          health: system_health_summary
        })
        return
      end

      say "\n📊 Swarm Status:", :green
      say "  Active agents: #{status[:active_agents]}", status[:active_agents] > 0 ? :yellow : :white
      say "  Completed tasks: #{status[:completed_tasks]}", :green
      say "  Worktrees: #{status[:worktrees].count}", :blue

      if status[:recent_branches].any?
        say "\n📌 Recent branches:", :yellow
        status[:recent_branches].each do |branch|
          say "  - #{branch}"
        end
      end
      
      # Show health summary
      health = system_health_summary
      if health[:issues].any?
        say "\n⚠️  Health Issues:", :yellow
        health[:issues].each do |issue|
          say "  - #{issue}", :red
        end
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
    option :detailed, type: :boolean, desc: 'Show detailed dependency information'
    option :json, type: :boolean, desc: 'Output results in JSON format'
    def doctor
      if options[:json]
        run_detailed_doctor_json
      else
        run_basic_doctor(options[:detailed])
      end
    end
    
    no_commands do
      def system_health_summary
        issues = []
        
        # Check for stale worktrees
        begin
          output = `git worktree list 2>/dev/null`
          worktree_count = output.lines.count { |line| line.include?('swarm/') }
          issues << "#{worktree_count} stale swarm worktrees" if worktree_count > 5
        rescue
          # Ignore errors
        end
        
        # Check disk space (basic)
        begin
          stat = File.statvfs('.')
          free_gb = (stat.bavail * stat.frsize) / (1024 * 1024 * 1024)
          issues << "Low disk space (#{free_gb}GB free)" if free_gb < 1
        rescue
          # Not supported on all platforms
        end
        
        { issues: issues }
      end
    end
    
    private
    
    def run_basic_doctor(detailed)
      say '🔍 Running EnhanceSwarm diagnostics...', :yellow

      validation_results = DependencyValidator.validate_all
      
      validation_results[:results].each do |tool, result|
        status = result[:passed] ? '✓'.green : '✗'.red
        
        if detailed && result[:version]
          say "  #{status} #{tool.capitalize}: #{result[:version]} (required: #{result[:required]})"
        else
          say "  #{status} #{tool.capitalize}"
        end
        
        if !result[:passed] && result[:error]
          say "    Error: #{result[:error]}", :red
        end
      end

      if validation_results[:passed]
        say "\n✅ All critical dependencies met!", :green
      else
        say "\n⚠️  Some dependencies failed. Please address the issues above.", :yellow
        exit(1) if ENV['ENHANCE_SWARM_STRICT'] == 'true'
      end
      
      # Run functional tests if requested
      if detailed
        say "\n🔧 Running functionality tests...", :yellow
        functional_results = DependencyValidator.validate_functionality
        
        functional_results.each do |test, result|
          status = result[:passed] ? '✓'.green : '✗'.red
          say "  #{status} #{test.to_s.humanize}"
          
          if !result[:passed] && result[:error]
            say "    Error: #{result[:error]}", :red
          end
        end
      end
    end
    
    def run_detailed_doctor_json
      validation_results = DependencyValidator.validate_all
      functional_results = DependencyValidator.validate_functionality
      
      output = {
        timestamp: Time.now.iso8601,
        version: EnhanceSwarm::VERSION,
        dependencies: validation_results,
        functionality: functional_results,
        environment: {
          ruby_version: RUBY_VERSION,
          platform: RUBY_PLATFORM,
          pwd: Dir.pwd
        }
      }
      
      puts JSON.pretty_generate(output)
    end

    desc 'version', 'Show EnhanceSwarm version'
    option :json, type: :boolean, desc: 'Output version info in JSON format'
    def version
      if options[:json]
        puts JSON.pretty_generate({
          version: EnhanceSwarm::VERSION,
          ruby_version: RUBY_VERSION,
          platform: RUBY_PLATFORM
        })
      else
        say "EnhanceSwarm v#{EnhanceSwarm::VERSION}"
      end
    end
    
    desc 'cleanup', 'Clean up stale swarm resources'
    option :dry_run, type: :boolean, desc: 'Show what would be cleaned without doing it'
    option :all, type: :boolean, desc: 'Clean all swarm resources (worktrees, branches, etc.)'
    def cleanup
      if options[:dry_run]
        say '🧽 Dry run - showing what would be cleaned:', :yellow
        # Implementation would show what would be cleaned
        say 'Dry run cleanup not implemented yet', :yellow
      elsif options[:all]
        say '🧽 Cleaning all swarm resources...', :yellow
        results = CleanupManager.cleanup_all_swarm_resources
        
        say "\n✅ Cleanup completed:", :green
        say "  Worktrees: #{results[:worktrees][:count]} processed"
        say "  Branches: #{results[:branches][:count]} processed"
        say "  Temp files: #{results[:temp_files][:files_removed]} removed"
      else
        say 'Please specify --all or --dry-run', :red
        say 'Use --help for more information'
      end
    end
  end
end
