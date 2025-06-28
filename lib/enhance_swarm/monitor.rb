# frozen_string_literal: true

require 'colorize'

module EnhanceSwarm
  class Monitor
    def initialize
      @config = EnhanceSwarm.configuration
    end
    
    def watch(interval: nil, timeout: nil)
      interval ||= @config.monitor_interval
      timeout ||= @config.monitor_timeout
      
      start_time = Time.now
      check_count = 0
      max_checks = timeout / interval
      
      puts "Monitoring swarm agents (max #{timeout}s)...".colorize(:yellow)
      
      loop do
        check_count += 1
        elapsed = Time.now - start_time
        
        # Check if we've exceeded timeout
        if elapsed > timeout
          puts "\n⏱️  Monitoring timeout reached. Agents continue in background.".colorize(:blue)
          break
        end
        
        # Get current status
        status = get_swarm_status
        
        # Display status
        puts "\n[Check #{check_count}/#{max_checks.to_i}] #{Time.now.strftime('%H:%M:%S')}".colorize(:gray)
        
        if status[:active].empty?
          puts "✅ All agents completed!".colorize(:green)
          show_completion_summary(status)
          break
        else
          puts "Active agents: #{status[:active].count}".colorize(:yellow)
          status[:active].each do |agent|
            puts "  - #{agent[:name]} (PID: #{agent[:pid]})".colorize(:yellow)
          end
        end
        
        # Show any completed agents
        if status[:completed].any?
          puts "Completed: #{status[:completed].count}".colorize(:green)
        end
        
        # Wait before next check
        sleep interval
      end
    end
    
    def status
      swarm_status = get_swarm_status
      worktrees = get_worktrees
      branches = get_recent_branches
      
      {
        active_agents: swarm_status[:active].count,
        completed_tasks: swarm_status[:completed].count,
        worktrees: worktrees,
        recent_branches: branches,
        raw_status: swarm_status
      }
    end
    
    private
    
    def get_swarm_status
      output = `claude-swarm ps 2>/dev/null`
      
      active = []
      completed = []
      
      return { active: active, completed: completed } if output.empty?
      
      # Parse the output (adjust based on actual claude-swarm output format)
      output.lines.each do |line|
        next if line.strip.empty?
        
        if line.include?("running")
          # Extract PID and name from line
          if match = line.match(/(\d+)\s+(\S+).*running/)
            active << { pid: match[1], name: match[2] }
          end
        elsif line.include?("completed")
          completed << line.strip
        end
      end
      
      { active: active, completed: completed }
    end
    
    def get_worktrees
      output = `git worktree list 2>/dev/null`
      return [] if output.empty?
      
      output.lines.map do |line|
        parts = line.split
        next if parts.empty?
        
        {
          path: parts[0],
          commit: parts[1],
          branch: parts[2]&.gsub(/[\[\]]/, '')
        }
      end.compact
    end
    
    def get_recent_branches
      output = `git branch -r 2>/dev/null | grep 'origin/swarm/' | tail -10`
      return [] if output.empty?
      
      output.lines.map(&:strip).map { |b| b.sub('origin/', '') }
    end
    
    def show_completion_summary(status)
      puts "\n📊 Completion Summary:".colorize(:green)
      puts "  Total completed: #{status[:completed].count}"
      
      # Check for new branches
      branches = get_recent_branches
      if branches.any?
        puts "\n📌 New branches created:".colorize(:blue)
        branches.each do |branch|
          puts "  - #{branch}"
        end
      end
      
      # Check for worktrees
      worktrees = get_worktrees
      if worktrees.any?
        puts "\n🌳 Active worktrees:".colorize(:blue)
        worktrees.each do |wt|
          puts "  - #{wt[:path]} (#{wt[:branch]})"
        end
      end
      
      puts "\n💡 Next steps:".colorize(:yellow)
      puts "  1. Review the completed work in each worktree"
      puts "  2. Merge approved changes"
      puts "  3. Clean up worktrees with: git worktree remove <path>"
      puts "  4. Mark task as completed"
    end
  end
end