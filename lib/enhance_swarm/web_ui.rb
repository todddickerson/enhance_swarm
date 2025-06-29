# frozen_string_literal: true

require 'webrick'
require 'json'
require 'erb'
require_relative 'logger'
require_relative 'orchestrator'
require_relative 'process_monitor'

module EnhanceSwarm
  class WebUI
    attr_reader :server, :port

    def initialize(port: 4567, host: 'localhost')
      @port = port
      @host = host
      @orchestrator = Orchestrator.new
      @process_monitor = ProcessMonitor.new
      setup_server
    end

    def start
      Logger.info("Starting EnhanceSwarm Web UI on http://#{@host}:#{@port}")
      puts "🌐 EnhanceSwarm Web UI starting on http://#{@host}:#{@port}".colorize(:blue)
      puts "   📋 Features: Task Management, Kanban Board, Agent Monitoring"
      puts "   🚀 Open your browser to access the interface"
      puts "   ⏹️  Press Ctrl+C to stop the server"
      
      trap 'INT' do
        puts "\n👋 Shutting down EnhanceSwarm Web UI..."
        @server.shutdown
      end

      @server.start
    end

    def stop
      @server&.shutdown
    end

    private

    def setup_server
      @server = WEBrick::HTTPServer.new(
        Port: @port,
        Host: @host,
        Logger: WEBrick::Log.new('/dev/null'),
        AccessLog: []
      )

      # Static assets
      @server.mount('/assets', WEBrick::HTTPServlet::FileHandler, assets_dir)
      
      # API endpoints
      setup_api_routes
      
      # Main UI routes
      setup_ui_routes
    end

    def setup_api_routes
      # Status API
      @server.mount_proc('/api/status') do |req, res|
        res['Content-Type'] = 'application/json'
        status_data = @process_monitor.status
        res.body = JSON.pretty_generate(status_data)
      end

      # Task management API
      @server.mount_proc('/api/tasks') do |req, res|
        res['Content-Type'] = 'application/json'
        task_data = @orchestrator.get_task_management_data
        res.body = JSON.pretty_generate(task_data)
      end

      # Agent spawn API
      @server.mount_proc('/api/agents/spawn') do |req, res|
        res['Content-Type'] = 'application/json'
        
        if req.request_method == 'POST'
          begin
            body = JSON.parse(req.body)
            role = body['role'] || 'general'
            task = body['task'] || 'General task'
            worktree = body['worktree'] || true
            
            result = @orchestrator.spawn_single(task: task, role: role, worktree: worktree)
            
            if result
              res.body = JSON.generate({ success: true, pid: result, message: "#{role.capitalize} agent spawned successfully" })
            else
              res.status = 400
              res.body = JSON.generate({ success: false, message: "Failed to spawn #{role} agent" })
            end
          rescue JSON::ParserError
            res.status = 400
            res.body = JSON.generate({ success: false, message: 'Invalid JSON in request body' })
          rescue StandardError => e
            res.status = 500
            res.body = JSON.generate({ success: false, message: e.message })
          end
        else
          res.status = 405
          res.body = JSON.generate({ success: false, message: 'Method not allowed' })
        end
      end

      # Configuration API
      @server.mount_proc('/api/config') do |req, res|
        res['Content-Type'] = 'application/json'
        config_data = EnhanceSwarm.configuration.to_h
        res.body = JSON.pretty_generate(config_data)
      end

      # Project analysis API
      @server.mount_proc('/api/project/analyze') do |req, res|
        res['Content-Type'] = 'application/json'
        
        begin
          analyzer = ProjectAnalyzer.new
          analysis = analyzer.analyze
          smart_defaults = analyzer.generate_smart_defaults
          
          res.body = JSON.pretty_generate({
            analysis: analysis,
            smart_defaults: smart_defaults
          })
        rescue StandardError => e
          res.status = 500
          res.body = JSON.generate({ error: e.message })
        end
      end
    end

    def setup_ui_routes
      # Main dashboard
      @server.mount_proc('/') do |req, res|
        res['Content-Type'] = 'text/html'
        res.body = render_template('dashboard')
      end

      # Kanban board
      @server.mount_proc('/kanban') do |req, res|
        res['Content-Type'] = 'text/html'
        res.body = render_template('kanban')
      end

      # Agent monitoring
      @server.mount_proc('/agents') do |req, res|
        res['Content-Type'] = 'text/html'
        res.body = render_template('agents')
      end

      # Project overview
      @server.mount_proc('/project') do |req, res|
        res['Content-Type'] = 'text/html'
        res.body = render_template('project')
      end

      # Configuration
      @server.mount_proc('/config') do |req, res|
        res['Content-Type'] = 'text/html'
        res.body = render_template('config')
      end
    end

    def render_template(template_name)
      template_path = File.join(templates_dir, "#{template_name}.html.erb")
      
      unless File.exist?(template_path)
        return error_template("Template not found: #{template_name}")
      end

      begin
        template = ERB.new(File.read(template_path))
        template.result(binding)
      rescue StandardError => e
        Logger.error("Template rendering error: #{e.message}")
        error_template("Template error: #{e.message}")
      end
    end

    def error_template(message)
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>EnhanceSwarm - Error</title>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
        </head>
        <body style="font-family: -apple-system, sans-serif; padding: 2rem; background: #f5f5f5;">
          <div style="max-width: 600px; margin: 0 auto; background: white; padding: 2rem; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
            <h1 style="color: #e74c3c; margin-top: 0;">⚠️ EnhanceSwarm Error</h1>
            <p style="color: #666; font-size: 1.1rem;">#{message}</p>
            <a href="/" style="display: inline-block; margin-top: 1rem; padding: 0.5rem 1rem; background: #3498db; color: white; text-decoration: none; border-radius: 4px;">← Back to Dashboard</a>
          </div>
        </body>
        </html>
      HTML
    end

    def templates_dir
      File.join(File.dirname(__FILE__), '..', '..', 'web', 'templates')
    end

    def assets_dir
      File.join(File.dirname(__FILE__), '..', '..', 'web', 'assets')
    end
  end
end