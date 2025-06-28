# frozen_string_literal: true

require_relative "enhance_swarm/version"
require_relative "enhance_swarm/configuration"
require_relative "enhance_swarm/cli"
require_relative "enhance_swarm/orchestrator"
require_relative "enhance_swarm/monitor"
require_relative "enhance_swarm/task_manager"
require_relative "enhance_swarm/generator"
require_relative "enhance_swarm/mcp_integration"

module EnhanceSwarm
  class Error < StandardError; end
  
  class << self
    def configure
      yield(configuration)
    end
    
    def configuration
      @configuration ||= Configuration.new
    end
    
    def root
      @root ||= find_project_root
    end
    
    def enhance!
      Orchestrator.new.enhance
    end
    
    private
    
    def find_project_root
      current = Dir.pwd
      while current != "/" && !File.exist?(File.join(current, ".enhance_swarm.yml"))
        current = File.dirname(current)
      end
      
      File.exist?(File.join(current, ".enhance_swarm.yml")) ? current : Dir.pwd
    end
  end
end