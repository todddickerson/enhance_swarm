# frozen_string_literal: true

require 'singleton'
require 'yaml'
require 'json'

module EnhanceSwarm
  class SmartDefaults
    include Singleton

    DEFAULT_SETTINGS_FILE = '.enhance_swarm/smart_defaults.yml'
    USER_PATTERNS_FILE = '.enhance_swarm/user_patterns.json'
    
    def initialize
      @settings = load_settings
      @user_patterns = load_user_patterns
      @project_context = analyze_project_context
      ensure_settings_directory
    end

    # Detect optimal role for a given task
    def suggest_role_for_task(task_description)
      task_lower = task_description.downcase
      
      # Check for explicit role keywords
      role_keywords = {
        'backend' => %w[api server database model migration schema endpoint route controller service auth jwt],
        'frontend' => %w[ui ux component view page template css html javascript react vue angular design layout],
        'qa' => %w[test testing spec unit integration e2e selenium cypress jest rspec quality assurance bug],
        'ux' => %w[design user experience wireframe mockup prototype accessibility usability flow journey]
      }
      
      # Calculate keyword matches for each role
      role_scores = role_keywords.transform_values do |keywords|
        keywords.count { |keyword| task_lower.include?(keyword) }
      end
      
      # Add context from user patterns
      if @user_patterns['role_preferences']
        @user_patterns['role_preferences'].each do |role, weight|
          role_scores[role] = (role_scores[role] || 0) + weight.to_f
        end
      end
      
      # Return the role with highest score, or 'general' if tied
      best_role = role_scores.max_by { |_, score| score }
      best_role && best_role[1] > 0 ? best_role[0] : 'general'
    end

    # Suggest optimal configuration based on project type
    def suggest_configuration
      config = {}
      
      # Detect project type and suggest stack
      project_type = detect_project_type
      config[:project_type] = project_type
      config[:technology_stack] = suggest_technology_stack(project_type)
      
      # Suggest commands based on project files
      config[:commands] = suggest_commands(project_type)
      
      # Suggest orchestration settings
      config[:orchestration] = suggest_orchestration_settings
      
      # Add MCP tool suggestions
      config[:mcp_tools] = suggest_mcp_tools(project_type)
      
      config
    end

    # Auto-retry with intelligent backoff
    def auto_retry_with_backoff(operation, max_retries: 3, base_delay: 1)
      attempt = 0
      last_error = nil
      
      loop do
        attempt += 1
        
        begin
          result = yield
          
          # Record successful pattern
          record_success_pattern(operation, attempt)
          return result
          
        rescue StandardError => e
          last_error = e
          
          if attempt >= max_retries
            record_failure_pattern(operation, attempt, e)
            raise e
          end
          
          # Calculate exponential backoff with jitter
          delay = base_delay * (2 ** (attempt - 1)) + rand(0.5)
          delay = [delay, 30].min # Cap at 30 seconds
          
          Logger.info("Retry #{attempt}/#{max_retries} for #{operation} in #{delay.round(1)}s: #{e.message}")
          sleep(delay)
        end
      end
    end

    # Suggest next actions based on current state
    def suggest_next_actions(current_context = {})
      suggestions = []
      
      # Check for common issues and suggest fixes
      if stale_worktrees_detected?
        suggestions << {
          action: 'cleanup',
          command: 'enhance-swarm cleanup --all',
          reason: 'Stale worktrees detected',
          priority: :medium
        }
      end
      
      if pending_agent_messages?
        suggestions << {
          action: 'communicate',
          command: 'enhance-swarm communicate --interactive',
          reason: 'Pending agent messages need responses',
          priority: :high
        }
      end
      
      # Suggest based on project state
      if tests_need_running?
        suggestions << {
          action: 'test',
          command: determine_test_command,
          reason: 'Code changes detected, tests should be run',
          priority: :medium
        }
      end
      
      # Suggest based on user patterns
      time_based_suggestions.each { |suggestion| suggestions << suggestion }
      
      suggestions.sort_by { |s| priority_weight(s[:priority]) }.reverse
    end

    # Auto-cleanup stale resources
    def auto_cleanup_if_needed
      cleanup_actions = []
      
      # Check for stale worktrees (older than 1 day)
      stale_worktrees = find_stale_worktrees
      if stale_worktrees.count > 3
        cleanup_actions << proc do
          CleanupManager.cleanup_stale_worktrees
          Logger.info("Auto-cleaned #{stale_worktrees.count} stale worktrees")
        end
      end
      
      # Check for old communication files (older than 7 days)
      old_comm_files = find_old_communication_files
      if old_comm_files.count > 20
        cleanup_actions << proc do
          AgentCommunicator.instance.cleanup_old_messages(7)
          Logger.info("Auto-cleaned #{old_comm_files.count} old communication files")
        end
      end
      
      # Check for old notification history (older than 14 days)
      if notification_history_size > 100
        cleanup_actions << proc do
          NotificationManager.instance.clear_history
          Logger.info("Auto-cleaned notification history")
        end
      end
      
      # Execute cleanup actions
      cleanup_actions.each(&:call)
      
      cleanup_actions.count
    end

    # Learn from user actions and update patterns
    def learn_from_action(action_type, details = {})
      @user_patterns['actions'] ||= {}
      @user_patterns['actions'][action_type] ||= {
        'count' => 0,
        'last_used' => nil,
        'success_rate' => 1.0,
        'preferences' => {}
      }
      
      action_data = @user_patterns['actions'][action_type]
      action_data['count'] += 1
      action_data['last_used'] = Time.now.iso8601
      
      # Update preferences based on details
      details.each do |key, value|
        action_data['preferences'][key.to_s] ||= {}
        action_data['preferences'][key.to_s][value.to_s] ||= 0
        action_data['preferences'][key.to_s][value.to_s] += 1
      end
      
      save_user_patterns
    end

    # Get context-aware command suggestions
    def suggest_commands_for_context(context = {})
      suggestions = []
      
      # Based on current directory contents
      if File.exist?('package.json')
        suggestions << 'npm test' if context[:changed_files]&.any? { |f| f.end_with?('.js', '.ts') }
        suggestions << 'npm run build' if context[:action] == 'deploy'
      end
      
      if File.exist?('Gemfile')
        suggestions << 'bundle exec rspec' if context[:changed_files]&.any? { |f| f.end_with?('.rb') }
        suggestions << 'bundle exec rubocop' if context[:action] == 'lint'
      end
      
      # Based on git status
      if context[:git_status]
        if context[:git_status][:modified_files] && context[:git_status][:modified_files] > 0
          suggestions << 'enhance-swarm review'
        end
        
        if context[:git_status][:untracked_files] && context[:git_status][:untracked_files] > 0
          suggestions << 'git add .'
        end
      end
      
      # Based on user patterns
      frequent_commands.each { |cmd| suggestions << cmd }
      
      suggestions.uniq
    end

    # Auto-detect optimal concurrency settings
    def suggest_concurrency_settings
      # Base on system resources
      cpu_cores = detect_cpu_cores
      available_memory_gb = detect_available_memory
      
      # Conservative defaults
      max_agents = [cpu_cores / 2, 4].min
      max_agents = [max_agents, 2].max # At least 2
      
      # Adjust based on memory
      if available_memory_gb < 4
        max_agents = [max_agents, 2].min
      elsif available_memory_gb > 16
        max_agents = [max_agents + 2, 8].min
      end
      
      {
        max_concurrent_agents: max_agents,
        monitor_interval: max_agents > 4 ? 15 : 30,
        timeout_multiplier: available_memory_gb < 8 ? 1.5 : 1.0
      }
    end

    private

    def load_settings
      return default_settings unless File.exist?(DEFAULT_SETTINGS_FILE)
      
      YAML.load_file(DEFAULT_SETTINGS_FILE)
    rescue StandardError
      default_settings
    end

    def load_user_patterns
      return {} unless File.exist?(USER_PATTERNS_FILE)
      
      JSON.parse(File.read(USER_PATTERNS_FILE))
    rescue StandardError
      {}
    end

    def save_user_patterns
      ensure_settings_directory
      File.write(USER_PATTERNS_FILE, JSON.pretty_generate(@user_patterns))
    end

    def ensure_settings_directory
      dir = File.dirname(DEFAULT_SETTINGS_FILE)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end

    def default_settings
      {
        'auto_cleanup' => true,
        'auto_retry' => true,
        'smart_suggestions' => true,
        'learning_enabled' => true,
        'cleanup_threshold_days' => 7
      }
    end

    def analyze_project_context
      context = {}
      
      # Git information
      if Dir.exist?('.git')
        context[:git] = {
          branch: `git branch --show-current`.strip,
          status: git_status_summary,
          recent_commits: recent_commit_count
        }
      end
      
      # Project files
      context[:files] = {
        package_json: File.exist?('package.json'),
        gemfile: File.exist?('Gemfile'),
        dockerfile: File.exist?('Dockerfile'),
        config_files: Dir.glob('*.{yml,yaml,json,toml}').count
      }
      
      # Directory structure
      context[:structure] = {
        src_dirs: Dir.glob('{src,lib,app}').count,
        test_dirs: Dir.glob('{test,spec,__tests__}').count,
        has_nested_structure: Dir.glob('*/*').count > 10
      }
      
      context
    end

    def detect_project_type
      return 'rails' if File.exist?('Gemfile') && File.exist?('config/application.rb')
      return 'node' if File.exist?('package.json')
      return 'python' if File.exist?('requirements.txt') || File.exist?('pyproject.toml')
      return 'docker' if File.exist?('Dockerfile')
      return 'static' if Dir.glob('*.html').any?
      
      'general'
    end

    def suggest_technology_stack(project_type)
      case project_type
      when 'rails'
        ['Ruby on Rails', 'PostgreSQL', 'Redis', 'Sidekiq']
      when 'node'
        detect_node_stack
      when 'python'
        detect_python_stack
      when 'docker'
        ['Docker', 'Docker Compose']
      else
        []
      end
    end

    def detect_node_stack
      stack = ['Node.js']
      
      if File.exist?('package.json')
        package_json = JSON.parse(File.read('package.json'))
        deps = package_json['dependencies'] || {}
        dev_deps = package_json['devDependencies'] || {}
        all_deps = deps.merge(dev_deps)
        
        stack << 'React' if all_deps.key?('react')
        stack << 'Vue.js' if all_deps.key?('vue')
        stack << 'Angular' if all_deps.key?('@angular/core')
        stack << 'Express' if all_deps.key?('express')
        stack << 'TypeScript' if all_deps.key?('typescript')
        stack << 'Webpack' if all_deps.key?('webpack')
        stack << 'Jest' if all_deps.key?('jest')
      end
      
      stack
    end

    def detect_python_stack
      stack = ['Python']
      
      requirements_files = ['requirements.txt', 'pyproject.toml', 'Pipfile']
      req_content = ''
      
      requirements_files.each do |file|
        if File.exist?(file)
          req_content += File.read(file).downcase
        end
      end
      
      stack << 'Django' if req_content.include?('django')
      stack << 'Flask' if req_content.include?('flask')
      stack << 'FastAPI' if req_content.include?('fastapi')
      stack << 'SQLAlchemy' if req_content.include?('sqlalchemy')
      stack << 'PostgreSQL' if req_content.include?('psycopg')
      stack << 'Redis' if req_content.include?('redis')
      
      stack
    end

    def suggest_commands(project_type)
      commands = {}
      
      case project_type
      when 'rails'
        commands = {
          'test' => 'bundle exec rspec',
          'lint' => 'bundle exec rubocop',
          'migrate' => 'bundle exec rails db:migrate',
          'console' => 'bundle exec rails console'
        }
      when 'node'
        package_json = File.exist?('package.json') ? JSON.parse(File.read('package.json')) : {}
        scripts = package_json['scripts'] || {}
        
        commands['test'] = scripts['test'] || 'npm test'
        commands['build'] = scripts['build'] || 'npm run build'
        commands['start'] = scripts['start'] || 'npm start'
        commands['lint'] = scripts['lint'] || 'npm run lint'
      when 'python'
        commands = {
          'test' => 'pytest',
          'lint' => 'flake8 .',
          'format' => 'black .',
          'install' => 'pip install -r requirements.txt'
        }
      end
      
      commands
    end

    def suggest_orchestration_settings
      concurrency = suggest_concurrency_settings
      
      {
        'max_concurrent_agents' => concurrency[:max_concurrent_agents],
        'monitor_interval' => concurrency[:monitor_interval],
        'timeout_per_agent' => 300,
        'auto_cleanup' => true
      }
    end

    def suggest_mcp_tools(project_type)
      tools = {
        'desktop_commander' => false,
        'gemini_cli' => true
      }
      
      # Enable specific tools based on project type
      case project_type
      when 'rails', 'node', 'python'
        tools['gemini_cli'] = true # Good for large codebases
      when 'docker'
        tools['desktop_commander'] = true # May need system operations
      end
      
      tools
    end

    def stale_worktrees_detected?
      find_stale_worktrees.count > 2
    end

    def find_stale_worktrees
      return [] unless Dir.exist?('.git')
      
      begin
        worktree_output = `git worktree list 2>/dev/null`
        stale_worktrees = []
        
        worktree_output.lines.each do |line|
          next unless line.include?('swarm/')
          
          parts = line.split
          path = parts[0]
          
          if Dir.exist?(path)
            # Check if worktree is old (no activity in 24 hours)
            last_modified = Dir.glob(File.join(path, '**/*')).map { |f| File.mtime(f) rescue Time.now }.max
            if last_modified && (Time.now - last_modified) > 86400 # 24 hours
              stale_worktrees << path
            end
          else
            stale_worktrees << path # Broken worktree reference
          end
        end
        
        stale_worktrees
      rescue StandardError
        []
      end
    end

    def pending_agent_messages?
      return false unless defined?(AgentCommunicator)
      
      AgentCommunicator.instance.pending_messages.any?
    end

    def tests_need_running?
      return false unless @project_context[:git]
      
      # Check if there are unstaged changes in source files
      status = `git status --porcelain`.lines
      source_files_changed = status.any? do |line|
        file = line[3..-1]&.strip
        file&.match?(/\.(rb|js|ts|py|java|go|rs)$/)
      end
      
      source_files_changed
    end

    def determine_test_command
      project_type = detect_project_type
      
      case project_type
      when 'rails' then 'bundle exec rspec'
      when 'node' then 'npm test'
      when 'python' then 'pytest'
      else 'echo "No test command configured"'
      end
    end

    def time_based_suggestions
      suggestions = []
      current_hour = Time.now.hour
      
      # Morning suggestions (8-10 AM)
      if current_hour.between?(8, 10)
        suggestions << {
          action: 'status',
          command: 'enhance-swarm status',
          reason: 'Morning status check',
          priority: :low
        }
      end
      
      # End of day suggestions (5-7 PM)
      if current_hour.between?(17, 19)
        suggestions << {
          action: 'cleanup',
          command: 'enhance-swarm cleanup --all',
          reason: 'End of day cleanup',
          priority: :low
        }
      end
      
      suggestions
    end

    def priority_weight(priority)
      case priority
      when :critical then 4
      when :high then 3
      when :medium then 2
      when :low then 1
      else 0
      end
    end

    def find_old_communication_files
      comm_dir = '.enhance_swarm/communication'
      return [] unless Dir.exist?(comm_dir)
      
      cutoff = Time.now - (7 * 24 * 60 * 60) # 7 days ago
      
      Dir.glob(File.join(comm_dir, '*.json')).select do |file|
        File.mtime(file) < cutoff
      end
    end

    def notification_history_size
      return 0 unless defined?(NotificationManager)
      
      NotificationManager.instance.recent_notifications(1000).count
    end

    def frequent_commands
      return [] unless @user_patterns['actions']
      
      @user_patterns['actions']
        .select { |_, data| data['count'] > 5 }
        .sort_by { |_, data| -data['count'] }
        .first(5)
        .map { |action, _| action }
    end

    def record_success_pattern(operation, attempt)
      @user_patterns['retry_patterns'] ||= {}
      @user_patterns['retry_patterns'][operation.to_s] ||= {
        'total_attempts' => 0,
        'success_attempts' => 0,
        'avg_attempts_to_success' => 1.0
      }
      
      pattern = @user_patterns['retry_patterns'][operation.to_s]
      pattern['total_attempts'] += attempt
      pattern['success_attempts'] += 1
      pattern['avg_attempts_to_success'] = pattern['total_attempts'].to_f / pattern['success_attempts']
      
      save_user_patterns
    end

    def record_failure_pattern(operation, attempt, error)
      @user_patterns['failure_patterns'] ||= {}
      @user_patterns['failure_patterns'][operation.to_s] ||= {
        'count' => 0,
        'last_error' => nil,
        'common_errors' => {}
      }
      
      pattern = @user_patterns['failure_patterns'][operation.to_s]
      pattern['count'] += 1
      pattern['last_error'] = error.message
      pattern['common_errors'][error.class.name] ||= 0
      pattern['common_errors'][error.class.name] += 1
      
      save_user_patterns
    end

    def git_status_summary
      return {} unless Dir.exist?('.git')
      
      begin
        status_output = `git status --porcelain`
        {
          modified_files: status_output.lines.count { |line| line.start_with?(' M', 'M ') },
          untracked_files: status_output.lines.count { |line| line.start_with?('??') },
          staged_files: status_output.lines.count { |line| line.start_with?('A ', 'M ') }
        }
      rescue StandardError
        {}
      end
    end

    def recent_commit_count
      return 0 unless Dir.exist?('.git')
      
      begin
        `git log --oneline --since="1 week ago"`.lines.count
      rescue StandardError
        0
      end
    end

    def detect_cpu_cores
      case RUBY_PLATFORM
      when /linux/
        `nproc`.to_i
      when /darwin/
        `sysctl -n hw.ncpu`.to_i
      else
        4 # Fallback
      end
    rescue StandardError
      4
    end

    def detect_available_memory
      case RUBY_PLATFORM
      when /linux/
        # Parse /proc/meminfo
        meminfo = File.read('/proc/meminfo')
        available_kb = meminfo[/MemAvailable:\s*(\d+)/, 1].to_i
        available_kb / 1024.0 / 1024.0 # Convert to GB
      when /darwin/
        # Use vm_stat
        vm_stat = `vm_stat`
        page_size = 4096
        pages_free = vm_stat[/Pages free:\s*(\d+)/, 1].to_i
        (pages_free * page_size) / 1024.0 / 1024.0 / 1024.0 # Convert to GB
      else
        8.0 # Fallback
      end
    rescue StandardError
      8.0
    end

    # Class methods for singleton access
    class << self
      def instance
        @instance ||= new
      end

      def suggest_role_for_task(*args)
        instance.suggest_role_for_task(*args)
      end

      def suggest_configuration
        instance.suggest_configuration
      end

      def auto_retry_with_backoff(*args, &block)
        instance.auto_retry_with_backoff(*args, &block)
      end

      def suggest_next_actions(*args)
        instance.suggest_next_actions(*args)
      end

      def auto_cleanup_if_needed
        instance.auto_cleanup_if_needed
      end

      def learn_from_action(*args)
        instance.learn_from_action(*args)
      end

      def get_suggestions(context = {})
        instance.suggest_next_actions(context)
      end
    end
  end
end