# frozen_string_literal: true

require 'json'
require_relative 'command_executor'

module EnhanceSwarm
  class TaskManager
    def initialize
      @config = EnhanceSwarm.configuration
    end

    def next_priority_task
      # Try to use swarm-tasks if available
      if swarm_tasks_available?
        list_swarm_tasks('backlog').first
      else
        # Fallback to simple file-based tasks
        find_next_file_task
      end
    end

    def find_task(task_id)
      if swarm_tasks_available?
        show_swarm_task(task_id)
      else
        find_file_task(task_id)
      end
    end

    def move_task(task_id, state)
      if swarm_tasks_available?
        begin
          CommandExecutor.execute(@config.task_command, 'move', task_id.to_s, state.to_s)
        rescue CommandExecutor::CommandError => e
          puts "Failed to move task: #{e.message}".colorize(:red)
          false
        end
      else
        puts 'Task management not configured. Please set up swarm-tasks.'.colorize(:yellow)
        false
      end
    end

    def list_tasks(state = 'all')
      if swarm_tasks_available?
        list_swarm_tasks(state)
      else
        list_file_tasks(state)
      end
    end

    private

    def swarm_tasks_available?
      CommandExecutor.command_available?(@config.task_command.split.first)
    rescue CommandExecutor::CommandError
      false
    end

    def list_swarm_tasks(state)
      output = CommandExecutor.execute(@config.task_command, 'list', state, '--json')
      return [] if output.empty?

      tasks = JSON.parse(output)
      tasks.map do |task|
        {
          id: task['id'],
          title: task['title'] || task['content'],
          description: task['description'] || task['content'],
          state: task['state'] || task['status'],
          priority: task['priority'],
          effort: task['effort'],
          tags: task['tags'] || []
        }
      end
    rescue CommandExecutor::CommandError, JSON::ParserError
      []
    end

    def show_swarm_task(task_id)
      output = CommandExecutor.execute(@config.task_command, 'show', task_id.to_s, '--json')
      return nil if output.empty?

      task = JSON.parse(output)
      {
        id: task['id'],
        title: task['title'] || task['content'],
        description: task['description'] || task['content'],
        state: task['state'] || task['status'],
        priority: task['priority'],
        effort: task['effort'],
        tags: task['tags'] || []
      }
    rescue CommandExecutor::CommandError, JSON::ParserError
      nil
    end

    def find_next_file_task
      # Simple file-based task system fallback
      task_dir = File.join(EnhanceSwarm.root, 'tasks', 'backlog')
      return nil unless Dir.exist?(task_dir)

      task_files = Dir.glob(File.join(task_dir, '*.md')).sort
      return nil if task_files.empty?

      task_file = task_files.first
      content = File.read(task_file)

      {
        id: File.basename(task_file, '.md'),
        title: extract_title(content),
        description: content,
        state: 'backlog',
        priority: 'medium',
        effort: 4,
        tags: []
      }
    end

    def find_file_task(task_id)
      %w[backlog active completed].each do |state|
        task_file = File.join(EnhanceSwarm.root, 'tasks', state, "#{task_id}.md")
        next unless File.exist?(task_file)

        content = File.read(task_file)
        return {
          id: task_id,
          title: extract_title(content),
          description: content,
          state: state,
          priority: 'medium',
          effort: 4,
          tags: []
        }
      end
      nil
    end

    def list_file_tasks(state)
      tasks = []

      states = state == 'all' ? %w[backlog active completed] : [state]

      states.each do |s|
        task_dir = File.join(EnhanceSwarm.root, 'tasks', s)
        next unless Dir.exist?(task_dir)

        Dir.glob(File.join(task_dir, '*.md')).each do |file|
          content = File.read(file)
          tasks << {
            id: File.basename(file, '.md'),
            title: extract_title(content),
            description: content,
            state: s,
            priority: 'medium',
            effort: 4,
            tags: []
          }
        end
      end

      tasks
    end

    def extract_title(content)
      # Try to extract first heading or first line
      if (match = content.match(/^#\s+(.+)$/))
        match[1]
      else
        content.lines.first&.strip || 'Untitled Task'
      end
    end
  end
end
