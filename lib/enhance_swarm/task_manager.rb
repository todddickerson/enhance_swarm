# frozen_string_literal: true

require 'json'

module EnhanceSwarm
  class TaskManager
    def initialize
      @config = EnhanceSwarm.configuration
    end
    
    def next_priority_task
      # Try to use swarm-tasks if available
      if swarm_tasks_available?
        list_swarm_tasks("backlog").first
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
        system("#{@config.task_move_command} #{task_id} #{state}")
      else
        puts "Task management not configured. Please set up swarm-tasks.".colorize(:yellow)
      end
    end
    
    def list_tasks(state = "all")
      if swarm_tasks_available?
        list_swarm_tasks(state)
      else
        list_file_tasks(state)
      end
    end
    
    private
    
    def swarm_tasks_available?
      system("which #{@config.task_command.split.first} > /dev/null 2>&1")
    end
    
    def list_swarm_tasks(state)
      output = `#{@config.task_command} list #{state} --json 2>/dev/null`
      return [] if output.empty?
      
      begin
        tasks = JSON.parse(output)
        tasks.map do |task|
          {
            id: task["id"],
            title: task["title"] || task["content"],
            description: task["description"] || task["content"],
            state: task["state"] || task["status"],
            priority: task["priority"],
            effort: task["effort"],
            tags: task["tags"] || []
          }
        end
      rescue JSON::ParserError
        []
      end
    end
    
    def show_swarm_task(task_id)
      output = `#{@config.task_command} show #{task_id} --json 2>/dev/null`
      return nil if output.empty?
      
      begin
        task = JSON.parse(output)
        {
          id: task["id"],
          title: task["title"] || task["content"],
          description: task["description"] || task["content"],
          state: task["state"] || task["status"],
          priority: task["priority"],
          effort: task["effort"],
          tags: task["tags"] || []
        }
      rescue JSON::ParserError
        nil
      end
    end
    
    def find_next_file_task
      # Simple file-based task system fallback
      task_dir = File.join(EnhanceSwarm.root, "tasks", "backlog")
      return nil unless Dir.exist?(task_dir)
      
      task_files = Dir.glob(File.join(task_dir, "*.md")).sort
      return nil if task_files.empty?
      
      task_file = task_files.first
      content = File.read(task_file)
      
      {
        id: File.basename(task_file, ".md"),
        title: extract_title(content),
        description: content,
        state: "backlog",
        priority: "medium",
        effort: 4,
        tags: []
      }
    end
    
    def find_file_task(task_id)
      %w[backlog active completed].each do |state|
        task_file = File.join(EnhanceSwarm.root, "tasks", state, "#{task_id}.md")
        if File.exist?(task_file)
          content = File.read(task_file)
          return {
            id: task_id,
            title: extract_title(content),
            description: content,
            state: state,
            priority: "medium",
            effort: 4,
            tags: []
          }
        end
      end
      nil
    end
    
    def list_file_tasks(state)
      tasks = []
      
      states = state == "all" ? %w[backlog active completed] : [state]
      
      states.each do |s|
        task_dir = File.join(EnhanceSwarm.root, "tasks", s)
        next unless Dir.exist?(task_dir)
        
        Dir.glob(File.join(task_dir, "*.md")).each do |file|
          content = File.read(file)
          tasks << {
            id: File.basename(file, ".md"),
            title: extract_title(content),
            description: content,
            state: s,
            priority: "medium",
            effort: 4,
            tags: []
          }
        end
      end
      
      tasks
    end
    
    def extract_title(content)
      # Try to extract first heading or first line
      if match = content.match(/^#\s+(.+)$/)
        match[1]
      else
        content.lines.first&.strip || "Untitled Task"
      end
    end
  end
end