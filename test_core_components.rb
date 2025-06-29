#!/usr/bin/env ruby
# Simple test runner for core components

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def test_core_functionality
  puts "🧪 Testing Core Components"
  puts "=" * 50

  results = []

  # Test 1: Configuration initialization
  puts "\n1️⃣  Testing Configuration..."
  begin
    config = EnhanceSwarm::Configuration.new
    if config.respond_to?(:project_name) && config.respond_to?(:max_concurrent_agents)
      puts "   ✅ Configuration initialized successfully"
      results << { test: "Configuration", status: "✅ PASS" }
    else
      puts "   ❌ Configuration missing required attributes"
      results << { test: "Configuration", status: "❌ FAIL" }
    end
  rescue => e
    puts "   ❌ Configuration failed: #{e.message}"
    results << { test: "Configuration", status: "❌ ERROR" }
  end

  # Test 2: ResourceManager functionality
  puts "\n2️⃣  Testing ResourceManager..."
  begin
    resource_manager = EnhanceSwarm::ResourceManager.new
    result = resource_manager.can_spawn_agent?
    
    if result.is_a?(Hash) && result.key?(:allowed) && result.key?(:reasons)
      puts "   ✅ ResourceManager can_spawn_agent? working"
      
      stats = resource_manager.get_resource_stats
      if stats.is_a?(Hash) && stats.key?(:active_agents)
        puts "   ✅ ResourceManager get_resource_stats working"
        results << { test: "ResourceManager", status: "✅ PASS" }
      else
        puts "   ❌ ResourceManager stats malformed"
        results << { test: "ResourceManager", status: "❌ FAIL" }
      end
    else
      puts "   ❌ ResourceManager can_spawn_agent? malformed response"
      results << { test: "ResourceManager", status: "❌ FAIL" }
    end
  rescue => e
    puts "   ❌ ResourceManager failed: #{e.message}"
    results << { test: "ResourceManager", status: "❌ ERROR" }
  end

  # Test 3: SessionManager functionality
  puts "\n3️⃣  Testing SessionManager..."
  begin
    session_manager = EnhanceSwarm::SessionManager.new
    
    # Test session creation
    session = session_manager.create_session("Test session")
    if session.is_a?(Hash) && session[:session_id]
      puts "   ✅ SessionManager create_session working"
      
      # Test agent addition
      result = session_manager.add_agent('backend', 12345, '/tmp/test', 'Test task')
      if result == true
        puts "   ✅ SessionManager add_agent working"
        
        # Test agent retrieval
        agents = session_manager.get_all_agents
        if agents.is_a?(Array) && agents.length == 1
          puts "   ✅ SessionManager get_all_agents working"
          results << { test: "SessionManager", status: "✅ PASS" }
        else
          puts "   ❌ SessionManager get_all_agents failed"
          results << { test: "SessionManager", status: "❌ FAIL" }
        end
      else
        puts "   ❌ SessionManager add_agent failed"
        results << { test: "SessionManager", status: "❌ FAIL" }
      end
    else
      puts "   ❌ SessionManager create_session failed"
      results << { test: "SessionManager", status: "❌ FAIL" }
    end
    
    # Cleanup
    session_manager.cleanup_session if session_manager.session_exists?
  rescue => e
    puts "   ❌ SessionManager failed: #{e.message}"
    results << { test: "SessionManager", status: "❌ ERROR" }
  end

  # Test 4: AgentSpawner input sanitization
  puts "\n4️⃣  Testing AgentSpawner Security..."
  begin
    spawner = EnhanceSwarm::AgentSpawner.new
    
    # Test task sanitization
    dangerous_task = 'test`rm -rf /`; echo $PATH'
    safe_task = spawner.send(:sanitize_task_description, dangerous_task)
    
    if !safe_task.include?('`') && !safe_task.include?(';') && !safe_task.include?('$')
      puts "   ✅ Task sanitization working"
      
      # Test role sanitization
      safe_role = spawner.send(:sanitize_role, 'unknown_role')
      if safe_role == 'general'
        puts "   ✅ Role sanitization working"
        results << { test: "AgentSpawner Security", status: "✅ PASS" }
      else
        puts "   ❌ Role sanitization failed"
        results << { test: "AgentSpawner Security", status: "❌ FAIL" }
      end
    else
      puts "   ❌ Task sanitization failed"
      results << { test: "AgentSpawner Security", status: "❌ FAIL" }
    end
  rescue => e
    puts "   ❌ AgentSpawner Security failed: #{e.message}"
    results << { test: "AgentSpawner Security", status: "❌ ERROR" }
  end

  # Results summary
  puts "\n" + "=" * 50
  puts "🧪 CORE COMPONENT TEST RESULTS"
  puts "=" * 50

  passed = results.count { |r| r[:status].include?("✅") }
  total = results.length
  
  results.each do |result|
    puts "   #{result[:status]} #{result[:test]}"
  end

  puts "\n📊 Test Success Rate: #{passed}/#{total} (#{total > 0 ? (passed.to_f / total * 100).round(1) : 0}%)"
  
  if passed == total && total > 0
    puts "\n🎉 ALL CORE COMPONENT TESTS PASSED!"
    puts "   ✅ Configuration system working"
    puts "   ✅ Resource management working"  
    puts "   ✅ Session management working"
    puts "   ✅ Security features working"
  else
    puts "\n⚠️  SOME TESTS FAILED!"
    puts "   Review failed tests and address issues"
  end
  
  passed == total && total > 0
end

if __FILE__ == $0
  success = test_core_functionality
  exit(success ? 0 : 1)
end