#!/usr/bin/env ruby
# Debug script to test agent spawning

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def test_agent_spawning
  puts "🔍 Testing Agent Spawning Debug"
  puts "=" * 50

  begin
    spawner = EnhanceSwarm::AgentSpawner.new
    
    # Test Claude CLI availability
    puts "\n1️⃣  Testing Claude CLI..."
    available = spawner.claude_cli_available?
    puts "   📊 Claude CLI available: #{available}"
    
    if available
      version = `claude --version 2>/dev/null`.strip
      puts "   📊 Claude version: #{version}"
    end
    
    # Test session manager
    puts "\n2️⃣  Testing Session Manager..."
    session_manager = EnhanceSwarm::SessionManager.new
    session = session_manager.create_session("Debug test session")
    puts "   📊 Session created: #{session[:session_id]}"
    
    # Test enhanced prompt building
    puts "\n3️⃣  Testing Enhanced Prompt Building..."
    prompt = spawner.send(:build_enhanced_agent_prompt, 
                         "Test task for debugging", 
                         "backend", 
                         Dir.pwd)
    puts "   📊 Prompt length: #{prompt.length} characters"
    puts "   📊 Contains role: #{prompt.include?('BACKEND')}"
    
    # Test script creation
    puts "\n4️⃣  Testing Agent Script Creation..."
    script_path = spawner.send(:create_agent_script, 
                              "Test prompt for script creation", 
                              "backend", 
                              Dir.pwd)
    puts "   📊 Script created: #{File.exist?(script_path)}"
    puts "   📊 Script executable: #{File.executable?(script_path)}"
    
    if File.exist?(script_path)
      script_content = File.read(script_path)
      puts "   📊 Script length: #{script_content.length} characters"
      puts "   📊 Contains claude command: #{script_content.include?('claude')}"
    end
    
    # Test the full spawn_agent method
    puts "\n5️⃣  Testing Full Agent Spawn..."
    puts "   🚀 Attempting to spawn agent..."
    
    result = spawner.spawn_agent(
      role: "backend",
      task: "Create a simple test file with hello world",
      worktree: true
    )
    
    if result
      puts "   ✅ Agent spawned successfully!"
      puts "   📊 PID: #{result[:pid]}"
      puts "   📊 Role: #{result[:role]}"
      puts "   📊 Worktree: #{result[:worktree_path]}"
      
      # Check if the process is actually running
      begin
        if result[:pid]
          running = Process.getpgid(result[:pid])
          puts "   📊 Process running: #{running ? 'Yes' : 'No'}"
        end
      rescue Errno::ESRCH
        puts "   📊 Process running: No (not found)"
      end
      
      # Wait a moment and check logs
      sleep(3)
      
      # Check log files
      puts "\n6️⃣  Checking Log Files..."
      log_dir = '.enhance_swarm/logs'
      if Dir.exist?(log_dir)
        log_files = Dir.entries(log_dir).reject { |f| f.start_with?('.') }
        log_files.each do |log_file|
          log_path = File.join(log_dir, log_file)
          content = File.read(log_path) rescue ""
          puts "   📊 #{log_file}: #{content.length} characters"
          if content.length > 0
            puts "      Preview: #{content[0..100]}..."
          end
        end
      end
    else
      puts "   ❌ Agent spawn failed"
    end
    
  rescue => e
    puts "   ❌ Error: #{e.class}: #{e.message}"
    puts "   📊 Backtrace:"
    e.backtrace.first(5).each { |line| puts "      #{line}" }
  ensure
    # Cleanup
    session_manager&.cleanup_session
  end
end

if __FILE__ == $0
  test_agent_spawning
end