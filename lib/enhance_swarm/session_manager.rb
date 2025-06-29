# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'securerandom'
require_relative 'logger'

module EnhanceSwarm
  class SessionManager
    SESSION_DIR = '.enhance_swarm'
    SESSION_FILE = 'session.json'

    def initialize
      @session_path = File.join(Dir.pwd, SESSION_DIR, SESSION_FILE)
      ensure_session_directory
    end

    def create_session(task_description = nil)
      session_data = {
        session_id: generate_session_id,
        start_time: Time.now.iso8601,
        task_description: task_description,
        agents: [],
        status: 'active'
      }
      
      write_session(session_data)
      Logger.info("Created new session: #{session_data[:session_id]}")
      session_data
    end

    def add_agent(role, pid, worktree_path, task = nil)
      session = read_session
      return false unless session

      agent_data = {
        role: role,
        pid: pid,
        worktree_path: worktree_path,
        task: task,
        start_time: Time.now.iso8601,
        status: 'running'
      }

      session[:agents] << agent_data
      write_session(session)
      Logger.info("Added agent to session: #{role} (PID: #{pid})")
      true
    end

    def update_agent_status(pid, status, completion_time = nil)
      session = read_session
      return false unless session

      agent = session[:agents].find { |a| a[:pid] == pid }
      return false unless agent

      agent[:status] = status
      agent[:completion_time] = completion_time if completion_time

      write_session(session)
      Logger.info("Updated agent status: PID #{pid} -> #{status}")
      true
    end

    def remove_agent(pid)
      session = read_session
      return false unless session

      initial_count = session[:agents].length
      session[:agents].reject! { |a| a[:pid] == pid }
      
      if session[:agents].length < initial_count
        write_session(session)
        Logger.info("Removed agent from session: PID #{pid}")
        true
      else
        false
      end
    end

    def get_active_agents
      session = read_session
      return [] unless session

      session[:agents].select { |a| a[:status] == 'running' }
    end

    def get_all_agents
      session = read_session
      return [] unless session

      session[:agents] || []
    end

    def session_exists?
      File.exist?(@session_path)
    end

    def read_session
      return nil unless session_exists?

      begin
        content = File.read(@session_path)
        JSON.parse(content, symbolize_names: true)
      rescue JSON::ParserError, StandardError => e
        Logger.error("Failed to read session file: #{e.message}")
        nil
      end
    end

    def session_status
      session = read_session
      return { exists: false } unless session

      active_agents = get_active_agents
      all_agents = get_all_agents
      
      {
        exists: true,
        session_id: session[:session_id],
        start_time: session[:start_time],
        task_description: session[:task_description],
        status: session[:status],
        total_agents: all_agents.length,
        active_agents: active_agents.length,
        completed_agents: all_agents.count { |a| a[:status] == 'completed' },
        failed_agents: all_agents.count { |a| a[:status] == 'failed' },
        agents: all_agents
      }
    end

    def close_session
      session = read_session
      return false unless session

      session[:status] = 'completed'
      session[:end_time] = Time.now.iso8601
      write_session(session)
      Logger.info("Closed session: #{session[:session_id]}")
      true
    end

    def cleanup_session
      return false unless session_exists?

      # Archive the session before removing
      if archive_session
        File.delete(@session_path)
        Logger.info("Cleaned up session file")
        true
      else
        false
      end
    end

    def check_agent_processes
      session = read_session
      return [] unless session

      updated_agents = []
      session_changed = false

      session[:agents].each do |agent|
        next unless agent[:status] == 'running'

        # Check if process is still running
        if process_running?(agent[:pid])
          updated_agents << agent
        else
          # Process is no longer running, update status
          agent[:status] = 'stopped'
          agent[:completion_time] = Time.now.iso8601
          session_changed = true
          Logger.info("Agent process stopped: #{agent[:role]} (PID: #{agent[:pid]})")
        end
      end

      write_session(session) if session_changed
      updated_agents
    end

    private

    def ensure_session_directory
      session_dir = File.dirname(@session_path)
      FileUtils.mkdir_p(session_dir) unless Dir.exist?(session_dir)
    end

    def write_session(session_data)
      begin
        File.write(@session_path, JSON.pretty_generate(session_data))
        true
      rescue StandardError => e
        Logger.error("Failed to write session file: #{e.message}")
        false
      end
    end

    def generate_session_id
      Time.now.to_i.to_s + '_' + SecureRandom.hex(4)
    end

    def archive_session
      return true unless session_exists?

      begin
        session = read_session
        return false unless session

        # Create archives directory
        archive_dir = File.join(Dir.pwd, SESSION_DIR, 'archives')
        FileUtils.mkdir_p(archive_dir)

        # Create archive filename with session ID and timestamp
        archive_name = "session_#{session[:session_id]}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
        archive_path = File.join(archive_dir, archive_name)

        FileUtils.cp(@session_path, archive_path)
        Logger.info("Archived session to: #{archive_path}")
        true
      rescue StandardError => e
        Logger.error("Failed to archive session: #{e.message}")
        false
      end
    end

    def process_running?(pid)
      begin
        # Use Process.kill(0, pid) to check if process exists
        # This doesn't actually kill the process, just checks if it's running
        Process.kill(0, pid.to_i)
        true
      rescue Errno::ESRCH
        # Process doesn't exist
        false
      rescue Errno::EPERM
        # Process exists but we don't have permission to signal it
        # This means it's running but owned by another user
        true
      rescue StandardError
        # Any other error, assume process is not running
        false
      end
    end
  end
end