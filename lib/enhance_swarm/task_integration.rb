# frozen_string_literal: true

require_relative 'logger'

module EnhanceSwarm
  class TaskIntegration
    def initialize
      @tasks_available = check_swarm_tasks_availability
    end

    def swarm_tasks_available?
      @tasks_available
    end

    def list_tasks
      return [] unless @tasks_available

      begin
        output = `bundle exec swarm-tasks list --format=json 2>/dev/null`
        return [] if output.empty?

        JSON.parse(output)
      rescue JSON::ParserError, StandardError => e
        Logger.warn("Failed to parse swarm-tasks output: #{e.message}")
        []
      end
    end

    def get_active_tasks
      tasks = list_tasks
      tasks.select { |task| task['status'] == 'active' || task['status'] == 'in_progress' }
    end

    def move_task(task_id, status)
      return false unless @tasks_available

      begin
        result = `bundle exec swarm-tasks move #{task_id} #{status} 2>/dev/null`
        $?.success?
      rescue StandardError => e
        Logger.error("Failed to move task #{task_id} to #{status}: #{e.message}")
        false
      end
    end

    def create_task(title, description = nil, priority = 'medium')
      return false unless @tasks_available

      begin
        cmd = "bundle exec swarm-tasks create \"#{title}\""
        cmd += " --description=\"#{description}\"" if description
        cmd += " --priority=#{priority}"
        cmd += " 2>/dev/null"
        
        result = `#{cmd}`
        $?.success?
      rescue StandardError => e
        Logger.error("Failed to create task: #{e.message}")
        false
      end
    end

    def get_task_folders
      return [] unless @tasks_available

      begin
        # Look for tasks directory structure
        tasks_dir = File.join(Dir.pwd, 'tasks')
        return [] unless Dir.exist?(tasks_dir)

        folders = []
        Dir.glob(File.join(tasks_dir, '*')).each do |path|
          next unless File.directory?(path)
          
          folder_name = File.basename(path)
          task_files = Dir.glob(File.join(path, '*.md')).length
          
          folders << {
            name: folder_name,
            path: path,
            task_count: task_files,
            status: folder_name # todo, in_progress, done, etc.
          }
        end

        folders
      rescue StandardError => e
        Logger.warn("Failed to analyze task folders: #{e.message}")
        []
      end
    end

    def get_kanban_data
      {
        swarm_tasks_available: @tasks_available,
        tasks: list_tasks,
        folders: get_task_folders,
        active_tasks: get_active_tasks
      }
    end

    def setup_task_management
      return false unless @tasks_available

      begin
        # Initialize swarm-tasks if not already done
        unless Dir.exist?(File.join(Dir.pwd, 'tasks'))
          Logger.info("Initializing swarm-tasks for project")
          `bundle exec swarm-tasks init 2>/dev/null`
        end

        # Create default task categories if they don't exist
        default_folders = ['todo', 'in_progress', 'review', 'done']
        tasks_dir = File.join(Dir.pwd, 'tasks')
        
        default_folders.each do |folder|
          folder_path = File.join(tasks_dir, folder)
          unless Dir.exist?(folder_path)
            FileUtils.mkdir_p(folder_path)
            Logger.info("Created task folder: #{folder}")
          end
        end

        true
      rescue StandardError => e
        Logger.error("Failed to setup task management: #{e.message}")
        false
      end
    end

    private

    def check_swarm_tasks_availability
      begin
        # Check if swarm-tasks gem is available
        require 'swarm_tasks'
        
        # Check if swarm-tasks command is available
        result = `bundle exec swarm-tasks --version 2>/dev/null`
        $?.success?
      rescue LoadError
        Logger.warn("swarm-tasks gem not available - task management features limited")
        false
      rescue StandardError => e
        Logger.warn("swarm-tasks not accessible: #{e.message}")
        false
      end
    end
  end
end