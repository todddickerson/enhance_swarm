# frozen_string_literal: true

require_relative 'command_executor'

module EnhanceSwarm
  class DependencyValidator
    REQUIRED_TOOLS = {
      'git' => {
        min_version: '2.20.0',
        check_command: 'git --version',
        version_regex: /git version (\d+\.\d+\.\d+)/,
        critical: true
      },
      'claude-swarm' => {
        min_version: '0.1.0',
        check_command: 'claude-swarm --version',
        version_regex: /(\d+\.\d+\.\d+)/,
        critical: false
      }
    }.freeze

    def self.validate_all
      results = {}
      all_critical_passed = true

      REQUIRED_TOOLS.each do |tool, config|
        result = validate_tool(tool, config)
        results[tool] = result
        
        if config[:critical] && !result[:passed]
          all_critical_passed = false
        end
      end

      # Check Ruby version
      ruby_result = validate_ruby_version
      results['ruby'] = ruby_result
      all_critical_passed = false unless ruby_result[:passed]

      {
        passed: all_critical_passed,
        results: results,
        summary: generate_summary(results)
      }
    end

    def self.validate_tool(tool, config)
      begin
        output = CommandExecutor.execute(config[:check_command].split.first, 
                                       *config[:check_command].split[1..], 
                                       timeout: 10)
        
        if config[:version_regex]
          version_match = output.match(config[:version_regex])
          if version_match
            version = version_match[1]
            meets_requirement = version_meets_requirement?(version, config[:min_version])
            
            {
              passed: meets_requirement,
              available: true,
              version: version,
              required: config[:min_version],
              error: meets_requirement ? nil : "Version #{version} is below required #{config[:min_version]}"
            }
          else
            {
              passed: false,
              available: true,
              version: 'unknown',
              required: config[:min_version],
              error: "Could not parse version from: #{output}"
            }
          end
        else
          # Tool exists but version check not configured
          {
            passed: true,
            available: true,
            version: 'unknown',
            required: config[:min_version],
            error: nil
          }
        end
      rescue CommandExecutor::CommandError => e
        {
          passed: false,
          available: false,
          version: nil,
          required: config[:min_version],
          error: "Tool not available: #{e.message}"
        }
      end
    end

    def self.validate_ruby_version
      current = RUBY_VERSION
      required = '3.0.0'
      meets_requirement = version_meets_requirement?(current, required)

      {
        passed: meets_requirement,
        available: true,
        version: current,
        required: required,
        error: meets_requirement ? nil : "Ruby #{current} is below required #{required}"
      }
    end

    def self.version_meets_requirement?(current, required)
      Gem::Version.new(current) >= Gem::Version.new(required)
    rescue ArgumentError
      false
    end

    def self.generate_summary(results)
      total = results.size
      passed = results.count { |_, result| result[:passed] }
      failed = total - passed

      "Dependency validation: #{passed}/#{total} passed"
    end

    # Functional validation beyond version checking
    def self.validate_functionality
      validations = {}

      # Test git functionality
      validations[:git_functional] = test_git_functionality
      
      # Test claude-swarm functionality if available
      validations[:claude_swarm_functional] = test_claude_swarm_functionality

      validations
    end

    private

    def self.test_git_functionality
      begin
        # Test basic git operations
        CommandExecutor.execute('git', 'status', timeout: 5)
        CommandExecutor.execute('git', 'config', 'user.name', timeout: 5)
        { passed: true, error: nil }
      rescue CommandExecutor::CommandError => e
        { passed: false, error: "Git functionality test failed: #{e.message}" }
      end
    end

    def self.test_claude_swarm_functionality
      begin
        # Test claude-swarm basic command
        CommandExecutor.execute('claude-swarm', 'help', timeout: 10)
        { passed: true, error: nil }
      rescue CommandExecutor::CommandError => e
        { passed: false, error: "Claude-swarm functionality test failed: #{e.message}" }
      end
    end
  end
end