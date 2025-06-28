# frozen_string_literal: true

require 'io/console'

module EnhanceSwarm
  class ProgressTracker
    attr_reader :current_step, :total_steps, :start_time, :estimated_tokens, :used_tokens

    def initialize(total_steps: 100, estimated_tokens: nil)
      @total_steps = total_steps
      @current_step = 0
      @start_time = Time.now
      @estimated_tokens = estimated_tokens
      @used_tokens = 0
      @last_update = Time.now
      @status_message = 'Initializing...'
      @details = {}
      @spinner_chars = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
      @spinner_index = 0
    end

    def advance(steps = 1, message: nil, details: {})
      @current_step = [@current_step + steps, @total_steps].min
      @status_message = message if message
      @details.merge!(details)
      update_display
    end

    def set_progress(step, message: nil, details: {})
      @current_step = [step, @total_steps].min
      @status_message = message if message
      @details.merge!(details)
      update_display
    end

    def add_tokens(count)
      @used_tokens += count
      update_display
    end

    def update_status(message, details: {})
      @status_message = message
      @details.merge!(details)
      update_display
    end

    def complete(message: 'Completed!')
      @current_step = @total_steps
      @status_message = message
      update_display
      puts # Final newline
    end

    def fail(message: 'Failed!')
      @status_message = message
      update_display
      puts # Final newline
    end

    private

    def update_display
      return if Time.now - @last_update < 0.1 # Limit update frequency
      
      @last_update = Time.now
      @spinner_index = (@spinner_index + 1) % @spinner_chars.length
      
      line = build_progress_line
      
      # Clear line and print new content
      print "\r\e[K#{line}"
      $stdout.flush
    end

    def build_progress_line
      spinner = @spinner_chars[@spinner_index]
      percentage = (@current_step.to_f / @total_steps * 100).round(1)
      elapsed = Time.now - @start_time
      
      # Progress bar
      bar_width = 20
      filled = (percentage / 100 * bar_width).round
      bar = '█' * filled + '░' * (bar_width - filled)
      
      # Time estimates
      time_info = build_time_info(elapsed, percentage)
      
      # Token info
      token_info = build_token_info
      
      # Details
      detail_info = build_detail_info
      
      "#{spinner} [#{bar}] #{percentage}% #{@status_message} #{time_info}#{token_info}#{detail_info}"
    end

    def build_time_info(elapsed, percentage)
      elapsed_str = format_duration(elapsed)
      
      if percentage > 5 && percentage < 100
        eta = (elapsed / percentage * 100) - elapsed
        eta_str = format_duration(eta)
        "(#{elapsed_str}/#{eta_str})"
      else
        "(#{elapsed_str})"
      end
    end

    def build_token_info
      return '' unless @estimated_tokens || @used_tokens > 0
      
      if @estimated_tokens
        token_percentage = (@used_tokens.to_f / @estimated_tokens * 100).round(1)
        " [#{@used_tokens}/#{@estimated_tokens} tokens (#{token_percentage}%)]"
      else
        " [#{@used_tokens} tokens]"
      end
    end

    def build_detail_info
      return '' if @details.empty?
      
      key_details = @details.slice(:agent, :worktree, :operation).compact
      return '' if key_details.empty?
      
      detail_str = key_details.map { |k, v| "#{k}: #{v}" }.join(', ')
      " - #{detail_str}"
    end

    def format_duration(seconds)
      if seconds < 60
        "#{seconds.round}s"
      elsif seconds < 3600
        minutes = (seconds / 60).round
        "#{minutes}m"
      else
        hours = (seconds / 3600).round(1)
        "#{hours}h"
      end
    end

    # Class methods for easy usage
    def self.track(total_steps: 100, estimated_tokens: nil)
      tracker = new(total_steps: total_steps, estimated_tokens: estimated_tokens)
      
      begin
        yield tracker
        tracker.complete
      rescue StandardError => e
        tracker.fail(message: "Error: #{e.message}")
        raise
      end
    end

    # Agent progress tracking
    def self.track_agent_operation(operation_name, estimated_steps: 10)
      tracker = new(total_steps: estimated_steps)
      tracker.update_status("#{operation_name}: Starting...")
      
      begin
        result = yield tracker
        tracker.complete(message: "#{operation_name}: Completed!")
        result
      rescue StandardError => e
        tracker.fail(message: "#{operation_name}: Failed - #{e.message}")
        raise
      end
    end

    # Multi-agent coordination
    def self.track_multi_agent(agents)
      total_steps = agents.count * 10 # Assume 10 steps per agent
      tracker = new(total_steps: total_steps)
      
      results = {}
      agents.each_with_index do |agent_config, index|
        agent_name = agent_config[:role] || "agent-#{index + 1}"
        
        tracker.update_status("Spawning #{agent_name}...", 
                            agent: agent_name,
                            operation: 'spawn')
        
        begin
          # This would be replaced with actual agent spawning
          result = yield agent_config, tracker, index
          results[agent_name] = result
          
          tracker.advance(10, 
                         message: "#{agent_name} completed",
                         agent: agent_name,
                         operation: 'completed')
        rescue StandardError => e
          tracker.fail(message: "#{agent_name} failed: #{e.message}")
          results[agent_name] = { error: e.message }
        end
      end
      
      tracker.complete(message: "All agents completed!")
      results
    end

    # Token estimation helpers
    def self.estimate_tokens_for_operation(operation_type)
      estimates = {
        'spawn_agent' => 500,
        'code_review' => 1000,
        'implementation' => 2000,
        'testing' => 800,
        'documentation' => 600
      }
      
      estimates[operation_type] || 1000
    end
  end
end