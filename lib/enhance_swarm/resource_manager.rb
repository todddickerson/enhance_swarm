# frozen_string_literal: true

require_relative 'logger'
require_relative 'configuration'

module EnhanceSwarm
  # Manages system resources and enforces limits for agent spawning
  class ResourceManager
    MAX_CONCURRENT_AGENTS = 10
    MAX_MEMORY_MB = 2048
    MAX_DISK_MB = 1024

    def initialize
      @config = EnhanceSwarm.configuration
    end

    def can_spawn_agent?
      result = {
        allowed: true,
        reasons: []
      }

      # Check concurrent agent limit
      current_agents = count_active_agents
      max_agents = @config.max_concurrent_agents || MAX_CONCURRENT_AGENTS
      
      if current_agents >= max_agents
        result[:allowed] = false
        result[:reasons] << "Maximum concurrent agents reached (#{current_agents}/#{max_agents})"
      end

      # Check system memory
      if memory_usage_too_high?
        result[:allowed] = false
        result[:reasons] << "System memory usage too high"
      end

      # Check disk space
      if disk_usage_too_high?
        result[:allowed] = false
        result[:reasons] << "Insufficient disk space"
      end

      # Check system load
      if system_load_too_high?
        result[:allowed] = false
        result[:reasons] << "System load too high"
      end

      result
    end

    def get_resource_stats
      {
        active_agents: count_active_agents,
        max_agents: @config.max_concurrent_agents || MAX_CONCURRENT_AGENTS,
        memory_usage_mb: get_memory_usage_mb,
        disk_usage_mb: get_disk_usage_mb,
        system_load: get_system_load
      }
    end

    def enforce_limits!
      stats = get_resource_stats
      
      if stats[:active_agents] > stats[:max_agents]
        Logger.warn("Agent limit exceeded: #{stats[:active_agents]}/#{stats[:max_agents]}")
        cleanup_oldest_agents(stats[:active_agents] - stats[:max_agents])
      end
    end

    private

    def count_active_agents
      # Count running enhance-swarm processes
      begin
        ps_output = `ps aux | grep -i enhance-swarm | grep -v grep | wc -l`.strip.to_i
        # Subtract 1 for the current process
        [ps_output - 1, 0].max
      rescue StandardError
        0
      end
    end

    def memory_usage_too_high?
      current_usage = get_memory_usage_mb
      max_usage = @config.max_memory_mb || MAX_MEMORY_MB
      current_usage > max_usage
    end

    def disk_usage_too_high?
      current_usage = get_disk_usage_mb
      max_usage = @config.max_disk_mb || MAX_DISK_MB
      current_usage > max_usage
    end

    def system_load_too_high?
      load_avg = get_system_load
      # Consider load too high if 1-minute average > number of CPU cores
      cpu_count = get_cpu_count
      load_avg > cpu_count * 1.5
    end

    def get_memory_usage_mb
      begin
        # Get RSS memory usage of all enhance-swarm processes
        ps_output = `ps aux | grep -i enhance-swarm | grep -v grep | awk '{sum += $6} END {print sum}'`.strip.to_i
        # Convert from KB to MB
        ps_output / 1024
      rescue StandardError
        0
      end
    end

    def get_disk_usage_mb
      begin
        # Check disk usage of .enhance_swarm directory
        if Dir.exist?('.enhance_swarm')
          du_output = `du -sm .enhance_swarm 2>/dev/null | awk '{print $1}'`.strip.to_i
          return du_output
        end
        0
      rescue StandardError
        0
      end
    end

    def get_system_load
      begin
        # Get 1-minute load average
        uptime_output = `uptime`.strip
        load_match = uptime_output.match(/load averages?: ([\d.]+)/)
        load_match ? load_match[1].to_f : 0.0
      rescue StandardError
        0.0
      end
    end

    def get_cpu_count
      begin
        # Get number of CPU cores
        if RUBY_PLATFORM.include?('darwin') # macOS
          `sysctl -n hw.ncpu`.strip.to_i
        else # Linux
          `nproc`.strip.to_i
        end
      rescue StandardError
        4 # Default fallback
      end
    end

    def cleanup_oldest_agents(count)
      Logger.info("Cleaning up #{count} oldest agents to enforce limits")
      
      begin
        # Get list of enhance-swarm processes sorted by start time
        ps_output = `ps aux | grep -i enhance-swarm | grep -v grep | sort -k9`
        pids_to_kill = ps_output.lines.first(count).map do |line|
          line.split[1].to_i # Get PID
        end

        pids_to_kill.each do |pid|
          begin
            Process.kill('TERM', pid)
            Logger.info("Terminated agent process: #{pid}")
          rescue Errno::ESRCH
            # Process already terminated
          rescue StandardError => e
            Logger.error("Failed to terminate process #{pid}: #{e.message}")
          end
        end
      rescue StandardError => e
        Logger.error("Failed to cleanup agents: #{e.message}")
      end
    end
  end
end