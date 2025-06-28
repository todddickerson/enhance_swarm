# frozen_string_literal: true

require 'singleton'
require 'json'
require 'digest'
require 'timeout'

module EnhanceSwarm
  class ErrorRecovery
    include Singleton

    RECOVERY_STRATEGIES_FILE = '.enhance_swarm/error_recovery_strategies.json'
    ERROR_PATTERNS_FILE = '.enhance_swarm/error_patterns.json'

    def initialize
      ensure_recovery_directory
      @recovery_strategies = load_recovery_strategies
      @error_patterns = load_error_patterns
      @recovery_history = []
    end

    # Analyze error and suggest recovery actions
    def analyze_error(error, context = {})
      error_info = {
        message: error.message,
        type: error.class.name,
        context: context,
        timestamp: Time.now.iso8601
      }

      # Find matching patterns
      matching_patterns = find_matching_patterns(error_info)
      
      # Generate recovery suggestions
      suggestions = generate_recovery_suggestions(error_info, matching_patterns)
      
      # Log error for pattern learning
      log_error_occurrence(error_info)
      
      {
        error: error_info,
        patterns: matching_patterns,
        suggestions: suggestions,
        auto_recoverable: auto_recoverable?(error_info, matching_patterns)
      }
    end

    # Attempt automatic recovery
    def attempt_recovery(error_analysis, agent_context = {})
      return false unless error_analysis[:auto_recoverable]

      recovery_attempts = []
      
      error_analysis[:suggestions].each do |suggestion|
        auto_executable = suggestion['auto_executable'] || suggestion[:auto_executable]
        next unless auto_executable
        
        begin
          description = suggestion['description'] || suggestion[:description]
          Logger.info("Attempting automatic recovery: #{description}")
          
          result = execute_recovery_action(suggestion, agent_context)
          
          recovery_attempts << {
            suggestion: suggestion,
            result: result,
            success: result[:success],
            timestamp: Time.now.iso8601
          }
          
          # If recovery succeeds, stop trying other strategies
          if result[:success]
            log_successful_recovery(error_analysis[:error], suggestion)
            return result
          end
          
        rescue StandardError => recovery_error
          Logger.error("Recovery attempt failed: #{recovery_error.message}")
          recovery_attempts << {
            suggestion: suggestion,
            result: { success: false, error: recovery_error.message },
            success: false,
            timestamp: Time.now.iso8601
          }
        end
      end
      
      # Log all recovery attempts for learning
      log_recovery_attempts(error_analysis[:error], recovery_attempts)
      
      { success: false, attempts: recovery_attempts }
    end

    # Get human-readable error explanation
    def explain_error(error, context = {})
      error_info = {
        message: error.message,
        type: error.class.name,
        context: context
      }

      matching_patterns = find_matching_patterns(error_info)
      
      if matching_patterns.any?
        primary_pattern = matching_patterns.first
        {
          explanation: primary_pattern[:explanation],
          likely_cause: primary_pattern[:likely_cause],
          prevention_tips: primary_pattern[:prevention_tips] || []
        }
      else
        generate_generic_explanation(error_info)
      end
    end

    # Learn from successful manual recovery
    def learn_from_manual_recovery(error, recovery_steps, context = {})
      error_info = {
        message: error.message,
        type: error.class.name,
        context: context,
        timestamp: Time.now.iso8601
      }

      # Create or update pattern
      pattern_key = generate_pattern_key(error_info)
      
      @error_patterns[pattern_key] ||= {
        'error_signatures' => [],
        'successful_recoveries' => [],
        'failure_rate' => 0.0,
        'last_seen' => nil
      }

      pattern = @error_patterns[pattern_key]
      
      # Add error signature if not already present
      signature = extract_error_signature(error_info)
      unless pattern['error_signatures'].any? { |sig| sig['message_pattern'] == signature[:message_pattern] }
        pattern['error_signatures'] << signature
      end

      # Add successful recovery
      pattern['successful_recoveries'] << {
        'steps' => recovery_steps,
        'context' => context,
        'timestamp' => Time.now.iso8601
      }

      pattern['last_seen'] = Time.now.iso8601
      
      save_error_patterns
      
      Logger.info("Learned new recovery pattern for #{error.class.name}")
    end

    # Get recovery statistics
    def recovery_statistics
      total_errors = @recovery_history.count
      successful_recoveries = @recovery_history.count { |h| h[:recovery_successful] }
      
      {
        total_errors_processed: total_errors,
        successful_automatic_recoveries: successful_recoveries,
        recovery_success_rate: total_errors > 0 ? (successful_recoveries.to_f / total_errors * 100).round(1) : 0.0,
        most_common_errors: most_common_error_types,
        recovery_patterns_learned: @error_patterns.count
      }
    end

    # Clear old recovery data
    def cleanup_old_data(days_to_keep = 30)
      cutoff_time = Time.now - (days_to_keep * 24 * 60 * 60)
      
      # Clean recovery history
      @recovery_history.reject! { |h| Time.parse(h[:timestamp]) < cutoff_time }
      
      # Clean old error patterns that haven't been seen recently
      @error_patterns.reject! do |_, pattern|
        last_seen = pattern['last_seen'] || pattern[:last_seen]
        last_seen && Time.parse(last_seen) < cutoff_time
      end
      
      save_error_patterns
      
      Logger.info("Cleaned up error recovery data older than #{days_to_keep} days")
    end

    private

    def load_recovery_strategies
      return default_recovery_strategies unless File.exist?(RECOVERY_STRATEGIES_FILE)
      
      JSON.parse(File.read(RECOVERY_STRATEGIES_FILE))
    rescue StandardError
      default_recovery_strategies
    end

    def load_error_patterns
      return {} unless File.exist?(ERROR_PATTERNS_FILE)
      
      JSON.parse(File.read(ERROR_PATTERNS_FILE))
    rescue StandardError
      {}
    end

    def save_error_patterns
      ensure_recovery_directory
      File.write(ERROR_PATTERNS_FILE, JSON.pretty_generate(@error_patterns))
    end

    def ensure_recovery_directory
      dir = File.dirname(RECOVERY_STRATEGIES_FILE)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end

    def default_recovery_strategies
      {
        'network_errors' => [
          {
            'description' => 'Retry with exponential backoff',
            'auto_executable' => true,
            'action' => 'retry_with_backoff',
            'max_attempts' => 3,
            'base_delay' => 1
          },
          {
            'description' => 'Check network connectivity',
            'auto_executable' => false,
            'action' => 'check_network',
            'command' => 'ping -c 1 8.8.8.8'
          }
        ],
        'file_not_found' => [
          {
            'description' => 'Create missing file with default content',
            'auto_executable' => true,
            'action' => 'create_default_file'
          },
          {
            'description' => 'Search for similar files in project',
            'auto_executable' => true,
            'action' => 'find_similar_files'
          }
        ],
        'permission_denied' => [
          {
            'description' => 'Fix file permissions',
            'auto_executable' => false,
            'action' => 'fix_permissions',
            'command' => 'chmod +x {file_path}'
          },
          {
            'description' => 'Run with elevated privileges',
            'auto_executable' => false,
            'action' => 'elevate_privileges'
          }
        ],
        'dependency_missing' => [
          {
            'description' => 'Install missing dependencies',
            'auto_executable' => true,
            'action' => 'install_dependencies'
          },
          {
            'description' => 'Update package manager',
            'auto_executable' => false,
            'action' => 'update_package_manager'
          }
        ],
        'timeout_error' => [
          {
            'description' => 'Increase timeout and retry',
            'auto_executable' => true,
            'action' => 'retry_with_longer_timeout',
            'timeout_multiplier' => 2.0
          },
          {
            'description' => 'Break task into smaller chunks',
            'auto_executable' => false,
            'action' => 'split_task'
          }
        ],
        'memory_error' => [
          {
            'description' => 'Reduce memory usage and retry',
            'auto_executable' => true,
            'action' => 'retry_with_reduced_memory'
          },
          {
            'description' => 'Clear system memory cache',
            'auto_executable' => false,
            'action' => 'clear_memory_cache'
          }
        ]
      }
    end

    def find_matching_patterns(error_info)
      matches = []
      
      @error_patterns.each do |pattern_key, pattern|
        confidence = calculate_pattern_match_confidence(error_info, pattern)
        
        if confidence > 0.5 # 50% confidence threshold
          matches << {
            pattern_key: pattern_key,
            confidence: confidence,
            explanation: pattern['explanation'] || pattern[:explanation] || "Similar error pattern detected",
            likely_cause: pattern['likely_cause'] || pattern[:likely_cause] || "Unknown cause",
            prevention_tips: pattern['prevention_tips'] || pattern[:prevention_tips] || [],
            successful_recoveries: pattern['successful_recoveries'] || pattern[:successful_recoveries] || []
          }
        end
      end
      
      # Sort by confidence
      matches.sort_by { |m| -m[:confidence] }
    end

    def calculate_pattern_match_confidence(error_info, pattern)
      error_signatures = pattern['error_signatures'] || pattern[:error_signatures]
      return 0.0 if error_signatures.nil? || error_signatures.empty?
      
      max_confidence = 0.0
      
      error_signatures.each do |signature|
        confidence = 0.0
        
        # Match error type
        error_type = signature['error_type'] || signature[:error_type]
        if error_type == error_info[:type]
          confidence += 0.4
        end
        
        # Match message patterns
        message_pattern = signature['message_pattern'] || signature[:message_pattern]
        if message_pattern && error_info[:message].downcase.include?(message_pattern.downcase)
          confidence += 0.3
        end
        
        # Match context patterns
        context_patterns = signature['context_patterns'] || signature[:context_patterns]
        if context_patterns && context_patterns.any?
          context_matches = context_patterns.count do |pattern|
            error_info[:context].to_s.downcase.include?(pattern.downcase)
          end
          
          confidence += (context_matches.to_f / context_patterns.count) * 0.3
        end
        
        max_confidence = [max_confidence, confidence].max
      end
      
      max_confidence
    end

    def generate_recovery_suggestions(error_info, matching_patterns)
      suggestions = []
      
      # Add suggestions from matching patterns
      matching_patterns.each do |pattern|
        successful_recoveries = pattern['successful_recoveries'] || pattern[:successful_recoveries] || []
        successful_recoveries.each do |recovery|
          steps = recovery['steps'] || recovery[:steps] || []
          suggestions << {
            description: "Apply previously successful recovery: #{steps.join(' → ')}",
            auto_executable: false,
            action: 'manual_recovery',
            steps: steps,
            confidence: pattern[:confidence],
            source: 'learned_pattern'
          }
        end
      end
      
      # Add generic recovery strategies
      generic_strategies = get_generic_strategies_for_error(error_info)
      suggestions.concat(generic_strategies)
      
      # Sort by confidence and auto-executability
      suggestions.sort_by { |s| [-s[:confidence], s[:auto_executable] ? 1 : 0] }
    end

    def get_generic_strategies_for_error(error_info)
      strategies = []
      
      # Network-related errors
      if network_error?(error_info)
        @recovery_strategies['network_errors'].each do |strategy|
          strategies << strategy.merge(confidence: 0.7, source: 'generic')
        end
      end
      
      # File system errors
      if file_system_error?(error_info)
        if error_info[:message].include?('No such file')
          @recovery_strategies['file_not_found'].each do |strategy|
            strategies << strategy.merge(confidence: 0.8, source: 'generic')
          end
        elsif error_info[:message].include?('Permission denied')
          @recovery_strategies['permission_denied'].each do |strategy|
            strategies << strategy.merge(confidence: 0.8, source: 'generic')
          end
        end
      end
      
      # Dependency errors
      if dependency_error?(error_info)
        @recovery_strategies['dependency_missing'].each do |strategy|
          strategies << strategy.merge(confidence: 0.7, source: 'generic')
        end
      end
      
      # Timeout errors
      if timeout_error?(error_info)
        @recovery_strategies['timeout_error'].each do |strategy|
          strategies << strategy.merge(confidence: 0.6, source: 'generic')
        end
      end
      
      # Memory errors
      if memory_error?(error_info)
        @recovery_strategies['memory_error'].each do |strategy|
          strategies << strategy.merge(confidence: 0.6, source: 'generic')
        end
      end
      
      strategies
    end

    def auto_recoverable?(error_info, matching_patterns)
      # Don't auto-recover critical system errors
      return false if critical_error?(error_info)
      
      # Check if any generic strategies are auto-executable
      get_generic_strategies_for_error(error_info).any? { |s| s['auto_executable'] }
    end

    def execute_recovery_action(suggestion, agent_context)
      action = suggestion['action'] || suggestion[:action]
      
      case action
      when 'retry_with_backoff'
        retry_with_backoff(suggestion, agent_context)
      when 'create_default_file'
        create_default_file(suggestion, agent_context)
      when 'find_similar_files'
        find_similar_files(suggestion, agent_context)
      when 'install_dependencies'
        install_dependencies(suggestion, agent_context)
      when 'retry_with_longer_timeout'
        retry_with_longer_timeout(suggestion, agent_context)
      when 'retry_with_reduced_memory'
        retry_with_reduced_memory(suggestion, agent_context)
      else
        { success: false, error: "Unknown recovery action: #{action}" }
      end
    end

    def retry_with_backoff(suggestion, agent_context)
      max_attempts = suggestion['max_attempts'] || 3
      base_delay = suggestion['base_delay'] || 1
      
      attempt = 1
      
      while attempt <= max_attempts
        begin
          # Re-execute the original operation
          if agent_context[:retry_block]
            result = agent_context[:retry_block].call
            return { success: true, result: result, attempts: attempt }
          else
            return { success: false, error: 'No retry block provided' }
          end
        rescue StandardError => e
          if attempt == max_attempts
            return { success: false, error: e.message, attempts: attempt }
          end
          
          delay = base_delay * (2 ** (attempt - 1))
          sleep(delay)
          attempt += 1
        end
      end
    end

    def create_default_file(suggestion, agent_context)
      file_path = agent_context[:file_path]
      return { success: false, error: 'No file path provided' } unless file_path
      
      begin
        # Create directory if it doesn't exist
        FileUtils.mkdir_p(File.dirname(file_path))
        
        # Create file with default content based on extension
        default_content = generate_default_file_content(file_path)
        File.write(file_path, default_content)
        
        { success: true, file_created: file_path, content: default_content }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end

    def find_similar_files(suggestion, agent_context)
      file_path = agent_context[:file_path]
      return { success: false, error: 'No file path provided' } unless file_path
      
      begin
        filename = File.basename(file_path)
        directory = File.dirname(file_path)
        extension = File.extname(file_path)
        basename_without_ext = File.basename(filename, extension)
        
        # Search for similar files
        similar_files = Dir.glob("#{directory}/**/*#{extension}").select do |f|
          existing_basename = File.basename(f, extension)
          # Check if either file contains parts of the other's name
          basename_without_ext.include?(existing_basename) || 
          existing_basename.include?(basename_without_ext) ||
          # Also check for common prefixes (e.g., "test" in both "test_new" and "test_file")
          common_prefix_length(basename_without_ext, existing_basename) >= 3
        end
        
        { success: true, similar_files: similar_files }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end

    def install_dependencies(suggestion, agent_context)
      begin
        if File.exist?('package.json')
          system('npm install')
          { success: true, package_manager: 'npm' }
        elsif File.exist?('Gemfile')
          system('bundle install')
          { success: true, package_manager: 'bundler' }
        elsif File.exist?('requirements.txt')
          system('pip install -r requirements.txt')
          { success: true, package_manager: 'pip' }
        else
          { success: false, error: 'No recognized dependency file found' }
        end
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end

    def retry_with_longer_timeout(suggestion, agent_context)
      multiplier = suggestion['timeout_multiplier'] || 2.0
      original_timeout = agent_context[:timeout] || 30
      new_timeout = (original_timeout * multiplier).to_i
      
      begin
        if agent_context[:retry_block]
          result = Timeout.timeout(new_timeout) do
            agent_context[:retry_block].call
          end
          { success: true, result: result, new_timeout: new_timeout }
        else
          { success: false, error: 'No retry block provided' }
        end
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end

    def retry_with_reduced_memory(suggestion, agent_context)
      begin
        # Force garbage collection
        GC.start
        
        # Re-execute with reduced memory profile
        if agent_context[:retry_block]
          result = agent_context[:retry_block].call
          { success: true, result: result }
        else
          { success: false, error: 'No retry block provided' }
        end
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end

    def generate_default_file_content(file_path)
      extension = File.extname(file_path).downcase
      
      case extension
      when '.rb'
        "# frozen_string_literal: true\n\n# Default Ruby file\n"
      when '.js'
        "// Default JavaScript file\n"
      when '.ts'
        "// Default TypeScript file\nexport {};\n"
      when '.py'
        "#!/usr/bin/env python3\n# Default Python file\n"
      when '.yml', '.yaml'
        "# Default YAML configuration\n"
      when '.json'
        "{}\n"
      when '.md'
        "# #{File.basename(file_path, extension).gsub(/[_-]/, ' ').split.map(&:capitalize).join(' ')}\n\nDefault content.\n"
      else
        "# Default content for #{file_path}\n"
      end
    end

    def network_error?(error_info)
      network_patterns = [
        'connection', 'network', 'timeout', 'unreachable', 'dns',
        'socket', 'ssl', 'certificate', 'refused', 'reset'
      ]
      
      message_lower = error_info[:message].downcase
      network_patterns.any? { |pattern| message_lower.include?(pattern) }
    end

    def file_system_error?(error_info)
      fs_patterns = [
        'no such file', 'permission denied', 'file not found',
        'directory not found', 'access denied', 'file exists'
      ]
      
      message_lower = error_info[:message].downcase
      fs_patterns.any? { |pattern| message_lower.include?(pattern) }
    end

    def dependency_error?(error_info)
      dep_patterns = [
        'cannot load', 'not found', 'missing', 'uninitialized constant',
        'module not found', 'import error', 'no such gem'
      ]
      
      message_lower = error_info[:message].downcase
      dep_patterns.any? { |pattern| message_lower.include?(pattern) }
    end

    def timeout_error?(error_info)
      error_info[:type].include?('Timeout') || 
      error_info[:message].downcase.include?('timeout')
    end

    def memory_error?(error_info)
      memory_patterns = ['memory', 'out of memory', 'cannot allocate']
      
      message_lower = error_info[:message].downcase
      memory_patterns.any? { |pattern| message_lower.include?(pattern) }
    end

    def critical_error?(error_info)
      critical_patterns = [
        'system', 'kernel', 'segmentation fault', 'access violation',
        'stack overflow', 'fatal'
      ]
      
      message_lower = error_info[:message].downcase
      critical_patterns.any? { |pattern| message_lower.include?(pattern) }
    end

    def generate_generic_explanation(error_info)
      {
        explanation: "An error of type #{error_info[:type]} occurred",
        likely_cause: "The specific cause is unclear from the available information",
        prevention_tips: [
          "Check the error message for specific details",
          "Verify that all dependencies are properly installed",
          "Ensure file permissions are correct",
          "Check for typos in file paths or commands"
        ]
      }
    end

    def log_error_occurrence(error_info)
      @recovery_history << {
        error: error_info,
        timestamp: Time.now.iso8601,
        recovery_attempted: false,
        recovery_successful: false
      }
    end

    def log_successful_recovery(error_info, recovery_strategy)
      # Update the most recent entry
      if @recovery_history.last && @recovery_history.last[:error] == error_info
        @recovery_history.last[:recovery_attempted] = true
        @recovery_history.last[:recovery_successful] = true
        @recovery_history.last[:recovery_strategy] = recovery_strategy
      end
    end

    def log_recovery_attempts(error_info, attempts)
      # Update the most recent entry
      if @recovery_history.last && @recovery_history.last[:error] == error_info
        @recovery_history.last[:recovery_attempted] = true
        @recovery_history.last[:recovery_successful] = attempts.any? { |a| a[:success] }
        @recovery_history.last[:recovery_attempts] = attempts
      end
    end

    def most_common_error_types
      error_counts = @recovery_history.group_by { |h| h[:error][:type] }
                                    .transform_values(&:count)
      
      error_counts.sort_by { |_, count| -count }.first(5).to_h
    end

    def extract_error_signature(error_info)
      {
        'error_type' => error_info[:type],
        'message_pattern' => extract_message_pattern(error_info[:message]),
        'context_patterns' => extract_context_patterns(error_info[:context])
      }
    end

    def extract_message_pattern(message)
      # Extract key words and remove specific paths/values
      pattern = message.gsub(/\/[\/\w.-]+/, '<PATH>')
                      .gsub(/\d+/, '<NUMBER>')
                      .gsub(/[a-f0-9]{8,}/, '<HASH>')
                      .strip
      
      # Take first meaningful part
      pattern.split(/[:.!]/).first&.strip || pattern
    end

    def extract_context_patterns(context)
      return [] unless context.is_a?(Hash)
      
      patterns = []
      context.each do |key, value|
        patterns << "#{key}:#{value.class.name}" if value
      end
      patterns
    end

    def generate_pattern_key(error_info)
      # Generate a consistent key for grouping similar errors
      key_parts = [
        error_info[:type],
        extract_message_pattern(error_info[:message])
      ]
      
      Digest::SHA256.hexdigest(key_parts.join('|'))[0, 16]
    end

    def common_prefix_length(str1, str2)
      return 0 if str1.nil? || str2.nil?
      
      min_length = [str1.length, str2.length].min
      (0...min_length).each do |i|
        return i if str1[i].downcase != str2[i].downcase
      end
      min_length
    end

    # Class methods for singleton access
    class << self
      def analyze_error(*args)
        instance.analyze_error(*args)
      end

      def attempt_recovery(*args)
        instance.attempt_recovery(*args)
      end

      def explain_error(*args)
        instance.explain_error(*args)
      end

      def learn_from_manual_recovery(*args)
        instance.learn_from_manual_recovery(*args)
      end

      def recovery_statistics
        instance.recovery_statistics
      end

      def cleanup_old_data(*args)
        instance.cleanup_old_data(*args)
      end
    end
  end
end