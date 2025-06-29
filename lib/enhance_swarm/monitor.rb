# frozen_string_literal: true

require 'colorize'
require_relative 'command_executor'
require_relative 'process_monitor'

module EnhanceSwarm
  class Monitor
    def initialize
      @config = EnhanceSwarm.configuration
      @process_monitor = ProcessMonitor.new
    end

    def watch(interval: nil, timeout: nil)
      interval ||= @config.monitor_interval
      timeout ||= @config.monitor_timeout

      # Delegate to built-in process monitor
      @process_monitor.watch(interval: interval, timeout: timeout)
    end

    def status
      # Delegate to built-in process monitor
      @process_monitor.status
    end

  end
end
