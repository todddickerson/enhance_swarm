# frozen_string_literal: true

require 'io/console'
require 'pty'

module EnhanceSwarm
  class OutputStreamer
    attr_reader :agent_outputs, :active_agents

    def initialize(max_lines: 10)
      @max_lines = max_lines
      @agent_outputs = {}
      @active_agents = {}
      @output_mutex = Mutex.new
      @display_thread = nil
      @running = false
    end

    def start_streaming
      @running = true
      @display_thread = Thread.new { display_loop }
    end

    def stop_streaming
      @running = false
      @display_thread&.join
      clear_display
    end

    def add_agent(agent_id, process_pid, role: 'agent')
      @output_mutex.synchronize do
        @active_agents[agent_id] = {
          pid: process_pid,
          role: role,
          start_time: Time.now,
          status: 'running'
        }
        @agent_outputs[agent_id] = {
          lines: [],
          last_update: Time.now
        }
      end
      
      # Start monitoring this agent's output (in real implementation)
      # start_agent_monitor(agent_id, process_pid)
    end

    def remove_agent(agent_id, status: 'completed')
      @output_mutex.synchronize do
        if @active_agents[agent_id]
          @active_agents[agent_id][:status] = status
          @active_agents[agent_id][:end_time] = Time.now
        end
      end
    end

    def add_output_line(agent_id, line)
      @output_mutex.synchronize do
        return unless @agent_outputs[agent_id]
        
        # Clean and format the line
        clean_line = clean_output_line(line)
        return if clean_line.empty?
        
        @agent_outputs[agent_id][:lines] << {
          text: clean_line,
          timestamp: Time.now
        }
        
        # Keep only recent lines
        if @agent_outputs[agent_id][:lines].length > @max_lines
          @agent_outputs[agent_id][:lines].shift
        end
        
        @agent_outputs[agent_id][:last_update] = Time.now
      end
    end

    private

    def display_loop
      while @running
        render_display
        sleep(0.1) # 10 FPS update rate
      end
    end

    def render_display
      @output_mutex.synchronize do
        clear_display
        
        # Show active agents summary
        puts build_agents_summary
        puts
        
        # Show live output for each agent
        @active_agents.each do |agent_id, agent_info|
          next unless agent_info[:status] == 'running'
          render_agent_output(agent_id, agent_info)
        end
        
        # Show completed agents summary
        completed = @active_agents.select { |_, info| info[:status] != 'running' }
        if completed.any?
          puts build_completed_summary(completed)
        end
      end
    end

    def build_agents_summary
      running = @active_agents.count { |_, info| info[:status] == 'running' }
      completed = @active_agents.count { |_, info| info[:status] == 'completed' }
      failed = @active_agents.count { |_, info| info[:status] == 'failed' }
      
      summary = "🤖 Agents: #{running} running"
      summary += ", #{completed} completed".colorize(:green) if completed > 0
      summary += ", #{failed} failed".colorize(:red) if failed > 0
      
      summary
    end

    def render_agent_output(agent_id, agent_info)
      role = agent_info[:role]
      elapsed = Time.now - agent_info[:start_time]
      
      # Agent header
      puts "┌─ #{role_icon(role)} #{role.upcase} Agent (#{format_duration(elapsed)}) #{agent_id[0..7]} ─".ljust(60, '─') + '┐'
      
      # Recent output lines
      output_data = @agent_outputs[agent_id]
      if output_data[:lines].any?
        output_data[:lines].last(@max_lines).each do |line_data|
          age = Time.now - line_data[:timestamp]
          age_indicator = age < 2 ? '●'.colorize(:green) : age < 10 ? '●'.colorize(:yellow) : '●'.colorize(:light_black)
          puts "│ #{age_indicator} #{line_data[:text].ljust(55)[0..55]} │"
        end
      else
        puts "│ #{' ' * 57} │"
        puts "│ #{'No output yet...'.colorize(:light_black).ljust(57)} │"
      end
      
      puts "└#{'─' * 58}┘"
      puts
    end

    def build_completed_summary(completed_agents)
      summary = "\n📋 Completed:"
      completed_agents.each do |agent_id, info|
        duration = info[:end_time] - info[:start_time]
        status_icon = info[:status] == 'completed' ? '✅' : '❌'
        summary += "\n  #{status_icon} #{info[:role]} (#{format_duration(duration)})"
      end
      summary
    end

    def start_agent_monitor(agent_id, process_pid)
      Thread.new do
        begin
          # Monitor the process output by tailing its log file or stdout
          # This is a simplified version - in reality you'd need to capture
          # the actual agent's stdout/stderr
          monitor_agent_process(agent_id, process_pid)
        rescue StandardError => e
          Logger.error("Failed to monitor agent #{agent_id}: #{e.message}")
        end
      end
    end

    def monitor_agent_process(agent_id, process_pid)
      # Check if process is still running
      loop do
        break unless process_running?(process_pid)
        
        # Try to read from agent's output (this would need actual implementation)
        # For now, simulate some output
        if rand < 0.3 # 30% chance of output per cycle
          simulate_agent_output(agent_id)
        end
        
        sleep(1)
      end
      
      # Process ended
      remove_agent(agent_id, status: 'completed')
    rescue StandardError => e
      remove_agent(agent_id, status: 'failed')
      add_output_line(agent_id, "❌ Agent failed: #{e.message}")
    end

    def process_running?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true # Process exists but we can't signal it
    end

    def simulate_agent_output(agent_id)
      # This simulates agent output - replace with actual output capture
      sample_outputs = [
        "🔍 Analyzing project structure...",
        "📁 Reading file: #{['app/models/user.rb', 'config/routes.rb', 'spec/models/user_spec.rb'].sample}",
        "✅ Found existing #{['authentication', 'user model', 'routes', 'tests'].sample}",
        "🔧 Generating #{['controller', 'migration', 'view', 'test'].sample}...",
        "📝 Writing #{['spec/requests/auth_spec.rb', 'app/controllers/sessions_controller.rb', 'app/views/sessions/new.html.erb'].sample}",
        "🏃 Running #{['rspec', 'rubocop', 'tests'].sample}...",
        "🎯 Implementing #{['login logic', 'validation', 'error handling'].sample}...",
        "🔒 Adding security #{['validations', 'sanitization', 'authentication'].sample}..."
      ]
      
      add_output_line(agent_id, sample_outputs.sample)
    end

    def clean_output_line(line)
      # Remove ANSI color codes and control characters
      line.to_s
          .gsub(/\e\[[0-9;]*m/, '') # Remove ANSI color codes
          .gsub(/\r\n?/, '') # Remove carriage returns
          .strip
          .slice(0, 55) # Limit length
    end

    def role_icon(role)
      icons = {
        'backend' => '🔧',
        'frontend' => '🎨', 
        'ux' => '✨',
        'qa' => '🧪',
        'general' => '🤖'
      }
      icons[role.to_s] || '🤖'
    end

    def format_duration(seconds)
      if seconds < 60
        "#{seconds.round}s"
      elsif seconds < 3600
        "#{(seconds / 60).round}m"
      else
        "#{(seconds / 3600).round(1)}h"
      end
    end

    def clear_display
      # Move cursor to top and clear screen
      print "\e[H\e[2J"
    end

    # Class methods for easy usage
    def self.stream_agents(agents)
      streamer = new
      
      begin
        streamer.start_streaming
        
        # Add all agents to streamer
        agents.each do |agent|
          streamer.add_agent(
            agent[:id] || "#{agent[:role]}-#{Time.now.to_i}",
            agent[:pid],
            role: agent[:role]
          )
        end
        
        # Wait for user interrupt or all agents to complete
        trap('INT') { streamer.stop_streaming; exit }
        
        loop do
          active_count = streamer.active_agents.count { |_, info| info[:status] == 'running' }
          break if active_count == 0
          
          sleep(1)
        end
        
      ensure
        streamer.stop_streaming
      end
    end
  end
end