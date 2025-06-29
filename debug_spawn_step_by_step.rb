#!/usr/bin/env ruby
# Debug spawn process step by step

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def debug_spawn_process
  puts "🔧 Debugging Spawn Process Step by Step"
  puts "=" * 50

  begin
    ENV['ENHANCE_SWARM_DEBUG'] = 'true'
    
    # Step 1: Test AgentSpawner initialization
    puts "\n1️⃣  Initializing AgentSpawner..."
    spawner = EnhanceSwarm::AgentSpawner.new
    puts "   ✅ AgentSpawner initialized"
    
    # Step 2: Test Claude CLI availability
    puts "\n2️⃣  Testing Claude CLI..."
    claude_available = spawner.claude_cli_available?
    puts "   📊 Claude CLI available: #{claude_available}"
    
    if claude_available
      claude_version = `claude --version 2>/dev/null`.strip
      puts "   📊 Claude version: #{claude_version}"
    end
    
    # Step 3: Test worktree creation
    puts "\n3️⃣  Testing Worktree Creation..."
    role = "frontend"
    
    # Call the private method using send
    worktree_path = spawner.send(:create_agent_worktree, role)
    puts "   📊 Worktree created: #{worktree_path}"
    
    if worktree_path
      puts "   📊 Worktree exists: #{Dir.exist?(worktree_path)}"
      puts "   📊 Worktree files: #{Dir.entries(worktree_path).reject { |f| f.start_with?('.') }}"
    end
    
    # Step 4: Test prompt building
    puts "\n4️⃣  Testing Prompt Building..."
    task = "Create a simple test component"
    prompt = spawner.send(:build_agent_prompt, task, role, worktree_path)
    puts "   📊 Prompt length: #{prompt.length} characters"
    puts "   📊 First 100 chars: #{prompt[0..100]}..."
    
    # Step 5: Test script creation
    puts "\n5️⃣  Testing Script Creation..."
    script_path = spawner.send(:create_agent_script, prompt, role, worktree_path || Dir.pwd)
    puts "   📊 Script created: #{script_path}"
    puts "   📊 Script exists: #{File.exist?(script_path)}"
    puts "   📊 Script executable: #{File.executable?(script_path)}"
    
    if File.exist?(script_path)
      script_content = File.read(script_path)
      puts "   📊 Script length: #{script_content.length} characters"
      puts "   📊 First few lines:"
      script_content.lines.first(5).each_with_index do |line, i|
        puts "      #{i+1}: #{line.strip}"
      end
    end
    
    # Step 6: Test environment building
    puts "\n6️⃣  Testing Environment..."
    env = spawner.send(:build_agent_environment, role, worktree_path)
    puts "   📊 Environment variables set:"
    env.select { |k, v| k.start_with?('ENHANCE_SWARM') }.each do |k, v|
      puts "      #{k}=#{v}"
    end
    
    # Step 7: Try manual script execution
    puts "\n7️⃣  Testing Manual Script Execution..."
    if File.exist?(script_path)
      puts "   🚀 Attempting to run script manually..."
      
      # Change to the working directory
      original_dir = Dir.pwd
      working_dir = worktree_path || Dir.pwd
      
      begin
        Dir.chdir(working_dir)
        puts "   📊 Changed to directory: #{Dir.pwd}"
        
        # Try to execute the script with timeout
        require 'timeout'
        
        output = ""
        error = ""
        
        begin
          Timeout::timeout(10) do
            output = `bash #{script_path} 2>&1`
          end
          exit_status = $?.exitstatus
          
          puts "   📊 Script exit status: #{exit_status}"
          puts "   📊 Output length: #{output.length}"
          puts "   📊 Output preview: #{output[0..300]}..." if output.length > 0
          
        rescue Timeout::Error
          puts "   ⚠️  Script execution timed out (>10s)"
        end
        
      ensure
        Dir.chdir(original_dir)
      end
    end
    
    # Step 8: Test Process.spawn approach
    puts "\n8️⃣  Testing Process.spawn..."
    if File.exist?(script_path)
      working_dir = worktree_path || Dir.pwd
      log_dir = '.enhance_swarm/logs'
      
      puts "   🚀 Spawning process..."
      puts "   📊 Working dir: #{working_dir}"
      puts "   📊 Log dir: #{log_dir}"
      
      begin
        FileUtils.mkdir_p(log_dir)
        
        pid = Process.spawn(
          '/bin/bash', script_path,
          chdir: working_dir,
          out: File.join(log_dir, 'debug_manual_output.log'),
          err: File.join(log_dir, 'debug_manual_error.log')
        )
        
        puts "   📊 Process spawned: PID #{pid}"
        Process.detach(pid)
        
        # Wait a moment and check status
        sleep(3)
        
        begin
          Process.getpgid(pid)
          puts "   📊 Process still running"
        rescue Errno::ESRCH
          puts "   📊 Process completed"
        end
        
        # Check output files
        output_file = File.join(log_dir, 'debug_manual_output.log')
        error_file = File.join(log_dir, 'debug_manual_error.log')
        
        if File.exist?(output_file)
          output = File.read(output_file)
          puts "   📊 Manual output: #{output.length} chars"
          puts "   📊 Output preview: #{output[0..200]}..." if output.length > 0
        end
        
        if File.exist?(error_file)
          error = File.read(error_file)
          puts "   📊 Manual error: #{error.length} chars"
          puts "   📊 Error preview: #{error[0..200]}..." if error.length > 0
        end
        
      rescue => e
        puts "   ❌ Process spawn failed: #{e.message}"
      end
    end
    
    # Cleanup
    puts "\n9️⃣  Cleanup..."
    if worktree_path && Dir.exist?(worktree_path)
      puts "   🧹 Cleaning up worktree..."
      begin
        system("git worktree remove #{worktree_path}")
        branch_name = File.basename(worktree_path)
        system("git branch -d #{branch_name}")
        puts "   ✅ Worktree cleaned up"
      rescue => e
        puts "   ⚠️  Cleanup warning: #{e.message}"
      end
    end
    
  rescue => e
    puts "   ❌ Error: #{e.class}: #{e.message}"
    puts "   📊 Backtrace:"
    e.backtrace.first(10).each { |line| puts "      #{line}" }
  ensure
    ENV.delete('ENHANCE_SWARM_DEBUG')
  end
end

if __FILE__ == $0
  debug_spawn_process
end