#!/usr/bin/env ruby
# Debug agent script execution

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def test_script_execution
  puts "🔧 Testing Agent Script Execution"
  puts "=" * 50

  begin
    spawner = EnhanceSwarm::AgentSpawner.new
    
    # Test script creation
    puts "\n1️⃣  Creating Agent Script..."
    script_path = spawner.send(:create_agent_script, 
                              "Test prompt for debugging", 
                              "backend", 
                              Dir.pwd)
    
    puts "   📊 Script path: #{script_path}"
    puts "   📊 Script exists: #{File.exist?(script_path)}"
    puts "   📊 Script executable: #{File.executable?(script_path)}"
    
    if File.exist?(script_path)
      content = File.read(script_path)
      puts "   📊 Script content length: #{content.length}"
      puts "\n   📋 Script Content Preview:"
      puts content.lines.first(10).map.with_index { |line, i| "      #{i+1}: #{line}" }.join
      
      # Test manual execution
      puts "\n2️⃣  Testing Manual Script Execution..."
      
      begin
        # Try to execute the script manually
        result = `bash #{script_path} 2>&1`
        exit_status = $?.exitstatus
        
        puts "   📊 Exit status: #{exit_status}"
        puts "   📊 Output length: #{result.length}"
        puts "   📊 Output preview: #{result[0..200]}..." if result.length > 0
        
        if exit_status == 0
          puts "   ✅ Script executed successfully"
        else
          puts "   ❌ Script execution failed"
          puts "   📊 Full output: #{result}" if result.length < 500
        end
        
      rescue => e
        puts "   ❌ Script execution error: #{e.message}"
      end
      
      # Test Claude CLI directly
      puts "\n3️⃣  Testing Claude CLI Directly..."
      
      claude_test = `echo "Hello, test prompt" | claude --print 2>&1`
      claude_status = $?.exitstatus
      
      puts "   📊 Claude CLI status: #{claude_status}"
      puts "   📊 Claude CLI output: #{claude_test[0..100]}..." if claude_test.length > 0
      
      # Test Process.spawn approach
      puts "\n4️⃣  Testing Process.spawn..."
      
      begin
        log_dir = '.enhance_swarm/logs'
        FileUtils.mkdir_p(log_dir)
        
        puts "   📊 Working directory: #{Dir.pwd}"
        puts "   📊 Log directory: #{log_dir}"
        
        pid = Process.spawn(
          '/bin/bash', script_path,
          chdir: Dir.pwd,
          out: File.join(log_dir, 'debug_output.log'),
          err: File.join(log_dir, 'debug_error.log')
        )
        
        puts "   📊 Spawned PID: #{pid}"
        
        Process.detach(pid)
        
        # Wait a moment and check process
        sleep(2)
        
        begin
          Process.getpgid(pid)
          puts "   📊 Process still running"
        rescue Errno::ESRCH
          puts "   📊 Process completed"
        end
        
        # Check log files
        output_log = File.join(log_dir, 'debug_output.log')
        error_log = File.join(log_dir, 'debug_error.log')
        
        if File.exist?(output_log)
          output_content = File.read(output_log)
          puts "   📊 Output log size: #{output_content.length}"
          puts "   📊 Output preview: #{output_content[0..200]}..." if output_content.length > 0
        end
        
        if File.exist?(error_log)
          error_content = File.read(error_log)
          puts "   📊 Error log size: #{error_content.length}"
          puts "   📊 Error preview: #{error_content[0..200]}..." if error_content.length > 0
        end
        
      rescue => e
        puts "   ❌ Process.spawn error: #{e.message}"
      end
      
    end
    
  rescue => e
    puts "   ❌ Overall error: #{e.message}"
    puts "   📊 Backtrace: #{e.backtrace.first(3).join(', ')}"
  end
end

if __FILE__ == $0
  test_script_execution
end