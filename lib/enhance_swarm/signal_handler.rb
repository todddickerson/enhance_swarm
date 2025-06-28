# frozen_string_literal: true

require_relative 'logger'
require_relative 'cleanup_manager'

module EnhanceSwarm
  class SignalHandler
    def self.setup
      @shutdown_requested = false
      @active_operations = {}
      
      # Handle graceful shutdown signals
      Signal.trap('INT') { handle_shutdown('SIGINT') }
      Signal.trap('TERM') { handle_shutdown('SIGTERM') }
      
      # Handle info signal for status
      if Signal.list.key?('USR1')
        Signal.trap('USR1') { handle_status_request }
      end
    end

    def self.handle_shutdown(signal)
      return if @shutdown_requested
      
      @shutdown_requested = true
      Logger.info("Received #{signal}, initiating graceful shutdown...")
      
      begin
        # Stop accepting new operations
        puts "\n🛑 Graceful shutdown initiated...".colorize(:yellow)
        
        # Clean up any active operations
        cleanup_active_operations
        
        # Perform final cleanup
        CleanupManager.cleanup_all_swarm_resources
        
        Logger.info("Graceful shutdown completed")
        puts "✅ Shutdown complete".colorize(:green)
        
        exit(0)
      rescue StandardError => e
        Logger.error("Error during shutdown: #{e.message}")
        puts "❌ Error during shutdown: #{e.message}".colorize(:red)
        exit(1)
      end
    end

    def self.handle_status_request
      Logger.info("Status request received via USR1")
      
      status = {
        active_operations: @active_operations.size,
        shutdown_requested: @shutdown_requested,
        timestamp: Time.now.iso8601
      }
      
      puts JSON.pretty_generate(status)
    end

    def self.register_operation(operation_id, details = {})
      @active_operations ||= {}
      @active_operations[operation_id] = {
        started_at: Time.now,
        details: details
      }
    end

    def self.unregister_operation(operation_id)
      @active_operations&.delete(operation_id)
    end

    def self.shutdown_requested?
      @shutdown_requested
    end

    private

    def self.cleanup_active_operations
      return unless @active_operations&.any?
      
      Logger.info("Cleaning up #{@active_operations.size} active operations")
      
      @active_operations.each do |operation_id, details|
        begin
          CleanupManager.cleanup_failed_operation(operation_id, details[:details])
        rescue StandardError => e
          Logger.error("Failed to cleanup operation #{operation_id}: #{e.message}")
        end
      end
      
      @active_operations.clear
    end
  end
end