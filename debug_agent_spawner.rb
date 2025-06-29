#!/usr/bin/env ruby
# Debug the specific AgentSpawner.spawn_agent method

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def test_agent_spawner_directly
  puts "🔧 Testing AgentSpawner.spawn_agent Directly"
  puts "=" * 50

  begin
    # Test the actual spawn_agent method step by step
    spawner = EnhanceSwarm::AgentSpawner.new
    
    puts "\n1️⃣  Testing AgentSpawner Components..."
    
    # Test Claude CLI availability
    claude_available = spawner.claude_cli_available?
    puts "   📊 Claude CLI available: #{claude_available}"
    
    # Test session manager
    session_manager = EnhanceSwarm::SessionManager.new
    session = session_manager.create_session("Debug test")
    puts "   📊 Session created: #{session[:session_id]}"
    
    puts "\n2️⃣  Testing spawn_agent Method..."
    
    # Call spawn_agent with debug info
    puts "   🚀 Calling spawn_agent..."
    
    result = spawner.spawn_agent(
      role: "backend",
      task: "Create a simple debug test file",
      worktree: true
    )
    
    puts "   📊 Spawn result: #{result.inspect}"
    
    if result
      puts "   ✅ Agent spawned successfully!"
      puts "   📊 PID: #{result[:pid]}"
      puts "   📊 Role: #{result[:role]}"
      puts "   📊 Worktree: #{result[:worktree_path]}"
      
      # Check if process is running
      begin
        Process.getpgid(result[:pid])
        puts "   📊 Process confirmed running"
        
        # Wait a bit and check logs
        sleep(3)
        puts "   📊 Waiting 3 seconds for agent to work..."
        
        # Check session status
        session_status = session_manager.session_status
        puts "   📊 Session agents: #{session_status[:total_agents]}"
        
        # Check logs
        log_dir = '.enhance_swarm/logs'
        if Dir.exist?(log_dir)
          log_files = Dir.entries(log_dir).reject { |f| f.start_with?('.') }
          log_files.each do |log_file|
            next if log_file.include?('debug') # Skip our debug logs
            log_path = File.join(log_dir, log_file)
            content = File.read(log_path) rescue ""
            puts "   📊 #{log_file}: #{content.length} characters"
            if content.length > 0
              puts "      Preview: #{content[0..100]}..."
            end
          end
        end
        
      rescue Errno::ESRCH
        puts "   📊 Process completed quickly"
      end
      
    else
      puts "   ❌ Agent spawn returned false"
    end
    
    # Check worktree status
    puts "\n3️⃣  Checking Worktree Status..."
    worktrees = `git worktree list 2>/dev/null`
    puts "   📊 Active worktrees:"
    worktrees.each_line { |line| puts "      #{line.strip}" }
    
  rescue => e
    puts "   ❌ Error: #{e.class}: #{e.message}"
    puts "   📊 Backtrace:"
    e.backtrace.first(5).each { |line| puts "      #{line}" }
  ensure
    # Cleanup session
    session_manager&.cleanup_session
  end
end

if __FILE__ == $0
  test_agent_spawner_directly
end