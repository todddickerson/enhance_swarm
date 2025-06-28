# frozen_string_literal: true

require_relative 'enhance_swarm/version'
require_relative 'enhance_swarm/configuration'
require_relative 'enhance_swarm/command_executor'
require_relative 'enhance_swarm/retry_handler'
require_relative 'enhance_swarm/logger'
require_relative 'enhance_swarm/dependency_validator'
require_relative 'enhance_swarm/cleanup_manager'
require_relative 'enhance_swarm/signal_handler'
require_relative 'enhance_swarm/agent_reviewer'
require_relative 'enhance_swarm/progress_tracker'
require_relative 'enhance_swarm/output_streamer'
require_relative 'enhance_swarm/control_agent'
require_relative 'enhance_swarm/notification_manager'
require_relative 'enhance_swarm/interrupt_handler'
require_relative 'enhance_swarm/cli'
require_relative 'enhance_swarm/orchestrator'
require_relative 'enhance_swarm/monitor'
require_relative 'enhance_swarm/task_manager'
require_relative 'enhance_swarm/generator'
require_relative 'enhance_swarm/mcp_integration'

module EnhanceSwarm
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class CommandError < Error; end

  class << self
    def configure
      yield(configuration)
    rescue StandardError => e
      raise ConfigurationError, "Configuration failed: #{e.message}"
    end

    def configuration
      @configuration ||= Configuration.new
    rescue StandardError => e
      raise ConfigurationError, "Failed to initialize configuration: #{e.message}"
    end

    def root
      @root ||= find_project_root
    rescue StandardError => e
      puts "Warning: Could not determine project root: #{e.message}"
      Dir.pwd
    end

    def enhance!
      Orchestrator.new.enhance
    rescue StandardError => e
      puts "Enhancement failed: #{e.message}".colorize(:red)
      false
    end

    private

    def find_project_root
      current = Dir.pwd
      current = File.dirname(current) while current != '/' && !File.exist?(File.join(current, '.enhance_swarm.yml'))

      File.exist?(File.join(current, '.enhance_swarm.yml')) ? current : Dir.pwd
    end
  end
end
