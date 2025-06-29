#!/usr/bin/env ruby
# Debug CLI spawn command integration

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'
require 'fileutils'

def test_cli_spawn_integration
  puts "🔧 Testing CLI Spawn Integration"
  puts "=" * 50

  begin
    # Test with enhanced debugging
    ENV['ENHANCE_SWARM_DEBUG'] = 'true'
    
    puts "\n1️⃣  Testing CLI Components..."
    
    # Test configuration
    config = EnhanceSwarm.configuration
    puts "   📊 Configuration loaded: #{config.project_name}"
    
    # Test orchestrator initialization
    orchestrator = EnhanceSwarm::Orchestrator.new
    puts "   📊 Orchestrator initialized: #{orchestrator.class}"
    
    # Test agent spawner directly
    agent_spawner = EnhanceSwarm::AgentSpawner.new
    puts "   📊 AgentSpawner initialized: #{agent_spawner.class}"
    puts "   📊 Claude CLI available: #{agent_spawner.claude_cli_available?}"
    
    puts "\n2️⃣  Testing Direct AgentSpawner Call..."
    
    # Test direct spawner call with debugging
    result = agent_spawner.spawn_agent(
      role: "frontend",
      task: "Create a simple test component",
      worktree: true
    )
    
    puts "   📊 Direct spawn result: #{result.inspect}"
    
    puts "\n3️⃣  Testing Orchestrator spawn_single..."
    
    # Test orchestrator spawn_single
    orchestrator_result = orchestrator.spawn_single(
      task: "Create a simple test component",
      role: "frontend", 
      worktree: true
    )
    
    puts "   📊 Orchestrator result: #{orchestrator_result.inspect}"
    
    puts "\n4️⃣  Testing Session Manager..."
    
    # Test session manager
    session_manager = EnhanceSwarm::SessionManager.new
    session = session_manager.create_session("Debug test session")
    puts "   📊 Session created: #{session.inspect}"
    
    # Check session status
    status = session_manager.session_status
    puts "   📊 Session status: #{status.inspect}"
    
    puts "\n5️⃣  Checking Error Logs..."
    
    # Check for error logs
    log_dir = '.enhance_swarm/logs'
    if Dir.exist?(log_dir)
      log_files = Dir.entries(log_dir).reject { |f| f.start_with?('.') }
      log_files.each do |log_file|
        log_path = File.join(log_dir, log_file)
        content = File.read(log_path) rescue ""
        if content.length > 0
          puts "   📊 #{log_file}: #{content.length} characters"
          puts "      Last 200 chars: #{content[-200..-1]}"
        else
          puts "   📊 #{log_file}: empty"
        end
      end
    end
    
  rescue => e
    puts "   ❌ Error: #{e.class}: #{e.message}"
    puts "   📊 Backtrace:"
    e.backtrace.first(5).each { |line| puts "      #{line}" }
  ensure
    # Cleanup
    session_manager&.cleanup_session
    ENV.delete('ENHANCE_SWARM_DEBUG')
  end
end

if __FILE__ == $0
  test_cli_spawn_integration
end