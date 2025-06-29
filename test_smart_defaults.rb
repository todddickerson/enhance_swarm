#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for smart defaults functionality

require_relative 'lib/enhance_swarm'

def test_smart_defaults
  puts "🧪 Testing Smart Defaults Functionality"
  puts "=" * 50

  # Test in current directory (enhance_swarm gem project)
  puts "\n📁 Testing in current directory (enhance_swarm gem):"
  
  begin
    # Remove config file temporarily if it exists
    config_path = File.join(Dir.pwd, '.enhance_swarm.yml')
    backup_path = "#{config_path}.backup"
    
    if File.exist?(config_path)
      FileUtils.mv(config_path, backup_path)
      puts "   Backed up existing config file"
    end

    # Create configuration with smart defaults
    config = EnhanceSwarm::Configuration.new
    
    puts "   ✅ Configuration created successfully"
    puts "   📊 Smart defaults applied:"
    puts "      Project Name: #{config.project_name}"
    puts "      Description: #{config.project_description}"
    puts "      Technology Stack: #{config.technology_stack}"
    puts "      Test Command: #{config.test_command}"
    puts "      Max Agents: #{config.max_concurrent_agents}"
    puts "      Code Standards: #{config.code_standards.first(2).join(', ')}..."
    puts "      Important Notes: #{config.important_notes.length} detected"
    
    if config.important_notes.any?
      puts "      First Note: #{config.important_notes.first}"
    end

    # Test project analyzer directly
    puts "\n🔍 Testing ProjectAnalyzer directly:"
    analyzer = EnhanceSwarm::ProjectAnalyzer.new
    results = analyzer.analyze
    
    puts "      Project Type: #{results[:project_type]}"
    puts "      Technology Stack: #{results[:technology_stack].join(', ')}"
    puts "      Testing Frameworks: #{results[:testing_framework].join(', ')}"
    puts "      Build Systems: #{results[:build_system].join(', ')}"
    puts "      Has Documentation: #{results[:documentation][:has_docs]}"
    puts "      Documentation Path: #{results[:documentation][:primary_path]}"
    puts "      Recommended Agents: #{results[:recommended_agents].join(', ')}"
    
    # Test smart commands
    smart_commands = results[:smart_commands]
    puts "      Smart Commands:"
    smart_commands.each do |type, command|
      puts "        #{type.to_s.capitalize}: #{command}" if command
    end

    # Restore config file if it existed
    if File.exist?(backup_path)
      FileUtils.mv(backup_path, config_path)
      puts "   Restored original config file"
    end

    puts "\n✅ Smart defaults test completed successfully!"
    
  rescue StandardError => e
    puts "\n❌ Error testing smart defaults: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    
    # Restore config file on error
    if File.exist?(backup_path)
      FileUtils.mv(backup_path, config_path)
      puts "   Restored original config file after error"
    end
    
    return false
  end
  
  true
end

def test_different_project_types
  puts "\n🎯 Testing Different Project Type Detection:"
  puts "=" * 50
  
  # Test various project signatures
  test_cases = [
    {
      name: "Rails Project",
      files: ['Gemfile', 'config/application.rb'],
      expected_type: 'rails'
    },
    {
      name: "React Project", 
      files: ['package.json'],
      package_content: { "dependencies" => { "react" => "^18.0.0" } },
      expected_type: 'react'
    },
    {
      name: "Django Project",
      files: ['manage.py', 'myapp/settings.py'],
      expected_type: 'django'
    }
  ]
  
  test_cases.each do |test_case|
    puts "\n📋 Testing #{test_case[:name]}:"
    
    # Create temporary test directory
    test_dir = "/tmp/enhance_swarm_test_#{rand(1000)}"
    Dir.mkdir(test_dir)
    
    begin
      # Create test files
      test_case[:files].each do |file|
        file_path = File.join(test_dir, file)
        FileUtils.mkdir_p(File.dirname(file_path))
        
        if file == 'package.json' && test_case[:package_content]
          File.write(file_path, JSON.pretty_generate(test_case[:package_content]))
        else
          File.write(file_path, "# Test file for #{test_case[:name]}")
        end
      end
      
      # Test analyzer
      analyzer = EnhanceSwarm::ProjectAnalyzer.new(test_dir)
      results = analyzer.analyze
      
      detected_type = results[:project_type]
      puts "      Expected: #{test_case[:expected_type]}"
      puts "      Detected: #{detected_type}"
      puts "      #{detected_type == test_case[:expected_type] ? '✅' : '❌'} Match"
      
    ensure
      # Cleanup
      FileUtils.rm_rf(test_dir) if Dir.exist?(test_dir)
    end
  end
end

# Run tests
puts "🚀 Starting Smart Defaults Tests"
puts

if test_smart_defaults
  test_different_project_types
  puts "\n🎉 All smart defaults tests completed!"
else
  puts "\n💥 Smart defaults tests failed!"
end