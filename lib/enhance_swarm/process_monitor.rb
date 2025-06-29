# frozen_string_literal: true

require 'colorize'
require_relative 'session_manager'
require_relative 'logger'

module EnhanceSwarm
  class ProcessMonitor
    def initialize
      @session_manager = SessionManager.new
    end

    def status
      session_status = @session_manager.session_status
      
      unless session_status[:exists]
        return {
          session_exists: false,
          active_agents: 0,
          total_agents: 0,
          message: 'No active session found'
        }
      end

      # Check and update process statuses
      active_agents = @session_manager.check_agent_processes
      all_agents = @session_manager.get_all_agents

      {
        session_exists: true,
        session_id: session_status[:session_id],
        start_time: session_status[:start_time],
        task_description: session_status[:task_description],
        active_agents: active_agents.length,
        total_agents: all_agents.length,
        completed_agents: all_agents.count { |a| a[:status] == 'completed' },
        failed_agents: all_agents.count { |a| a[:status] == 'failed' },
        stopped_agents: all_agents.count { |a| a[:status] == 'stopped' },
        agents: all_agents,
        active_agent_details: active_agents
      }
    end

    def display_status
      status_data = status

      unless status_data[:session_exists]
        puts "📊 No active enhance-swarm session found".colorize(:yellow)
        puts "   Run 'enhance-swarm enhance' to start a new session"
        return
      end

      puts "📊 EnhanceSwarm Session Status".colorize(:blue)
      puts "=" * 50

      # Session info
      puts "\n🎯 Session: #{status_data[:session_id]}".colorize(:green)
      puts "   Started: #{format_time(status_data[:start_time])}"
      puts "   Task: #{status_data[:task_description] || 'No description'}" if status_data[:task_description]

      # Agent summary
      puts "\n📈 Agents Summary:".colorize(:blue)
      puts "   Total: #{status_data[:total_agents]}"
      puts "   Active: #{status_data[:active_agents]}".colorize(:green)
      puts "   Completed: #{status_data[:completed_agents]}".colorize(:green)
      puts "   Stopped: #{status_data[:stopped_agents]}".colorize(:yellow)
      puts "   Failed: #{status_data[:failed_agents]}".colorize(:red) if status_data[:failed_agents] > 0

      # Active agents details
      if status_data[:active_agents] > 0
        puts "\n🤖 Active Agents:".colorize(:yellow)
        status_data[:active_agent_details].each do |agent|
          runtime = calculate_runtime(agent[:start_time])
          puts "   #{agent[:role].upcase.ljust(8)} PID: #{agent[:pid].to_s.ljust(6)} Runtime: #{runtime}".colorize(:yellow)
          puts "   #{' ' * 10} Worktree: #{agent[:worktree_path]}" if agent[:worktree_path]
        end
      end

      # All agents table if requested or if there are completed/failed agents
      if status_data[:total_agents] > status_data[:active_agents]
        puts "\n📋 All Agents:".colorize(:blue)
        display_agents_table(status_data[:agents])
      end

      # Git worktrees
      display_worktree_status

      puts ""
    end

    def display_agents_table(agents)
      return if agents.empty?

      # Table headers
      printf "   %-10s %-8s %-12s %-10s %s\n", "ROLE", "PID", "STATUS", "RUNTIME", "WORKTREE"
      puts "   " + "-" * 70

      agents.each do |agent|
        runtime = calculate_runtime(agent[:start_time], agent[:completion_time])
        worktree = agent[:worktree_path] ? File.basename(agent[:worktree_path]) : 'none'
        
        status_color = case agent[:status]
                      when 'running' then :green
                      when 'completed' then :blue
                      when 'failed' then :red
                      when 'stopped' then :yellow
                      else :white
                      end

        role = agent[:role].upcase.ljust(10)
        pid = agent[:pid].to_s.ljust(8)
        status = agent[:status].ljust(12)
        
        printf "   %-10s %-8s ", role, pid
        print status.colorize(status_color)
        printf " %-10s %s\n", runtime, worktree
      end
    end

    def display_worktree_status
      begin
        worktrees = get_git_worktrees
        enhance_worktrees = worktrees.select { |wt| wt[:path].include?('.enhance_swarm/worktrees') }
        
        if enhance_worktrees.any?
          puts "\n🌳 Git Worktrees:".colorize(:blue)
          enhance_worktrees.each do |worktree|
            branch = worktree[:branch] || 'detached'
            puts "   #{File.basename(worktree[:path]).ljust(20)} #{branch}".colorize(:cyan)
          end
        end
      rescue StandardError => e
        Logger.warn("Could not get worktree status: #{e.message}")
      end
    end

    def watch(interval: 5, timeout: nil)
      start_time = Time.now
      check_count = 0

      puts "🔍 Watching enhance-swarm agents (Ctrl+C to stop)...".colorize(:yellow)
      puts ""

      begin
        loop do
          check_count += 1
          elapsed = Time.now - start_time

          # Check timeout
          if timeout && elapsed > timeout
            puts "\n⏱️  Watch timeout reached (#{timeout}s)".colorize(:blue)
            break
          end

          # Clear screen and show status
          system('clear') || system('cls')
          
          puts "[Check #{check_count}] #{Time.now.strftime('%H:%M:%S')} (#{elapsed.round}s elapsed)".colorize(:gray)
          display_status

          # Check if all agents completed
          status_data = status
          if status_data[:session_exists] && status_data[:active_agents] == 0 && status_data[:total_agents] > 0
            puts "✅ All agents completed!".colorize(:green)
            break
          end

          sleep interval
        end
      rescue Interrupt
        puts "\n\n👋 Watch stopped by user".colorize(:yellow)
      end
    end

    def cleanup_completed_agents
      all_agents = @session_manager.get_all_agents
      completed_agents = all_agents.select { |a| a[:status] == 'completed' }
      
      cleanup_count = 0
      completed_agents.each do |agent|
        if cleanup_agent_worktree(agent[:worktree_path])
          @session_manager.remove_agent(agent[:pid])
          cleanup_count += 1
        end
      end

      if cleanup_count > 0
        puts "🧹 Cleaned up #{cleanup_count} completed agents".colorize(:green)
      end

      cleanup_count
    end

    private

    def format_time(time_string)
      return 'unknown' unless time_string

      begin
        Time.parse(time_string).strftime('%Y-%m-%d %H:%M:%S')
      rescue StandardError
        time_string
      end
    end

    def calculate_runtime(start_time, end_time = nil)
      return 'unknown' unless start_time

      begin
        start = Time.parse(start_time)
        finish = end_time ? Time.parse(end_time) : Time.now
        
        duration = finish - start
        format_duration(duration)
      rescue StandardError
        'unknown'
      end
    end

    def format_duration(seconds)
      return '0s' if seconds <= 0

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

    def get_git_worktrees
      output = `git worktree list 2>/dev/null`
      return [] if output.empty?

      output.lines.map do |line|
        parts = line.strip.split
        next if parts.empty?

        {
          path: parts[0],
          commit: parts[1],
          branch: parts[2]&.gsub(/[\[\]]/, '')
        }
      end.compact
    rescue StandardError
      []
    end

    def cleanup_agent_worktree(worktree_path)
      return false unless worktree_path && Dir.exist?(worktree_path)

      begin
        # Remove git worktree
        `git worktree remove --force "#{worktree_path}" 2>/dev/null`
        Logger.info("Cleaned up worktree: #{worktree_path}")
        true
      rescue StandardError => e
        Logger.warn("Failed to cleanup worktree #{worktree_path}: #{e.message}")
        false
      end
    end
  end
end