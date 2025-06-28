# frozen_string_literal: true

require 'json'

module EnhanceSwarm
  class NotificationManager
    NOTIFICATION_TYPES = {
      agent_completed: { priority: :high, desktop: true, sound: true },
      agent_failed: { priority: :critical, desktop: true, sound: true },
      agent_stuck: { priority: :high, desktop: true, sound: false },
      coordination_complete: { priority: :medium, desktop: true, sound: true },
      intervention_needed: { priority: :critical, desktop: true, sound: true },
      progress_milestone: { priority: :low, desktop: false, sound: false }
    }.freeze

    def initialize
      @enabled = true
      @desktop_notifications = desktop_notifications_available?
      @sound_enabled = sound_available?
      @notification_history = []
    end

    def notify(type, message, details = {})
      return unless @enabled
      
      notification = build_notification(type, message, details)
      @notification_history << notification
      
      # Console notification (always shown)
      display_console_notification(notification)
      
      # Desktop notification (if available and configured)
      if should_show_desktop?(notification)
        send_desktop_notification(notification)
      end
      
      # Sound notification (if available and configured)
      if should_play_sound?(notification)
        play_notification_sound(notification[:priority])
      end
      
      # Log for automation tools
      Logger.log_operation("notification_#{type}", 'sent', {
        message: message,
        priority: notification[:priority],
        details: details
      })
      
      notification
    end

    def agent_completed(agent_id, role, duration, details = {})
      message = "🎉 Agent '#{role}' completed successfully!"
      
      notify(:agent_completed, message, {
        agent_id: agent_id,
        role: role,
        duration: duration,
        **details
      })
      
      if details[:output_path]
        puts "   View: enhance-swarm show #{agent_id}".colorize(:blue)
      end
    end

    def agent_failed(agent_id, role, error, suggestions = [])
      message = "❌ Agent '#{role}' failed: #{error}"
      
      notify(:agent_failed, message, {
        agent_id: agent_id,
        role: role,
        error: error,
        suggestions: suggestions
      })
      
      if suggestions.any?
        puts "\n💡 Quick fixes:".colorize(:yellow)
        suggestions.each_with_index do |suggestion, index|
          puts "  #{index + 1}. #{suggestion}".colorize(:yellow)
        end
        puts "\nChoose [1-#{suggestions.length}] or [c]ustom command:".colorize(:yellow)
      end
    end

    def agent_stuck(agent_id, role, last_activity, current_task = nil)
      time_stuck = Time.now - last_activity
      time_str = format_duration(time_stuck)
      
      message = "⚠️ Agent '#{role}' stuck for #{time_str}"
      
      notify(:agent_stuck, message, {
        agent_id: agent_id,
        role: role,
        last_activity: last_activity,
        time_stuck: time_stuck,
        current_task: current_task
      })
      
      puts "   Last activity: #{current_task || 'Unknown'}".colorize(:yellow)
      puts "   Action: enhance-swarm restart #{agent_id} [y/N]?".colorize(:blue)
    end

    def coordination_complete(summary)
      total_agents = summary[:completed] + summary[:failed]
      message = "✅ Coordination complete: #{summary[:completed]}/#{total_agents} agents succeeded"
      
      notify(:coordination_complete, message, summary)
      
      if summary[:failed] > 0
        puts "\n⚠️ #{summary[:failed]} agent(s) failed. Review with: enhance-swarm review".colorize(:yellow)
      end
    end

    def intervention_needed(reason, agent_id = nil, suggestions = [])
      message = "🚨 Intervention needed: #{reason}"
      
      notify(:intervention_needed, message, {
        reason: reason,
        agent_id: agent_id,
        suggestions: suggestions
      })
      
      if suggestions.any?
        puts "\nRecommended actions:".colorize(:red)
        suggestions.each_with_index do |suggestion, index|
          puts "  #{index + 1}. #{suggestion}".colorize(:red)
        end
      end
    end

    def progress_milestone(milestone, progress_percentage, eta = nil)
      message = "📍 #{milestone} (#{progress_percentage}% complete)"
      
      notify(:progress_milestone, message, {
        milestone: milestone,
        progress: progress_percentage,
        eta: eta
      })
      
      if eta
        puts "   ETA: #{eta.strftime('%H:%M:%S')}".colorize(:blue)
      end
    end

    # Background monitoring for stuck agents
    def start_monitoring(agents)
      return if @monitoring_thread&.alive?
      
      @monitoring_thread = Thread.new do
        monitor_agents(agents)
      end
    end

    def stop_monitoring
      @monitoring_thread&.kill
      @monitoring_thread = nil
    end

    # Enable/disable notifications
    def enable!
      @enabled = true
      puts "✅ Notifications enabled".colorize(:green)
    end

    def disable!
      @enabled = false
      puts "🔇 Notifications disabled".colorize(:yellow)
    end

    def enabled?
      @enabled
    end

    # Notification history
    def recent_notifications(limit = 10)
      @notification_history.last(limit)
    end

    def clear_history
      @notification_history.clear
    end

    private

    def build_notification(type, message, details)
      config = NOTIFICATION_TYPES[type] || { priority: :medium, desktop: false, sound: false }
      
      {
        type: type,
        message: message,
        details: details,
        priority: config[:priority],
        desktop: config[:desktop],
        sound: config[:sound],
        timestamp: Time.now
      }
    end

    def display_console_notification(notification)
      priority_colors = {
        critical: :red,
        high: :yellow,
        medium: :blue,
        low: :light_black
      }
      
      color = priority_colors[notification[:priority]] || :white
      timestamp = notification[:timestamp].strftime('%H:%M:%S')
      
      puts "[#{timestamp}] #{notification[:message]}".colorize(color)
    end

    def should_show_desktop?(notification)
      @desktop_notifications && notification[:desktop] && notification[:priority] != :low
    end

    def should_play_sound?(notification)
      @sound_enabled && notification[:sound] && [:critical, :high].include?(notification[:priority])
    end

    def send_desktop_notification(notification)
      return unless @desktop_notifications
      
      case RbConfig::CONFIG['host_os']
      when /darwin/ # macOS
        send_macos_notification(notification)
      when /linux/ # Linux
        send_linux_notification(notification)
      when /mswin|mingw|cygwin/ # Windows
        send_windows_notification(notification)
      end
    rescue StandardError => e
      Logger.warn("Failed to send desktop notification: #{e.message}")
    end

    def send_macos_notification(notification)
      title = "EnhanceSwarm"
      subtitle = notification[:type].to_s.humanize
      message = notification[:message]
      
      # Use macOS osascript for notifications
      script = <<~APPLESCRIPT
        display notification "#{message}" with title "#{title}" subtitle "#{subtitle}"
      APPLESCRIPT
      
      CommandExecutor.execute('osascript', '-e', script)
    end

    def send_linux_notification(notification)
      # Use notify-send if available
      if CommandExecutor.command_available?('notify-send')
        CommandExecutor.execute(
          'notify-send', 
          'EnhanceSwarm', 
          notification[:message],
          '--urgency=normal'
        )
      end
    end

    def send_windows_notification(notification)
      # Use PowerShell toast notifications
      if CommandExecutor.command_available?('powershell')
        script = <<~POWERSHELL
          [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
          $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
          $template.SelectSingleNode('//text[@id="1"]').AppendChild($template.CreateTextNode('EnhanceSwarm'))
          $template.SelectSingleNode('//text[@id="2"]').AppendChild($template.CreateTextNode('#{notification[:message]}'))
          $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
          [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('EnhanceSwarm').Show($toast)
        POWERSHELL
        
        CommandExecutor.execute('powershell', '-Command', script)
      end
    end

    def play_notification_sound(priority)
      return unless @sound_enabled
      
      case RbConfig::CONFIG['host_os']
      when /darwin/ # macOS
        sound = priority == :critical ? 'Basso' : 'Ping'
        CommandExecutor.execute('afplay', "/System/Library/Sounds/#{sound}.aiff")
      when /linux/ # Linux
        if CommandExecutor.command_available?('paplay')
          # Use default system sound
          CommandExecutor.execute('paplay', '/usr/share/sounds/alsa/Front_Left.wav')
        elsif CommandExecutor.command_available?('aplay')
          CommandExecutor.execute('aplay', '/usr/share/sounds/alsa/Front_Left.wav')
        end
      end
    rescue StandardError => e
      Logger.debug("Failed to play notification sound: #{e.message}")
    end

    def monitor_agents(agents)
      while @enabled
        agents.each do |agent|
          check_agent_health(agent)
        end
        
        sleep(30) # Check every 30 seconds
      end
    rescue StandardError => e
      Logger.error("Agent monitoring error: #{e.message}")
    end

    def check_agent_health(agent)
      # Check if agent process is still running
      unless process_running?(agent[:pid])
        agent_failed(agent[:id], agent[:role], "Process terminated unexpectedly")
        return
      end
      
      # Check for stuck agents (no activity for >10 minutes)
      if agent[:last_activity] && (Time.now - agent[:last_activity]) > 600
        agent_stuck(agent[:id], agent[:role], agent[:last_activity], agent[:current_task])
      end
      
      # Check for excessive memory usage
      if agent[:memory_mb] && agent[:memory_mb] > 1000
        intervention_needed(
          "Agent '#{agent[:role]}' using excessive memory (#{agent[:memory_mb]}MB)",
          agent[:id],
          ["enhance-swarm restart #{agent[:id]}", "enhance-swarm kill #{agent[:id]}"]
        )
      end
    end

    def process_running?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true # Process exists but we can't signal it
    end

    def desktop_notifications_available?
      case RbConfig::CONFIG['host_os']
      when /darwin/
        CommandExecutor.command_available?('osascript')
      when /linux/
        CommandExecutor.command_available?('notify-send')
      when /mswin|mingw|cygwin/
        CommandExecutor.command_available?('powershell')
      else
        false
      end
    end

    def sound_available?
      case RbConfig::CONFIG['host_os']
      when /darwin/
        CommandExecutor.command_available?('afplay')
      when /linux/
        CommandExecutor.command_available?('paplay') || CommandExecutor.command_available?('aplay')
      else
        false
      end
    end

    def format_duration(seconds)
      if seconds < 60
        "#{seconds.round}s"
      elsif seconds < 3600
        "#{(seconds / 60).round}m"
      else
        "#{(seconds / 3600).round(1)}h"
      end
    end

    # Class methods for global access
    def self.instance
      @instance ||= new
    end

    def self.notify(*args)
      instance.notify(*args)
    end

    def self.agent_completed(*args)
      instance.agent_completed(*args)
    end

    def self.agent_failed(*args)
      instance.agent_failed(*args)
    end

    def self.agent_stuck(*args)
      instance.agent_stuck(*args)
    end

    def self.coordination_complete(*args)
      instance.coordination_complete(*args)
    end

    def self.intervention_needed(*args)
      instance.intervention_needed(*args)
    end

    def self.progress_milestone(*args)
      instance.progress_milestone(*args)
    end
  end
end