# frozen_string_literal: true

require 'singleton'
require 'colorize'
require 'json'

module EnhanceSwarm
  class VisualDashboard
    include Singleton

    def initialize
      @agents = {}
      @coordination_status = {}
      @dashboard_active = false
      @refresh_rate = 2 # seconds
      @last_update = Time.now
      @terminal_size = get_terminal_size
    end

    # Start the visual dashboard
    def start_dashboard(agents = [])
      @dashboard_active = true
      @agents = agents.each_with_object({}) { |agent, hash| hash[agent[:id]] = agent }
      
      puts "🖥️  Starting Visual Agent Dashboard...".colorize(:green)
      puts "Press 'q' to quit, 'r' to refresh, 'p' to pause".colorize(:light_black)
      
      setup_terminal
      display_loop
    end

    def stop_dashboard
      @dashboard_active = false
      restore_terminal
      puts "\n🖥️  Dashboard stopped".colorize(:yellow)
    end

    # Update agent status
    def update_agent(agent_id, updates)
      return unless @agents[agent_id]
      
      @agents[agent_id].merge!(updates)
      @last_update = Time.now
    end

    # Update coordination status
    def update_coordination(status)
      @coordination_status = status
      @last_update = Time.now
    end

    # Add new agent to dashboard
    def add_agent(agent)
      @agents[agent[:id]] = agent
      @last_update = Time.now
    end

    # Remove agent from dashboard
    def remove_agent(agent_id)
      @agents.delete(agent_id)
      @last_update = Time.now
    end

    # Display a static snapshot of agent status
    def display_snapshot(agents = [])
      @agents = agents.each_with_object({}) { |agent, hash| hash[agent[:id]] = agent }
      
      puts "📸 EnhanceSwarm Dashboard Snapshot".colorize(:cyan)
      puts "─" * 50
      puts "Timestamp: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      puts
      
      if @agents.empty?
        puts "No agents currently running".colorize(:light_black)
        return
      end
      
      puts "🤖 Agent Status:".colorize(:blue)
      @agents.each do |id, agent|
        role = agent[:role] || 'unknown'
        status = format_agent_status(agent)
        progress = agent[:progress_percentage] || agent[:progress] || 0
        duration = format_duration(agent)
        
        puts "  #{role.ljust(10)} │ #{status} │ #{progress}% │ #{duration}"
      end
      
      puts
      puts "System Resources:".colorize(:blue)
      memory_info = get_memory_info
      puts "  Memory: #{memory_info[:used_gb]}GB/#{memory_info[:total_gb]}GB (#{memory_info[:used_percent]}%)"
      puts "  Active Processes: #{@agents.count { |_, agent| agent[:pid] }}"
      
      puts "\n📊 Summary:".colorize(:green)
      puts "  Total Agents: #{@agents.count}"
      puts "  Active: #{@agents.count { |_, agent| agent[:status] == 'active' || agent[:status] == 'running' }}"
      puts "  Completed: #{@agents.count { |_, agent| agent[:status] == 'completed' }}"
      puts "  Failed: #{@agents.count { |_, agent| agent[:status] == 'failed' }}"
    end

    private

    def setup_terminal
      # Hide cursor and enable raw mode for input
      print "\e[?25l" # Hide cursor
      print "\e[2J"   # Clear screen
      print "\e[H"    # Move to top-left
    end

    def restore_terminal
      print "\e[?25h" # Show cursor
      print "\e[0m"   # Reset colors
    end

    def display_loop
      while @dashboard_active
        render_dashboard
        
        # Check for user input (non-blocking)
        if input_available?
          key = $stdin.getc
          handle_input(key)
        end
        
        sleep(@refresh_rate)
      end
    rescue Interrupt
      @dashboard_active = false
    ensure
      restore_terminal
    end

    def render_dashboard
      clear_screen
      
      # Header
      render_header
      
      # Coordination overview
      render_coordination_overview
      
      # Agent grid
      render_agent_grid
      
      # Status bar
      render_status_bar
      
      # Controls
      render_controls
    end

    def clear_screen
      print "\e[2J\e[H"
    end

    def render_header
      time_str = Time.now.strftime('%H:%M:%S')
      agent_count = @agents.count
      active_count = @agents.count { |_, agent| agent[:status] == 'active' }
      
      puts "┌─── 🖥️  EnhanceSwarm Visual Dashboard ─────────────────────────────────┐".colorize(:cyan)
      puts "│ #{time_str} │ Agents: #{agent_count} │ Active: #{active_count} │ Updated: #{time_ago(@last_update)} ago │".colorize(:white)
      puts "└────────────────────────────────────────────────────────────────────────┘".colorize(:cyan)
      puts
    end

    def render_coordination_overview
      puts "📊 Coordination Status".colorize(:blue)
      puts "─" * 40
      
      if @coordination_status.any?
        phase = @coordination_status[:phase] || 'Unknown'
        progress = @coordination_status[:progress] || 0
        active_agents = @coordination_status[:active_agents] || []
        completed_agents = @coordination_status[:completed_agents] || []
        
        puts "Phase: #{phase}".colorize(:yellow)
        puts "Progress: #{render_progress_bar(progress, 30)} #{progress}%"
        puts "Active: #{active_agents.join(', ')}" if active_agents.any?
        puts "Completed: #{completed_agents.join(', ')}" if completed_agents.any?
      else
        puts "No active coordination".colorize(:light_black)
      end
      
      puts
    end

    def render_agent_grid
      puts "🤖 Agent Status Grid".colorize(:blue)
      puts "─" * 60
      
      if @agents.empty?
        puts "No agents to display".colorize(:light_black)
        return
      end
      
      # Calculate grid layout
      terminal_width = @terminal_size[:width] || 80
      agent_width = 18
      cols = [terminal_width / agent_width, 1].max
      
      @agents.values.each_slice(cols) do |agent_row|
        render_agent_row(agent_row)
        puts
      end
    end

    def render_agent_row(agents)
      # Top border
      agents.each { print "┌────────────────┐ " }
      puts
      
      # Agent ID and role
      agents.each do |agent|
        role = (agent[:role] || 'unknown')[0..7].ljust(8)
        print "│ #{role}        │ "
      end
      puts
      
      # Status line
      agents.each do |agent|
        status = format_agent_status(agent)
        print "│ #{status.ljust(14)} │ "
      end
      puts
      
      # Progress line
      agents.each do |agent|
        progress = render_agent_progress(agent)
        print "│ #{progress} │ "
      end
      puts
      
      # Duration line
      agents.each do |agent|
        duration = format_duration(agent)
        print "│ #{duration.ljust(14)} │ "
      end
      puts
      
      # Bottom border
      agents.each { print "└────────────────┘ " }
      puts
    end

    def format_agent_status(agent)
      status = agent[:status] || 'unknown'
      
      case status
      when 'active'
        "🟢 Active".colorize(:green)
      when 'completed'
        "✅ Done".colorize(:green)
      when 'failed'
        "❌ Failed".colorize(:red)
      when 'stuck'
        "⚠️  Stuck".colorize(:yellow)
      when 'starting'
        "🔄 Starting".colorize(:blue)
      else
        "⚪ #{status.capitalize}".colorize(:light_black)
      end
    end

    def render_agent_progress(agent)
      if agent[:progress_percentage]
        percentage = agent[:progress_percentage].to_i
        bar = render_mini_progress_bar(percentage, 12)
        "#{bar} #{percentage}%"
      elsif agent[:current_task]
        task = agent[:current_task][0..11]
        task.ljust(14)
      else
        "              "
      end
    end

    def format_duration(agent)
      if agent[:start_time]
        duration = Time.now - Time.parse(agent[:start_time])
        format_time_duration(duration)
      else
        ""
      end
    end

    def render_status_bar
      puts "📈 System Resources".colorize(:blue)
      puts "─" * 30
      
      # Memory usage
      memory_info = get_memory_info
      puts "Memory: #{render_progress_bar(memory_info[:used_percent], 20)} #{memory_info[:used_gb]}GB/#{memory_info[:total_gb]}GB"
      
      # Active processes
      process_count = @agents.count { |_, agent| agent[:pid] }
      puts "Processes: #{process_count} active"
      
      # Communication queue
      if defined?(AgentCommunicator)
        pending_messages = AgentCommunicator.instance.pending_messages.count
        puts "Messages: #{pending_messages} pending"
      end
      
      puts
    end

    def render_controls
      puts "🎮 Controls".colorize(:blue)
      puts "─" * 15
      puts "[q] Quit  [r] Refresh  [p] Pause  [c] Clear  [h] Help"
    end

    def render_progress_bar(percentage, width)
      filled = (percentage * width / 100.0).round
      empty = width - filled
      
      bar = "█" * filled + "░" * empty
      case percentage
      when 0..30
        bar.colorize(:red)
      when 31..70
        bar.colorize(:yellow)
      else
        bar.colorize(:green)
      end
    end

    def render_mini_progress_bar(percentage, width)
      filled = (percentage * width / 100.0).round
      empty = width - filled
      
      "█" * filled + "░" * empty
    end

    def handle_input(key)
      case key.downcase
      when 'q'
        @dashboard_active = false
      when 'r'
        # Force refresh
        @last_update = Time.now
      when 'p'
        pause_dashboard
      when 'c'
        clear_screen
      when 'h'
        show_help
      when 's'
        save_dashboard_snapshot
      when 'd'
        show_detailed_view
      end
    end

    def pause_dashboard
      puts "\n⏸️  Dashboard paused. Press any key to continue...".colorize(:yellow)
      $stdin.getc
    end

    def show_help
      clear_screen
      puts "🖥️  EnhanceSwarm Dashboard Help".colorize(:cyan)
      puts "─" * 40
      puts
      puts "Controls:".colorize(:blue)
      puts "  q - Quit dashboard"
      puts "  r - Force refresh"
      puts "  p - Pause/resume"
      puts "  c - Clear screen"
      puts "  s - Save snapshot"
      puts "  d - Detailed view"
      puts "  h - Show this help"
      puts
      puts "Agent Status Icons:".colorize(:blue)
      puts "  🟢 Active   - Agent is working"
      puts "  ✅ Done     - Agent completed successfully"
      puts "  ❌ Failed   - Agent encountered an error"
      puts "  ⚠️  Stuck    - Agent appears stuck"
      puts "  🔄 Starting - Agent is initializing"
      puts
      puts "Press any key to return...".colorize(:light_black)
      $stdin.getc
    end

    def save_dashboard_snapshot
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filename = ".enhance_swarm/dashboard_snapshot_#{timestamp}.json"
      
      snapshot = {
        timestamp: Time.now.iso8601,
        agents: @agents,
        coordination: @coordination_status,
        system_info: get_system_snapshot
      }
      
      FileUtils.mkdir_p(File.dirname(filename))
      File.write(filename, JSON.pretty_generate(snapshot))
      
      flash_message("💾 Snapshot saved: #{filename}")
    end

    def show_detailed_view
      clear_screen
      puts "📋 Detailed Agent View".colorize(:cyan)
      puts "─" * 50
      
      @agents.each do |id, agent|
        puts "\n🤖 #{agent[:role] || 'Unknown'} (#{id})".colorize(:blue)
        puts "   Status: #{format_agent_status(agent)}"
        puts "   PID: #{agent[:pid] || 'N/A'}"
        puts "   Task: #{agent[:current_task] || 'N/A'}"
        puts "   Progress: #{agent[:progress_percentage] || 0}%"
        puts "   Duration: #{format_duration(agent)}"
        puts "   Memory: #{agent[:memory_mb] || 'N/A'}MB" if agent[:memory_mb]
        puts "   Output: #{agent[:output_path] || 'N/A'}" if agent[:output_path]
      end
      
      puts "\nPress any key to return...".colorize(:light_black)
      $stdin.getc
    end

    def flash_message(message)
      # Save current position and show message
      print "\e[s" # Save cursor position
      height = @terminal_size[:height] || 24
      print "\e[#{height - 2};1H" # Move to bottom
      print message.colorize(:green)
      sleep(2)
      print "\e[u" # Restore cursor position
    end

    def input_available?
      # Non-blocking input check
      ready = IO.select([$stdin], nil, nil, 0)
      ready && ready[0].include?($stdin)
    end

    def get_terminal_size
      begin
        stty_output = `stty size`.strip
        return { width: 80, height: 24 } if stty_output.empty?
        
        rows, cols = stty_output.split.map(&:to_i)
        return { width: 80, height: 24 } if rows == 0 || cols == 0
        
        { width: cols, height: rows }
      rescue
        { width: 80, height: 24 }
      end
    end

    def get_memory_info
      begin
        if RUBY_PLATFORM.include?('darwin') # macOS
          vm_stat = `vm_stat`
          page_size = 4096
          
          pages_free = vm_stat[/Pages free:\s+(\d+)/, 1].to_i
          pages_wired = vm_stat[/Pages wired down:\s+(\d+)/, 1].to_i
          pages_active = vm_stat[/Pages active:\s+(\d+)/, 1].to_i
          pages_inactive = vm_stat[/Pages inactive:\s+(\d+)/, 1].to_i
          
          total_pages = pages_free + pages_wired + pages_active + pages_inactive
          used_pages = total_pages - pages_free
          
          total_gb = (total_pages * page_size / 1024.0 / 1024.0 / 1024.0).round(1)
          used_gb = (used_pages * page_size / 1024.0 / 1024.0 / 1024.0).round(1)
          used_percent = ((used_pages.to_f / total_pages) * 100).round
          
          { total_gb: total_gb, used_gb: used_gb, used_percent: used_percent }
        else
          # Default fallback
          { total_gb: 8.0, used_gb: 4.0, used_percent: 50 }
        end
      rescue
        { total_gb: 8.0, used_gb: 4.0, used_percent: 50 }
      end
    end

    def get_system_snapshot
      {
        memory: get_memory_info,
        terminal_size: @terminal_size,
        ruby_version: RUBY_VERSION,
        platform: RUBY_PLATFORM,
        timestamp: Time.now.iso8601
      }
    end

    def time_ago(time)
      seconds = Time.now - time
      
      if seconds < 60
        "#{seconds.round}s"
      elsif seconds < 3600
        "#{(seconds / 60).round}m"
      else
        "#{(seconds / 3600).round}h"
      end
    end

    def format_time_duration(seconds)
      if seconds < 60
        "#{seconds.round}s"
      elsif seconds < 3600
        minutes = seconds / 60
        "#{minutes.round}m"
      else
        hours = seconds / 3600
        minutes = (seconds % 3600) / 60
        "#{hours.round}h#{minutes.round}m"
      end
    end

    # Class methods for singleton access
    class << self
      def instance
        @instance ||= new
      end

      def start_dashboard(*args)
        instance.start_dashboard(*args)
      end

      def stop_dashboard
        instance.stop_dashboard
      end

      def update_agent(*args)
        instance.update_agent(*args)
      end

      def update_coordination(*args)
        instance.update_coordination(*args)
      end

      def add_agent(*args)
        instance.add_agent(*args)
      end

      def remove_agent(*args)
        instance.remove_agent(*args)
      end
    end
  end
end