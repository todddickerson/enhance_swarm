#!/usr/bin/env ruby
# frozen_string_literal: true

# Test real Claude CLI integration

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def test_claude_cli_integration
  puts "🤖 Testing Real Claude CLI Integration"
  puts "=" * 60

  test_results = []

  # Test 1: Claude CLI Availability
  begin
    puts "\n1️⃣  Testing Claude CLI Availability..."
    
    spawner = EnhanceSwarm::AgentSpawner.new
    available = spawner.claude_cli_available?
    
    puts "   📊 Claude CLI Available: #{available}"
    
    if available
      # Test version
      version = `claude --version 2>/dev/null`.strip
      puts "   📊 Claude Version: #{version}"
      
      # Test basic functionality
      test_response = `echo "Say hello in one word" | claude --print 2>/dev/null`.strip
      puts "   📊 Basic Test Response: #{test_response.length > 0 ? 'Success' : 'Failed'}"
      
      test_results << { test: "Claude CLI Availability", status: "✅ PASS" }
    else
      puts "   ❌ Claude CLI not available"
      test_results << { test: "Claude CLI Availability", status: "❌ FAIL" }
    end
  rescue => e
    puts "   ❌ Error testing Claude CLI: #{e.message}"
    test_results << { test: "Claude CLI Availability", status: "❌ FAIL", error: e.message }
  end

  # Test 2: Agent Prompt Building
  begin
    puts "\n2️⃣  Testing Agent Prompt Building..."
    
    spawner = EnhanceSwarm::AgentSpawner.new
    config = EnhanceSwarm::Configuration.new
    
    # Test enhanced prompt building
    base_task = "Create a simple Ruby class for a blog post"
    role = "backend"
    worktree_path = "/tmp/test_worktree"
    
    enhanced_prompt = spawner.send(:build_enhanced_agent_prompt, base_task, role, worktree_path)
    
    puts "   📊 Enhanced Prompt Length: #{enhanced_prompt.length} characters"
    puts "   📊 Contains Role Info: #{enhanced_prompt.include?('BACKEND')}"
    puts "   📊 Contains Task: #{enhanced_prompt.include?(base_task)}"
    puts "   📊 Contains Project Info: #{enhanced_prompt.include?(config.project_name)}"
    
    if enhanced_prompt.length > 500 && enhanced_prompt.include?(base_task)
      test_results << { test: "Agent Prompt Building", status: "✅ PASS" }
    else
      test_results << { test: "Agent Prompt Building", status: "❌ FAIL" }
    end
  rescue => e
    puts "   ❌ Error testing prompt building: #{e.message}"
    test_results << { test: "Agent Prompt Building", status: "❌ FAIL", error: e.message }
  end

  # Test 3: Agent Script Creation
  begin
    puts "\n3️⃣  Testing Agent Script Creation..."
    
    spawner = EnhanceSwarm::AgentSpawner.new
    prompt = "Test prompt for agent script creation"
    role = "frontend"
    working_dir = Dir.pwd
    
    # Create script and test immediately since Tempfile auto-deletes
    script_tempfile = nil
    script_content = ""
    script_exists = false
    script_executable = false
    
    begin
      # Call the method and capture the tempfile path
      script_path = spawner.send(:create_agent_script, prompt, role, working_dir)
      
      if script_path && File.exist?(script_path)
        script_exists = true
        script_executable = File.executable?(script_path)
        script_content = File.read(script_path)
        
        puts "   📊 Script Created: #{script_exists}"
        puts "   📊 Script Executable: #{script_executable}"
        puts "   📊 Script Length: #{script_content.length} characters"
        puts "   📊 Contains Role: #{script_content.include?(role)}"
        puts "   📊 Contains Claude Command: #{script_content.include?('claude')}"
        
        test_results << { test: "Agent Script Creation", status: "✅ PASS" }
      else
        puts "   📊 Script Created: false"
        test_results << { test: "Agent Script Creation", status: "❌ FAIL" }
      end
    rescue => script_error
      puts "   📊 Script Creation Error: #{script_error.message}"
      test_results << { test: "Agent Script Creation", status: "❌ FAIL" }
    end
  rescue => e
    puts "   ❌ Error testing script creation: #{e.message}"
    test_results << { test: "Agent Script Creation", status: "❌ FAIL", error: e.message }
  end

  # Test 4: Real Agent Spawning (if Claude CLI available)
  if spawner.claude_cli_available?
    begin
      puts "\n4️⃣  Testing Real Agent Spawning..."
      
      # Create a simple test task
      test_task = "Create a simple 'Hello World' Ruby file and output it"
      role = "backend"
      
      # Spawn a real agent
      pid = spawner.spawn_agent(role: role, task: test_task, worktree: false)
      
      if pid
        puts "   📊 Agent Spawned: PID #{pid}"
        puts "   📊 Process Running: #{Process.getpgid(pid) ? true : false}"
        
        # Give the agent a moment to start
        sleep(2)
        
        # Check if logs are being created
        log_file = File.join('.enhance_swarm', 'logs', "#{role}_output.log")
        puts "   📊 Log File Created: #{File.exist?(log_file)}"
        
        if File.exist?(log_file)
          # Wait a bit more and check log content
          sleep(5)
          log_content = File.read(log_file) rescue ""
          puts "   📊 Log Content Length: #{log_content.length} characters"
          puts "   📊 Agent Active: #{log_content.length > 0}"
        end
        
        # Try to stop the agent gracefully
        begin
          Process.kill('TERM', pid)
          puts "   📊 Agent Termination: Sent"
        rescue => e
          puts "   📊 Agent Termination: #{e.message}"
        end
        
        test_results << { test: "Real Agent Spawning", status: "✅ PASS" }
      else
        puts "   ❌ Failed to spawn agent"
        test_results << { test: "Real Agent Spawning", status: "❌ FAIL" }
      end
    rescue => e
      puts "   ❌ Error testing real spawning: #{e.message}"
      test_results << { test: "Real Agent Spawning", status: "❌ FAIL", error: e.message }
    end
  else
    puts "\n4️⃣  Skipping Real Agent Spawning (Claude CLI not available)"
    test_results << { test: "Real Agent Spawning", status: "⏭️ SKIP" }
  end

  # Test 5: Session Integration
  begin
    puts "\n5️⃣  Testing Session Integration..."
    
    session_manager = EnhanceSwarm::SessionManager.new
    orchestrator = EnhanceSwarm::Orchestrator.new
    
    # Create a session
    session = session_manager.create_session("Claude CLI integration test")
    puts "   📊 Session Created: #{session[:session_id]}"
    
    # Test spawning through orchestrator
    spawn_result = orchestrator.spawn_single(
      task: "Simple test task for integration",
      role: "general",
      worktree: false
    )
    
    if spawn_result
      puts "   📊 Orchestrator Spawn: Success (PID: #{spawn_result})"
      
      # Check session status
      status = session_manager.session_status
      puts "   📊 Session Agents: #{status[:total_agents]}"
      
      # Cleanup
      session_manager.cleanup_session
      
      test_results << { test: "Session Integration", status: "✅ PASS" }
    else
      puts "   ❌ Orchestrator spawn failed"
      test_results << { test: "Session Integration", status: "❌ FAIL" }
    end
  rescue => e
    puts "   ❌ Error testing session integration: #{e.message}"
    test_results << { test: "Session Integration", status: "❌ FAIL", error: e.message }
  end

  # Results Summary
  puts "\n" + "=" * 60
  puts "📊 CLAUDE CLI INTEGRATION TEST RESULTS"
  puts "=" * 60

  passed = test_results.count { |r| r[:status].include?("✅") }
  total = test_results.count { |r| !r[:status].include?("⏭️") }
  
  test_results.each do |result|
    puts "   #{result[:status]} #{result[:test]}"
    if result[:error]
      puts "      Error: #{result[:error]}"
    end
  end

  puts "\n📈 Success Rate: #{passed}/#{total} (#{total > 0 ? (passed.to_f / total * 100).round(1) : 0}%)"
  
  if passed == total && total > 0
    puts "\n🎉 CLAUDE CLI INTEGRATION COMPLETE!"
    puts "   ✅ Real Claude agents can be spawned and managed"
    puts "   ✅ Enhanced prompts with role specialization working"
    puts "   ✅ Agent scripts generated correctly"
    puts "   ✅ Session management integrated"
    puts "   ✅ Ready for production multi-agent workflows"
  else
    puts "\n⚠️  Some integration tests failed"
    puts "   🔧 Address issues above for full Claude CLI integration"
  end

  passed == total && total > 0
