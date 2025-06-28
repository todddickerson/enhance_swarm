# frozen_string_literal: true

require 'singleton'
require 'json'
require 'fileutils'
require 'colorize'

module EnhanceSwarm
  class AgentCommunicator
    include Singleton

    COMMUNICATION_DIR = '.enhance_swarm/communication'
    MESSAGE_FILE_PATTERN = 'agent_*.json'
    USER_RESPONSE_FILE = 'user_responses.json'
    PROMPT_TIMEOUT = 120 # 2 minutes for user response
    
    def initialize
      @communication_dir = File.join(Dir.pwd, COMMUNICATION_DIR)
      @user_responses = {}
      @pending_messages = {}
      @monitoring_active = false
      @monitoring_thread = nil
      ensure_communication_directory
      load_existing_responses
    end

    # Agent sends a message/question to user
    def agent_message(agent_id, message_type, content, options = {})
      message = {
        id: generate_message_id(agent_id),
        agent_id: agent_id,
        role: options[:role] || extract_role_from_id(agent_id),
        type: message_type,
        content: content,
        timestamp: Time.now.iso8601,
        priority: options[:priority] || :medium,
        requires_response: options[:requires_response] || false,
        timeout: options[:timeout] || PROMPT_TIMEOUT,
        quick_actions: options[:quick_actions] || [],
        context: options[:context] || {}
      }

      save_message(message)
      
      if message[:requires_response]
        @pending_messages[message[:id]] = message
        prompt_user_for_response(message) if options[:immediate_prompt]
      end

      # Notify user through notification system
      notify_user_of_message(message)
      
      message[:id]
    end

    # Agent asks a quick question requiring user response
    def agent_question(agent_id, question, quick_actions = [], options = {})
      agent_message(
        agent_id,
        :question,
        question,
        {
          requires_response: true,
          quick_actions: quick_actions,
          immediate_prompt: options[:immediate_prompt] || false,
          priority: options[:priority] || :high,
          **options
        }
      )
    end

    # Agent provides status update
    def agent_status(agent_id, status, details = {})
      agent_message(
        agent_id,
        :status,
        status,
        {
          requires_response: false,
          priority: :low,
          context: details
        }
      )
    end

    # Agent reports progress
    def agent_progress(agent_id, progress_message, percentage = nil, eta = nil)
      agent_message(
        agent_id,
        :progress,
        progress_message,
        {
          requires_response: false,
          priority: :low,
          context: {
            percentage: percentage,
            eta: eta&.iso8601
          }
        }
      )
    end

    # Agent requests user decision
    def agent_decision(agent_id, decision_prompt, options_list, default = nil)
      agent_message(
        agent_id,
        :decision,
        decision_prompt,
        {
          requires_response: true,
          quick_actions: options_list,
          immediate_prompt: true,
          priority: :high,
          context: { default: default }
        }
      )
    end

    # User responds to a pending message
    def user_respond(message_id, response)
      if @pending_messages[message_id]
        @user_responses[message_id] = {
          response: response,
          timestamp: Time.now.iso8601
        }
        
        save_user_responses
        @pending_messages.delete(message_id)
        
        # Notify agent via file system
        create_response_file(message_id, response)
        
        puts "✅ Response sent to agent".colorize(:green)
        true
      else
        puts "❌ Message ID not found or already responded".colorize(:red)
        false
      end
    end

    # Get pending messages for user
    def pending_messages
      @pending_messages.values.sort_by { |msg| msg[:timestamp] }
    end

    # Get recent messages (responded + pending)
    def recent_messages(limit = 10)
      all_messages = load_all_messages
      all_messages.sort_by { |msg| msg[:timestamp] }.last(limit)
    end

    # Check for agent response to user input
    def agent_get_response(message_id, timeout = PROMPT_TIMEOUT)
      start_time = Time.now
      
      while Time.now - start_time < timeout
        response_file = File.join(@communication_dir, "response_#{message_id}.json")
        
        if File.exist?(response_file)
          response_data = JSON.parse(File.read(response_file))
          File.delete(response_file) # Cleanup
          return response_data['response']
        end
        
        sleep(1)
      end
      
      nil # Timeout
    end

    # Start monitoring for user responses (CLI integration)
    def start_monitoring
      return if @monitoring_active
      
      @monitoring_active = true
      @monitoring_thread = Thread.new do
        monitor_for_pending_messages
      end
    end

    def stop_monitoring
      @monitoring_active = false
      @monitoring_thread&.kill
      @monitoring_thread = nil
    end

    # CLI: Show pending messages
    def show_pending_messages
      pending = pending_messages
      
      if pending.empty?
        puts "No pending messages from agents".colorize(:yellow)
        return
      end
      
      puts "\n💬 Pending Agent Messages:".colorize(:blue)
      pending.each_with_index do |message, index|
        show_message_summary(message, index + 1)
      end
      
      puts "\nUse 'enhance-swarm communicate --respond <id> <response>' to reply".colorize(:light_black)
    end

    # CLI: Interactive response mode
    def interactive_response_mode
      pending = pending_messages
      
      if pending.empty?
        puts "No pending messages".colorize(:yellow)
        return
      end
      
      puts "\n💬 Interactive Agent Communication".colorize(:blue)
      
      pending.each_with_index do |message, index|
        puts "\n#{'-' * 60}".colorize(:light_black)
        show_message_detail(message, index + 1)
        
        if message[:quick_actions].any?
          puts "\nQuick actions:".colorize(:yellow)
          message[:quick_actions].each_with_index do |action, i|
            puts "  #{i + 1}. #{action}"
          end
          puts "  c. Custom response"
        end
        
        print "\nYour response: ".colorize(:blue)
        response = $stdin.gets&.chomp
        
        next if response.nil? || response.empty?
        
        # Handle quick action selection
        if message[:quick_actions].any? && response.match?(/^\d+$/)
          action_index = response.to_i - 1
          if action_index >= 0 && action_index < message[:quick_actions].length
            response = message[:quick_actions][action_index]
          end
        end
        
        user_respond(message[:id], response)
      end
    end

    # Clean up old messages
    def cleanup_old_messages(days_old = 7)
      cutoff = Time.now - (days_old * 24 * 60 * 60)
      
      Dir.glob(File.join(@communication_dir, MESSAGE_FILE_PATTERN)).each do |file|
        begin
          message = JSON.parse(File.read(file))
          message_time = Time.parse(message['timestamp'])
          
          if message_time < cutoff
            File.delete(file)
          end
        rescue
          # Delete malformed files
          File.delete(file)
        end
      end
    end

    private

    def ensure_communication_directory
      FileUtils.mkdir_p(@communication_dir) unless Dir.exist?(@communication_dir)
    end

    def generate_message_id(agent_id)
      "#{agent_id}_#{Time.now.to_i}_#{rand(1000)}"
    end

    def extract_role_from_id(agent_id)
      agent_id.split('-').first
    end

    def save_message(message)
      filename = "agent_#{message[:id]}.json"
      filepath = File.join(@communication_dir, filename)
      
      File.write(filepath, JSON.pretty_generate(message))
    end

    def load_all_messages
      messages = []
      
      Dir.glob(File.join(@communication_dir, MESSAGE_FILE_PATTERN)).each do |file|
        begin
          message = JSON.parse(File.read(file), symbolize_names: true)
          messages << message
        rescue
          # Skip malformed files
        end
      end
      
      messages
    end

    def load_existing_responses
      response_file = File.join(@communication_dir, USER_RESPONSE_FILE)
      
      if File.exist?(response_file)
        @user_responses = JSON.parse(File.read(response_file))
      end
    rescue
      @user_responses = {}
    end

    def save_user_responses
      response_file = File.join(@communication_dir, USER_RESPONSE_FILE)
      File.write(response_file, JSON.pretty_generate(@user_responses))
    end

    def create_response_file(message_id, response)
      response_file = File.join(@communication_dir, "response_#{message_id}.json")
      File.write(response_file, JSON.pretty_generate({
        message_id: message_id,
        response: response,
        timestamp: Time.now.iso8601
      }))
    end

    def notify_user_of_message(message)
      return unless defined?(NotificationManager)
      
      notification_content = case message[:type]
                             when :question
                               "❓ #{message[:role].capitalize} agent has a question"
                             when :decision
                               "🤔 #{message[:role].capitalize} agent needs a decision"
                             when :status
                               "📝 #{message[:role].capitalize}: #{message[:content]}"
                             when :progress
                               "📊 #{message[:role].capitalize}: #{message[:content]}"
                             else
                               "💬 Message from #{message[:role]} agent"
                             end
      
      priority = message[:requires_response] ? :high : :low
      
      NotificationManager.instance.notify(
        :agent_communication,
        notification_content,
        {
          agent_id: message[:agent_id],
          message_id: message[:id],
          requires_response: message[:requires_response],
          type: message[:type]
        }
      )
    end

    def prompt_user_for_response(message)
      puts "\n💬 Agent Message [#{message[:agent_id]}]:".colorize(:blue)
      puts "#{message[:content]}"
      
      if message[:quick_actions].any?
        puts "\nQuick actions:".colorize(:yellow)
        message[:quick_actions].each_with_index do |action, i|
          puts "  #{i + 1}. #{action}"
        end
        puts "  Or provide custom response:"
      end
      
      puts "Use 'enhance-swarm communicate --respond #{message[:id]} <response>' to reply".colorize(:light_black)
    end

    def monitor_for_pending_messages
      while @monitoring_active
        # Check for messages that need immediate user attention
        @pending_messages.values.each do |message|
          age = Time.now - Time.parse(message[:timestamp])
          
          # Prompt if message is getting old and high priority
          if age > 60 && message[:priority] == :high && !message[:notified]
            puts "\n⚠️  Urgent: Agent #{message[:agent_id]} waiting for response!".colorize(:red)
            puts "Message: #{message[:content]}"
            puts "Use 'enhance-swarm communicate --list' to see all pending messages".colorize(:light_black)
            
            message[:notified] = true
          end
        end
        
        sleep(30) # Check every 30 seconds
      end
    rescue StandardError => e
      Logger.error("Communication monitoring error: #{e.message}")
    end

    def show_message_summary(message, index)
      age = time_ago_in_words(Time.parse(message[:timestamp]))
      priority_color = case message[:priority]
                       when :high then :yellow
                       when :critical then :red
                       else :white
                       end
      
      puts "#{index}. [#{message[:id]}] #{message[:type].upcase} from #{message[:role]} (#{age} ago)".colorize(priority_color)
      puts "   #{message[:content][0..80]}#{message[:content].length > 80 ? '...' : ''}"
    end

    def show_message_detail(message, index)
      age = time_ago_in_words(Time.parse(message[:timestamp]))
      
      puts "#{index}. Message from #{message[:role]} agent [#{message[:agent_id]}]".colorize(:blue)
      puts "   Type: #{message[:type]}".colorize(:light_black)
      puts "   Priority: #{message[:priority]}".colorize(:light_black)
      puts "   Sent: #{age} ago".colorize(:light_black)
      puts "\n#{message[:content]}"
      
      if message[:context] && message[:context].any?
        puts "\nContext:".colorize(:light_black)
        message[:context].each do |key, value|
          puts "  #{key}: #{value}"
        end
      end
    end

    def time_ago_in_words(time)
      seconds = Time.now - time
      
      if seconds < 60
        "#{seconds.round}s"
      elsif seconds < 3600
        "#{(seconds / 60).round}m"
      elsif seconds < 86400
        "#{(seconds / 3600).round}h"
      else
        "#{(seconds / 86400).round}d"
      end
    end

    # Class methods for singleton access
    class << self
      def instance
        @instance ||= new
      end

      def agent_message(*args)
        instance.agent_message(*args)
      end

      def agent_question(*args)
        instance.agent_question(*args)
      end

      def agent_status(*args)
        instance.agent_status(*args)
      end

      def agent_progress(*args)
        instance.agent_progress(*args)
      end

      def agent_decision(*args)
        instance.agent_decision(*args)
      end
    end
  end
end