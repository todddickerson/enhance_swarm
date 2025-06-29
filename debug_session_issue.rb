#!/usr/bin/env ruby
# Debug session manager issue

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def debug_session_issue
  puts "🔧 Debugging Session Manager Issue"
  puts "=" * 40

  begin
    # Test session manager
    puts "\n1️⃣  Testing SessionManager..."
    session_manager = EnhanceSwarm::SessionManager.new
    puts "   ✅ SessionManager initialized"
    
    # Check if session exists
    puts "\n2️⃣  Checking session existence..."
    session_exists = session_manager.session_exists?
    puts "   📊 Session exists: #{session_exists}"
    
    if session_exists
      session = session_manager.read_session
      puts "   📊 Current session: #{session[:session_id]}"
    else
      puts "   📊 No active session found"
    end
    
    # Try to create a session
    puts "\n3️⃣  Creating session..."
    session = session_manager.create_session("Debug test session")
    puts "   📊 Session created: #{session[:session_id]}"
    
    # Test add_agent
    puts "\n4️⃣  Testing add_agent..."
    success = session_manager.add_agent("frontend", 12345, "/tmp/test", "Test task")
    puts "   📊 add_agent result: #{success}"
    
    if success
      puts "   ✅ Agent added successfully"
      
      # Check session status
      status = session_manager.session_status
      puts "   📊 Session status: #{status}"
    else
      puts "   ❌ Failed to add agent"
    end
    
    # Test direct spawn_agent with session
    puts "\n5️⃣  Testing AgentSpawner with session..."
    spawner = EnhanceSwarm::AgentSpawner.new
    
    # Ensure session exists for spawner
    unless spawner.instance_variable_get(:@session_manager).session_exists?
      spawner.instance_variable_get(:@session_manager).create_session("Spawner test session")
      puts "   📊 Created session for spawner"
    end
    
    result = spawner.spawn_agent(
      role: "frontend",
      task: "Create test component", 
      worktree: false  # Skip worktree to simplify
    )
    
    puts "   📊 spawn_agent result: #{result}"
    
    if result
      puts "   ✅ Agent spawned successfully"
      puts "   📊 PID: #{result[:pid]}"
      puts "   📊 Role: #{result[:role]}"
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
  debug_session_issue
end