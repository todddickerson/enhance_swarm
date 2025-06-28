# frozen_string_literal: true

module EnhanceSwarm
  class RetryHandler
    class RetryError < StandardError; end

    def self.with_retry(max_retries: 3, base_delay: 1, max_delay: 30, &block)
      retries = 0
      
      begin
        yield
      rescue StandardError => e
        retries += 1
        
        if retries <= max_retries && retryable_error?(e)
          delay = [base_delay * (2 ** (retries - 1)), max_delay].min
          puts "Attempt #{retries} failed: #{e.message}. Retrying in #{delay}s...".colorize(:yellow)
          sleep(delay)
          retry
        end
        
        raise RetryError.new("Operation failed after #{max_retries} retries: #{e.message}")
      end
    end

    def self.retryable_error?(error)
      case error
      when CommandExecutor::CommandError
        # Retry on timeout or command not found, but not on validation errors
        error.message.include?('timed out') || error.message.include?('not found')
      when Errno::ENOENT, Errno::ECONNREFUSED, Errno::ETIMEDOUT
        true
      when IOError, SystemCallError
        true
      else
        false
      end
    end
  end
end