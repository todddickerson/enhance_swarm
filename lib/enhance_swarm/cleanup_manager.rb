# frozen_string_literal: true

require 'fileutils'
require_relative 'command_executor'
require_relative 'logger'

module EnhanceSwarm
  class CleanupManager
    CLEANUP_TIMEOUT = 30 # seconds

    def self.cleanup_failed_operation(operation_id, details = {})
      Logger.info("Starting cleanup for failed operation: #{operation_id}")
      
      cleanup_tasks = []
      
      # Cleanup git worktrees
      if details[:worktree_path]
        cleanup_tasks << -> { cleanup_worktree(details[:worktree_path]) }
      end
      
      # Cleanup git branches
      if details[:branch_name]
        cleanup_tasks << -> { cleanup_branch(details[:branch_name]) }
      end
      
      # Cleanup temporary files
      if details[:temp_files]
        cleanup_tasks << -> { cleanup_temp_files(details[:temp_files]) }
      end
      
      # Kill hanging processes
      if details[:process_pid]
        cleanup_tasks << -> { cleanup_process(details[:process_pid]) }
      end

      # Execute cleanup tasks with timeout protection
      cleanup_results = execute_cleanup_tasks(cleanup_tasks)
      
      Logger.log_operation("cleanup_#{operation_id}", 'completed', cleanup_results)
      cleanup_results
    end

    def self.cleanup_all_swarm_resources
      Logger.info("Starting comprehensive swarm resource cleanup")
      
      results = {
        worktrees: cleanup_swarm_worktrees,
        branches: cleanup_swarm_branches,
        processes: cleanup_swarm_processes,
        temp_files: cleanup_swarm_temp_files
      }
      
      Logger.log_operation('cleanup_all', 'completed', results)
      results
    end

    private

    def self.execute_cleanup_tasks(tasks)
      results = []
      
      tasks.each_with_index do |task, index|
        begin
          Timeout.timeout(CLEANUP_TIMEOUT) do
            result = task.call
            results << { task: index, status: 'success', result: result }
          end
        rescue Timeout::Error
          Logger.warn("Cleanup task #{index} timed out after #{CLEANUP_TIMEOUT}s")
          results << { task: index, status: 'timeout', error: 'Cleanup timed out' }
        rescue StandardError => e
          Logger.error("Cleanup task #{index} failed: #{e.message}")
          results << { task: index, status: 'failed', error: e.message }
        end
      end
      
      results
    end

    def self.cleanup_worktree(worktree_path)
      return { status: 'skipped', reason: 'Path not provided' } unless worktree_path
      
      begin
        if Dir.exist?(worktree_path)
          # Force remove worktree
          CommandExecutor.execute('git', 'worktree', 'remove', '--force', worktree_path)
          Logger.info("Removed worktree: #{worktree_path}")
          { status: 'success', path: worktree_path }
        else
          { status: 'not_found', path: worktree_path }
        end
      rescue CommandExecutor::CommandError => e
        Logger.error("Failed to cleanup worktree #{worktree_path}: #{e.message}")
        # Try manual cleanup if git command fails
        FileUtils.rm_rf(worktree_path) if Dir.exist?(worktree_path)
        { status: 'manual_cleanup', path: worktree_path, error: e.message }
      end
    end

    def self.cleanup_branch(branch_name)
      return { status: 'skipped', reason: 'Branch not provided' } unless branch_name
      
      begin
        # Check if branch exists
        CommandExecutor.execute('git', 'rev-parse', '--verify', branch_name)
        
        # Force delete branch
        CommandExecutor.execute('git', 'branch', '-D', branch_name)
        Logger.info("Deleted branch: #{branch_name}")
        { status: 'success', branch: branch_name }
      rescue CommandExecutor::CommandError => e
        if e.message.include?('does not exist')
          { status: 'not_found', branch: branch_name }
        else
          Logger.error("Failed to cleanup branch #{branch_name}: #{e.message}")
          { status: 'failed', branch: branch_name, error: e.message }
        end
      end
    end

    def self.cleanup_temp_files(file_patterns)
      return { status: 'skipped', reason: 'No patterns provided' } unless file_patterns
      
      cleaned_files = []
      file_patterns.each do |pattern|
        Dir.glob(pattern).each do |file|
          begin
            FileUtils.rm_f(file)
            cleaned_files << file
          rescue StandardError => e
            Logger.error("Failed to remove temp file #{file}: #{e.message}")
          end
        end
      end
      
      { status: 'success', files_removed: cleaned_files.size, files: cleaned_files }
    end

    def self.cleanup_process(pid)
      return { status: 'skipped', reason: 'No PID provided' } unless pid
      
      begin
        # Check if process exists
        Process.kill(0, pid.to_i)
        
        # Try graceful termination first
        Process.kill('TERM', pid.to_i)
        sleep(2)
        
        # Force kill if still running
        begin
          Process.kill(0, pid.to_i)
          Process.kill('KILL', pid.to_i)
          Logger.info("Force killed process: #{pid}")
          { status: 'force_killed', pid: pid }
        rescue Errno::ESRCH
          Logger.info("Process terminated gracefully: #{pid}")
          { status: 'terminated', pid: pid }
        end
      rescue Errno::ESRCH
        { status: 'not_found', pid: pid }
      rescue Errno::EPERM
        Logger.error("Permission denied killing process: #{pid}")
        { status: 'permission_denied', pid: pid }
      end
    end

    def self.cleanup_swarm_worktrees
      begin
        output = CommandExecutor.execute('git', 'worktree', 'list', '--porcelain')
        worktrees = parse_worktree_list(output)
        
        swarm_worktrees = worktrees.select { |wt| wt[:branch]&.start_with?('swarm/') }
        
        results = swarm_worktrees.map do |worktree|
          cleanup_worktree(worktree[:path])
        end
        
        { count: results.size, results: results }
      rescue CommandExecutor::CommandError => e
        Logger.error("Failed to list worktrees for cleanup: #{e.message}")
        { count: 0, error: e.message }
      end
    end

    def self.cleanup_swarm_branches
      begin
        output = CommandExecutor.execute('git', 'branch', '-a')
        branches = output.lines.map(&:strip).reject(&:empty?)
        
        swarm_branches = branches.select { |b| b.include?('swarm/') }
                                .map { |b| b.gsub(/^\*?\s*/, '').gsub(/^remotes\/origin\//, '') }
                                .uniq
        
        results = swarm_branches.map do |branch|
          cleanup_branch(branch)
        end
        
        { count: results.size, results: results }
      rescue CommandExecutor::CommandError => e
        Logger.error("Failed to list branches for cleanup: #{e.message}")
        { count: 0, error: e.message }
      end
    end

    def self.cleanup_swarm_processes
      # This is OS-specific and should be implemented based on requirements
      # For now, just return a placeholder
      { count: 0, message: 'Process cleanup not implemented for this platform' }
    end

    def self.cleanup_swarm_temp_files
      patterns = [
        '/tmp/enhance_swarm_*',
        '*.enhance_swarm.tmp',
        '.enhance_swarm.lock'
      ]
      
      cleanup_temp_files(patterns)
    end

    def self.parse_worktree_list(output)
      worktrees = []
      current_worktree = {}
      
      output.lines.each do |line|
        line = line.strip
        next if line.empty?
        
        case line
        when /^worktree (.+)$/
          worktrees << current_worktree unless current_worktree.empty?
          current_worktree = { path: $1 }
        when /^branch (.+)$/
          current_worktree[:branch] = $1.gsub(/^refs\/heads\//, '')
        when /^HEAD (.+)$/
          current_worktree[:head] = $1
        end
      end
      
      worktrees << current_worktree unless current_worktree.empty?
      worktrees
    end
  end
end