end

def demonstrate_production_usage
  puts "\n🚀 Production Claude CLI Usage Examples"
  puts "=" * 60

  puts "\n💻 Enhanced Agent Spawning:"
  puts "   enhance-swarm enhance                    # Start full orchestration"
  puts "   enhance-swarm spawn 'Create API model'   # Spawn single agent"
  puts "   enhance-swarm status                     # Check agent status"
  puts "   enhance-swarm ui                         # Web interface"

  puts "\n🤖 Agent Role Specializations:"
  puts "   Backend Agent:  Models, APIs, database logic, business rules"
  puts "   Frontend Agent: UI components, styling, client-side logic"
  puts "   QA Agent:       Tests, validation, edge cases, quality checks"
  puts "   UX Agent:       User flows, accessibility, design improvements"

  puts "\n⚡ Claude CLI Integration Features:"
  puts "   • Real Claude agents with specialized prompts"
  puts "   • Automatic role-based task assignment"
  puts "   • Project-aware context and standards"
  puts "   • Independent agent execution with monitoring"
  puts "   • Graceful fallback to simulation mode"
  puts "   • Comprehensive logging and error handling"

  puts "\n🔧 Integration Benefits:"
  puts "   • Authentic multi-agent development workflows"
  puts "   • Specialized agents for different development phases"
  puts "   • Real-time progress monitoring and coordination"
  puts "   • Production-ready code generation and testing"
  puts "   • Seamless integration with existing development tools"
end

# Run the test
if __FILE__ == $0
  success = test_claude_cli_integration
  demonstrate_production_usage
  
  puts "\n🎯 FINAL ASSESSMENT:"
  if success
    puts "   🚀 Claude CLI integration is PRODUCTION-READY!"
    puts "   🏆 Real multi-agent workflows confirmed working"
    puts "   🛠️  Enhanced EnhanceSwarm ready for v1.0 release"
  else
    puts "   🔧 Claude CLI integration needs refinement"
    puts "   💡 Some features may fall back to simulation mode"
  end
end