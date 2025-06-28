# frozen_string_literal: true

require 'json'
require 'fileutils'

module EnhanceSwarm
  class AgentReviewer
    def self.review_all_work
      results = {
        timestamp: Time.now.iso8601,
        worktrees: [],
        completed_tasks: [],
        active_tasks: [],
        blocked_tasks: [],
        summary: {}
      }

      begin
        worktrees = list_swarm_worktrees
        Logger.info("Found #{worktrees.count} swarm worktrees to review")

        worktrees.each do |worktree|
          review = review_worktree(worktree)
          results[:worktrees] << review
          
          categorize_tasks(review, results)
        end

        results[:summary] = generate_summary(results)
        results
      rescue StandardError => e
        Logger.error("Failed to review agent work: #{e.message}")
        results[:error] = e.message
        results
      end
    end

    def self.list_swarm_worktrees
      output = CommandExecutor.execute('git', 'worktree', 'list', '--porcelain')
      worktrees = []
      current_worktree = {}

      output.split("\n").each do |line|
        case line
        when /^worktree (.+)/
          current_worktree[:path] = $1
        when /^branch (.+)/
          current_worktree[:branch] = $1
        when /^HEAD (.+)/
          current_worktree[:head] = $1
        when ''
          if current_worktree[:path]&.include?('swarm/')
            worktrees << current_worktree.dup
          end
          current_worktree.clear
        end
      end

      # Don't forget the last one
      if current_worktree[:path]&.include?('swarm/')
        worktrees << current_worktree
      end

      worktrees
    end

    def self.review_worktree(worktree)
      review = {
        path: worktree[:path],
        branch: worktree[:branch],
        last_activity: nil,
        status: 'unknown',
        files_changed: [],
        commits: [],
        task_progress: {},
        issues: []
      }

      begin
        Dir.chdir(worktree[:path]) do
          # Get last activity
          begin
            last_commit = CommandExecutor.execute('git', 'log', '-1', '--format=%ci')
            review[:last_activity] = Time.parse(last_commit.strip)
          rescue
            review[:last_activity] = File.mtime(worktree[:path])
          end

          # Check status
          git_status = CommandExecutor.execute('git', 'status', '--porcelain')
          review[:files_changed] = git_status.split("\n").map(&:strip).reject(&:empty?)
          
          # Get recent commits
          begin
            commits_output = CommandExecutor.execute('git', 'log', '--oneline', '-5')
            review[:commits] = commits_output.split("\n").map(&:strip).reject(&:empty?)
          rescue
            # No commits yet
          end

          # Determine status
          review[:status] = determine_worktree_status(review)
          
          # Check for issues
          review[:issues] = detect_issues(worktree[:path], review)
          
          # Look for task progress indicators
          review[:task_progress] = extract_task_progress(worktree[:path])
        end
      rescue StandardError => e
        review[:status] = 'error'
        review[:issues] << "Failed to review: #{e.message}"
      end

      review
    end

    def self.determine_worktree_status(review)
      return 'stale' if review[:last_activity] && review[:last_activity] < (Time.now - 3600) # 1 hour

      if review[:files_changed].any?
        'active'
      elsif review[:commits].any?
        'completed'
      else
        'initialized'
      end
    end

    def self.detect_issues(path, review)
      issues = []
      
      # Check for merge conflicts
      if review[:files_changed].any? { |f| f.start_with?('UU ') }
        issues << 'merge conflicts detected'
      end
      
      # Check for untracked important files
      untracked = review[:files_changed].select { |f| f.start_with?('?? ') }
      if untracked.any? { |f| f.include?('.rb') || f.include?('.js') || f.include?('.py') }
        issues << 'untracked source files'
      end

      # Check disk space
      begin
        stat = File.statvfs(path)
        free_gb = (stat.bavail * stat.frsize) / (1024 * 1024 * 1024)
        issues << "low disk space (#{free_gb}GB)" if free_gb < 1
      rescue
        # Not all platforms support statvfs
      end

      issues
    end

    def self.extract_task_progress(path)
      progress = {}
      
      # Look for task files
      task_files = Dir.glob(File.join(path, '.claude', 'tasks', '*.md'))
      task_files.each do |file|
        begin
          content = File.read(file)
          task_name = File.basename(file, '.md')
          
          # Simple progress extraction
          if content.include?('✅') || content.include?('completed')
            progress[task_name] = 'completed'
          elsif content.include?('🔄') || content.include?('in progress')
            progress[task_name] = 'in_progress'
          elsif content.include?('❌') || content.include?('blocked')
            progress[task_name] = 'blocked'
          else
            progress[task_name] = 'pending'
          end
        rescue
          # Ignore file read errors
        end
      end
      
      progress
    end

    def self.categorize_tasks(review, results)
      review[:task_progress].each do |task, status|
        task_info = {
          task: task,
          worktree: review[:path],
          branch: review[:branch],
          status: status,
          last_activity: review[:last_activity]
        }

        case status
        when 'completed'
          results[:completed_tasks] << task_info
        when 'in_progress'
          results[:active_tasks] << task_info
        when 'blocked'
          results[:blocked_tasks] << task_info
        end
      end
    end

    def self.generate_summary(results)
      {
        total_worktrees: results[:worktrees].count,
        active_worktrees: results[:worktrees].count { |w| w[:status] == 'active' },
        stale_worktrees: results[:worktrees].count { |w| w[:status] == 'stale' },
        completed_tasks: results[:completed_tasks].count,
        active_tasks: results[:active_tasks].count,
        blocked_tasks: results[:blocked_tasks].count,
        total_issues: results[:worktrees].sum { |w| w[:issues].count }
      }
    end

    def self.print_review_report(results)
      puts "=== Agent Work Review ==="
      puts "Time: #{Time.parse(results[:timestamp]).strftime('%Y-%m-%d %H:%M:%S')}"
      puts
      
      summary = results[:summary]
      puts "📊 Summary:"
      puts "  Total worktrees: #{summary[:total_worktrees]}"
      puts "  Active: #{summary[:active_worktrees]}".colorize(:green)
      puts "  Stale: #{summary[:stale_worktrees]}".colorize(:yellow)
      puts
      
      puts "📋 Tasks:"
      puts "  Completed: #{summary[:completed_tasks]}".colorize(:green)
      puts "  Active: #{summary[:active_tasks]}".colorize(:blue)
      puts "  Blocked: #{summary[:blocked_tasks]}".colorize(:red)
      puts

      if results[:completed_tasks].any?
        puts "✅ Recently Completed:"
        results[:completed_tasks].each do |task|
          puts "  #{task[:task]} (#{task[:worktree]})"
        end
        puts
      end

      if results[:active_tasks].any?
        puts "🔄 Currently Active:"
        results[:active_tasks].each do |task|
          age = Time.now - task[:last_activity]
          puts "  #{task[:task]} (#{format_duration(age)} ago)"
        end
        puts
      end

      if results[:blocked_tasks].any?
        puts "❌ Blocked Tasks:"
        results[:blocked_tasks].each do |task|
          puts "  #{task[:task]} (#{task[:worktree]})".colorize(:red)
        end
        puts
      end

      # Show issues
      issues = results[:worktrees].flat_map { |w| w[:issues] }
      if issues.any?
        puts "⚠️  Issues Found:"
        issues.each { |issue| puts "  - #{issue}".colorize(:yellow) }
        puts
      end

      if summary[:stale_worktrees] > 0
        puts "💡 Suggestion: Run 'enhance-swarm cleanup --all' to clean stale worktrees"
      end
    end

    def self.format_duration(seconds)
      if seconds < 60
        "#{seconds.to_i}s"
      elsif seconds < 3600
        "#{(seconds / 60).to_i}m"
      else
        "#{(seconds / 3600).to_i}h"
      end
    end
  end
end