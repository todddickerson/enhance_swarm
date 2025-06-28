# frozen_string_literal: true

require 'open3'
require 'shellwords'
require 'timeout'

module EnhanceSwarm
  class CommandExecutor
    class CommandError < StandardError
      attr_reader :exit_status, :stderr

      def initialize(message, exit_status: nil, stderr: nil)
        super(message)
        @exit_status = exit_status
        @stderr = stderr
      end
    end

    def self.execute(command, *args, timeout: 30, input: nil)
      # Sanitize command and arguments
      safe_command = sanitize_command(command)
      safe_args = args.map { |arg| sanitize_argument(arg) }

      begin
        Timeout.timeout(timeout) do
          stdout, stderr, status = Open3.capture3(safe_command, *safe_args,
                                                  stdin_data: input)

          unless status.success?
            raise CommandError.new(
              "Command failed: #{safe_command} #{safe_args.join(' ')}",
              exit_status: status.exitstatus,
              stderr: stderr
            )
          end

          stdout.strip
        end
      rescue Timeout::Error
        raise CommandError.new("Command timed out after #{timeout} seconds")
      rescue Errno::ENOENT
        raise CommandError.new("Command not found: #{safe_command}")
      end
    end

    def self.execute_async(command, *args)
      safe_command = sanitize_command(command)
      safe_args = args.map { |arg| sanitize_argument(arg) }

      begin
        pid = Process.spawn(safe_command, *safe_args)
        Process.detach(pid)
        pid
      rescue Errno::ENOENT
        raise CommandError.new("Command not found: #{safe_command}")
      end
    end

    def self.command_available?(command)
      execute('which', command, timeout: 5)
      true
    rescue CommandError
      false
    end

    def self.sanitize_command(command)
      # Only allow alphanumeric, dash, underscore, and slash
      raise ArgumentError, "Invalid command: #{command}" unless command.match?(%r{\A[a-zA-Z0-9_\-/]+\z})

      command
    end

    def self.sanitize_argument(arg)
      # Convert to string and escape shell metacharacters
      Shellwords.escape(arg.to_s)
    end
  end
end
