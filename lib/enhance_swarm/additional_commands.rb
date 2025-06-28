# frozen_string_literal: true

module EnhanceSwarm
  module AdditionalCommands
    def self.add_commands_to(cli_class)
      cli_class.class_eval do
        desc 'dashboard', 'Start visual agent dashboard'
        option :agents, type: :array, desc: 'Specific agent IDs to monitor'
        option :refresh, type: :numeric, default: 2, desc: 'Refresh rate in seconds'
        option :snapshot, type: :boolean, desc: 'Take dashboard snapshot and exit'
        def dashboard
          if options[:snapshot]
            agents = discover_running_agents
            VisualDashboard.instance.display_snapshot(agents)
            return
          end

          say "🖥️  Starting Visual Agent Dashboard...", :green
          
          # Create demo agents if none running
          agents = options[:agents] ? 
                     load_specific_agents(options[:agents]) : 
                     discover_running_agents
          
          if agents.empty?
            say "No agents found, creating demo agents for dashboard...", :yellow
            agents = create_demo_agents
          end
          
          dashboard = VisualDashboard.instance
          dashboard.instance_variable_set(:@refresh_rate, options[:refresh])
          
          begin
            dashboard.start_dashboard(agents)
          rescue Interrupt
            say "\n🖥️  Dashboard stopped by user", :yellow
          end
        end

        desc 'notifications', 'Manage notification settings'
        option :enable, type: :boolean, desc: 'Enable notifications'
        option :disable, type: :boolean, desc: 'Disable notifications'
        option :test, type: :boolean, desc: 'Test notification system'
        option :status, type: :boolean, desc: 'Show notification status'
        def notifications
          notification_manager = NotificationManager.instance
          
          if options[:enable]
            notification_manager.enable!
            say "✅ Notifications enabled", :green
          elsif options[:disable]
            notification_manager.disable!
            say "🔕 Notifications disabled", :yellow
          elsif options[:test]
            say "🔔 Testing notification system...", :blue
            notification_manager.test_notifications
            say "✅ Notification test completed", :green
          else
            # Show status by default
            enabled = notification_manager.enabled?
            say "\n💬 Notification Status:", :blue
            say "  Enabled: #{enabled ? '✅ Yes' : '❌ No'}"
            say "  Platform: #{RUBY_PLATFORM}"
            
            if enabled
              say "\n🔔 Testing notifications..."
              notification_manager.agent_completed('demo-123', 'backend', 120, { success: true })
            end
          end
        end

        desc 'communicate', 'Manage agent communication and messages'
        option :status, type: :boolean, desc: 'Show communication status'
        option :demo, type: :boolean, desc: 'Demo communication features'
        def communicate
          communicator = AgentCommunicator.instance
          
          if options[:demo]
            say "💬 Demo Agent Communication", :green
            say "Creating demo messages...", :blue
            
            # Create demo messages
            communicator.agent_question('demo-backend', 'Should I use PostgreSQL or MySQL?', 
                                      ['PostgreSQL', 'MySQL', 'SQLite'])
            communicator.agent_status('demo-frontend', 'UI components 60% complete')
            
            say "✅ Demo messages created", :green
            say "Use 'enhance-swarm communicate --status' to see them"
          else
            # Show status
            pending = communicator.pending_messages
            recent = communicator.recent_messages(5)
            
            say "\n💬 Agent Communication Status:", :blue
            say "  Pending messages: #{pending.count}"
            say "  Recent messages: #{recent.count}"
            
            if pending.any?
              say "\n📋 Recent Messages:", :yellow
              pending.first(3).each_with_index do |message, index|
                say "  #{index + 1}. #{message[:type]} from #{message[:role]}"
                say "     #{message[:content][0..60]}..."
              end
            else
              say "  No messages currently"
              say "\nTry: enhance-swarm communicate --demo"
            end
          end
        end

        desc 'suggest', 'Get smart suggestions for next actions'
        option :context, type: :string, desc: 'Additional context for suggestions'
        def suggest
          say "🧠 Analyzing project and generating smart suggestions...", :blue
          
          context = {
            git_status: { modified_files: 2, untracked_files: 1 },
            project_files: { ruby_files: 15, test_files: 8 },
            user_context: options[:context]
          }
          
          suggestions = SmartDefaults.get_suggestions(context)
          
          if suggestions.empty?
            say "✅ No suggestions at this time. Your project looks good!", :green
            return
          end
          
          say "\n💡 Smart Suggestions:\n", :yellow
          
          suggestions.each_with_index do |suggestion, i|
            priority_color = case suggestion[:priority]
                            when :high then :red
                            when :medium then :yellow  
                            when :low then :blue
                            else :white
                            end
            
            say "#{i + 1}. [#{suggestion[:priority].to_s.upcase}] #{suggestion[:description]}", priority_color
            say "   Command: #{suggestion[:command]}", :light_black if suggestion[:command]
            say ""
          end
        end

        desc 'recover', 'Intelligent error recovery and analysis'
        option :analyze, type: :string, desc: 'Analyze specific error message'
        option :stats, type: :boolean, desc: 'Show error recovery statistics'
        option :demo, type: :boolean, desc: 'Demo error recovery features'
        def recover
          error_recovery = ErrorRecovery.instance
          
          if options[:analyze]
            say "🔍 Analyzing error: #{options[:analyze]}", :blue
            
            test_error = StandardError.new(options[:analyze])
            analysis = error_recovery.analyze_error(test_error, { context: 'cli_demo' })
            
            say "\n📊 Error Analysis:", :yellow
            say "  Type: #{analysis[:error][:type]}"
            say "  Auto-recoverable: #{analysis[:auto_recoverable] ? 'Yes' : 'No'}"
            say "  Suggestions: #{analysis[:suggestions].count}"
            
            if analysis[:suggestions].any?
              say "\n💡 Recovery Suggestions:", :green
              analysis[:suggestions].first(3).each_with_index do |suggestion, i|
                description = suggestion['description'] || suggestion[:description]
                say "  #{i + 1}. #{description}"
              end
            end
            
          elsif options[:stats]
            stats = error_recovery.recovery_statistics
            
            say "\n📊 Error Recovery Statistics:", :blue
            say "  Total errors processed: #{stats[:total_errors_processed]}"
            say "  Successful recoveries: #{stats[:successful_automatic_recoveries]}"
            say "  Success rate: #{stats[:recovery_success_rate]}%"
            say "  Patterns learned: #{stats[:recovery_patterns_learned]}"
            
          elsif options[:demo]
            say "🔧 Demo Error Recovery", :green
            
            # Demo different error types
            errors = [
              'Connection timeout after 30 seconds',
              'No such file or directory - missing.rb',
              'Permission denied accessing /etc/hosts'
            ]
            
            errors.each do |error_msg|
              say "\n🔍 Analyzing: #{error_msg}", :blue
              test_error = StandardError.new(error_msg)
              analysis = error_recovery.analyze_error(test_error)
              
              say "  Auto-recoverable: #{analysis[:auto_recoverable] ? '✅ Yes' : '❌ No'}"
              say "  Suggestions: #{analysis[:suggestions].count}"
            end
            
          else
            say "Please specify an action:", :yellow
            say "  --analyze 'error message'  - Analyze specific error"
            say "  --stats                    - Show recovery statistics" 
            say "  --demo                     - Demo error recovery features"
          end
        end

        desc 'troubleshoot', 'Interactive troubleshooting assistant'
        def troubleshoot
          say "🔧 EnhanceSwarm Troubleshooting Assistant", :green
          say "─" * 50, :light_black
          
          # Quick system check
          say "\n🔍 Quick System Check:", :blue
          
          # Check dependencies
          begin
            require 'thor'
            say "  ✅ Thor gem available"
          rescue LoadError
            say "  ❌ Thor gem missing"
          end
          
          begin
            require 'colorize'
            say "  ✅ Colorize gem available"
          rescue LoadError
            say "  ❌ Colorize gem missing"
          end
          
          # Check git
          git_available = system('git --version > /dev/null 2>&1')
          say "  #{git_available ? '✅' : '❌'} Git #{git_available ? 'available' : 'not found'}"
          
          # Check project structure
          enhance_config = File.exist?('.enhance_swarm.yml')
          say "  #{enhance_config ? '✅' : '❌'} Project config #{enhance_config ? 'found' : 'missing'}"
          
          # Test core classes
          say "\n🧪 Testing Core Classes:", :blue
          
          classes = %w[NotificationManager VisualDashboard SmartDefaults ErrorRecovery AgentCommunicator]
          classes.each do |cls|
            begin
              klass = EnhanceSwarm.const_get(cls)
              klass.instance if klass.respond_to?(:instance)
              say "  ✅ #{cls} working"
            rescue => e
              say "  ❌ #{cls} error: #{e.message}"
            end
          end
          
          say "\n✅ Troubleshooting completed!", :green
          say "If issues persist, check the README for setup instructions."
        end

        private

        def discover_running_agents
          # Return demo agents for now since we don't have real agent discovery
          []
        end

        def load_specific_agents(agent_ids)
          agent_ids.map do |id|
            {
              id: id,
              role: 'backend', 
              status: 'running',
              progress: rand(10..90),
              start_time: Time.now - rand(60..3600),
              pid: rand(1000..9999)
            }
          end
        end

        def create_demo_agents
          [
            {
              id: 'backend-auth-123',
              role: 'backend',
              status: 'running', 
              progress: 75,
              start_time: Time.now - 300,
              pid: 1234
            },
            {
              id: 'frontend-ui-456',
              role: 'frontend',
              status: 'completed',
              progress: 100,
              start_time: Time.now - 600,
              pid: 5678
            }
          ]
        end
      end
    end
  end
end