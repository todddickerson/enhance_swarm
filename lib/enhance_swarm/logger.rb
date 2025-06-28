# frozen_string_literal: true

require 'logger'
require 'json'
require 'time'

module EnhanceSwarm
  class Logger
    LOG_LEVELS = {
      debug: ::Logger::DEBUG,
      info: ::Logger::INFO,
      warn: ::Logger::WARN,
      error: ::Logger::ERROR,
      fatal: ::Logger::FATAL
    }.freeze

    def self.logger
      @logger ||= create_logger
    end

    def self.create_logger
      logger = ::Logger.new($stdout)
      logger.level = log_level
      logger.formatter = method(:format_message)
      logger
    end

    def self.log_level
      level = ENV['ENHANCE_SWARM_LOG_LEVEL']&.downcase&.to_sym || :info
      LOG_LEVELS[level] || ::Logger::INFO
    end

    def self.format_message(severity, timestamp, progname, msg)
      if ENV['ENHANCE_SWARM_JSON_LOGS'] == 'true'
        format_json(severity, timestamp, progname, msg)
      else
        format_human(severity, timestamp, progname, msg)
      end
    end

    def self.format_json(severity, timestamp, progname, msg)
      {
        timestamp: timestamp.iso8601,
        level: severity,
        component: progname || 'enhance_swarm',
        message: msg.to_s,
        pid: Process.pid
      }.to_json + "\n"
    end

    def self.format_human(severity, timestamp, progname, msg)
      color = case severity
               when 'ERROR', 'FATAL' then :red
               when 'WARN' then :yellow
               when 'INFO' then :blue
               else :white
               end
      
      "[#{timestamp.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} #{msg}".colorize(color) + "\n"
    end

    # Convenience methods
    def self.debug(msg, component: nil)
      logger.debug(msg) { component }
    end

    def self.info(msg, component: nil)
      logger.info(msg) { component }
    end

    def self.warn(msg, component: nil)
      logger.warn(msg) { component }
    end

    def self.error(msg, component: nil)
      logger.error(msg) { component }
    end

    def self.fatal(msg, component: nil)
      logger.fatal(msg) { component }
    end

    # Structured logging for automation
    def self.log_operation(operation, status, details = {})
      log_data = {
        operation: operation,
        status: status,
        details: details,
        timestamp: Time.now.iso8601
      }

      case status
      when 'success', 'completed'
        info("Operation #{operation} completed successfully", component: 'operation')
      when 'failed', 'error'
        error("Operation #{operation} failed: #{details[:error]}", component: 'operation')
      when 'started', 'in_progress'
        info("Operation #{operation} started", component: 'operation')
      else
        debug("Operation #{operation}: #{status}", component: 'operation')
      end

      log_data
    end
  end
end