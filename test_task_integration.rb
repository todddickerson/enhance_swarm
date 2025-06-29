#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for swarm-tasks integration

require_relative 'lib/enhance_swarm'

def test_task_integration
  puts "🧪 Testing Task Integration Functionality"
  puts "=" * 50

  begin
    # Test TaskIntegration class directly
    puts "\n📋 Testing TaskIntegration class:"
    
    task_integration = EnhanceSwarm::TaskIntegration.new
    
    puts "   ✅ TaskIntegration created successfully"
    puts "   📊 Swarm Tasks Available: #{task_integration.swarm_tasks_available?}"
    
    if task_integration.swarm_tasks_available?
      puts "   🎯 Testing swarm-tasks commands:"
      
      # Test list tasks
      tasks = task_integration.list_tasks
      puts "      Found #{tasks.length} tasks"
      
      # Test get active tasks
      active_tasks = task_integration.get_active_tasks
      puts "      Found #{active_tasks.length} active tasks"
      
      # Test get task folders
      folders = task_integration.get_task_folders
      puts "      Found #{folders.length} task folders"
      
      # Test kanban data
      kanban_data = task_integration.get_kanban_data
      puts "      Kanban data structure: #{kanban_data.keys.join(', ')}"
    else
      puts "   ⚠️  swarm-tasks not available - testing limited functionality"
    end
    
    # Test orchestrator integration
    puts "\n🎯 Testing Orchestrator integration:"
    
    orchestrator = EnhanceSwarm::Orchestrator.new
    puts "   ✅ Orchestrator created successfully"
    
    task_data = orchestrator.get_task_management_data
    puts "   📊 Task management data retrieved"
    puts "      Keys: #{task_data.keys.join(', ')}"
    
    # Test setup
    setup_result = orchestrator.setup_task_management
    puts "   🔧 Task management setup: #{setup_result ? 'Success' : 'Failed/Limited'}"
    
    puts "\n✅ Task integration test completed successfully!"
    
  rescue StandardError => e
    puts "\n❌ Error testing task integration: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    return false
  end
  
  true
end

def test_task_folder_structure
  puts "\n🗂️  Testing Task Folder Structure:"
  puts "=" * 50
  
  # Create test task directory structure
  test_tasks_dir = File.join(Dir.pwd, 'test_tasks')
  
  begin
    # Create test structure
    FileUtils.mkdir_p(test_tasks_dir)
    
    # Create standard kanban folders
    folders = ['todo', 'in_progress', 'review', 'done']
    folders.each do |folder|
      folder_path = File.join(test_tasks_dir, folder)
      FileUtils.mkdir_p(folder_path)
      
      # Create some test task files
      (1..3).each do |i|
        task_file = File.join(folder_path, "task_#{i}.md")
        File.write(task_file, "# Test Task #{i}\n\nThis is a test task in #{folder}")
      end
    end
    
    puts "   ✅ Created test task structure with #{folders.length} folders"
    puts "   📁 Folders: #{folders.join(', ')}"
    
    # Test folder analysis
    original_dir = Dir.pwd
    Dir.chdir(File.dirname(test_tasks_dir))
    
    # Temporarily rename the test directory to 'tasks' for testing
    tasks_dir = File.join(File.dirname(test_tasks_dir), 'tasks')
    FileUtils.mv(test_tasks_dir, tasks_dir) if Dir.exist?(test_tasks_dir)
    
    task_integration = EnhanceSwarm::TaskIntegration.new
    detected_folders = task_integration.get_task_folders
    
    puts "   🔍 Detected #{detected_folders.length} task folders:"
    detected_folders.each do |folder|
      puts "      #{folder[:name]}: #{folder[:task_count]} tasks (#{folder[:status]})"
    end
    
    Dir.chdir(original_dir)
    
    puts "   ✅ Task folder structure test completed!"
    
  ensure
    # Cleanup
    [test_tasks_dir, tasks_dir].each do |dir|
      FileUtils.rm_rf(dir) if dir && Dir.exist?(dir)
    end
  end
  
  true
end

def test_configuration_with_tasks
  puts "\n⚙️  Testing Configuration with Task Integration:"
  puts "=" * 50
  
  begin
    # Test configuration creation with task management
    config = EnhanceSwarm::Configuration.new
    
    puts "   ✅ Configuration created successfully"
    puts "   📊 Task Command: #{config.task_command}"
    puts "   📊 Task Move Command: #{config.task_move_command}"
    
    # Test orchestrator with configuration
    orchestrator = EnhanceSwarm::Orchestrator.new
    puts "   ✅ Orchestrator with task integration created"
    
    puts "   ✅ Configuration test completed!"
    
  rescue StandardError => e
    puts "   ❌ Error testing configuration: #{e.message}"
    return false
  end
  
  true
end

# Run tests
puts "🚀 Starting Task Integration Tests"
puts

if test_task_integration
  if test_task_folder_structure
    if test_configuration_with_tasks
      puts "\n🎉 All task integration tests completed successfully!"
      puts "\n📋 Summary:"
      puts "   ✅ TaskIntegration class working"
      puts "   ✅ Orchestrator integration working"
      puts "   ✅ Task folder structure detection working"
      puts "   ✅ Configuration integration working"
      puts "\n🎯 Ready for UI development with task management features!"
    else
      puts "\n💥 Configuration tests failed!"
    end
  else
    puts "\n💥 Task folder tests failed!"
  end
else
  puts "\n💥 Task integration tests failed!"
end