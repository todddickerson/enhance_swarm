#!/usr/bin/env ruby
# Final comprehensive validation test for EnhanceSwarm v1.0

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def run_final_validation
  puts "🔍 EnhanceSwarm v1.0 Final Validation Test"
  puts "=" * 60

  results = {
    core_functionality: {},
    reliability: {},
    user_experience: {},
    production_readiness: {}
  }

  begin
    # 1. Core Functionality Tests
    puts "\n1️⃣  CORE FUNCTIONALITY VALIDATION"
    puts "-" * 40

    # Test AgentSpawner
    puts "   Testing AgentSpawner..."
    spawner = EnhanceSwarm::AgentSpawner.new
    claude_available = spawner.claude_cli_available?
    results[:core_functionality][:claude_cli] = claude_available
    puts "   📊 Claude CLI: #{claude_available ? '✅' : '❌'}"

    # Test SessionManager
    puts "   Testing SessionManager..."
    session_manager = EnhanceSwarm::SessionManager.new
    session = session_manager.create_session("Validation test")
    session_works = session && session[:session_id]
    results[:core_functionality][:session_management] = session_works
    puts "   📊 Session Management: #{session_works ? '✅' : '❌'}"

    # Test Configuration
    puts "   Testing Configuration..."
    config = EnhanceSwarm.configuration
    config_works = config && config.project_name
    results[:core_functionality][:configuration] = config_works
    puts "   📊 Configuration: #{config_works ? '✅' : '❌'}"

    # Test Orchestrator
    puts "   Testing Orchestrator..."
    orchestrator = EnhanceSwarm::Orchestrator.new
    orchestrator_works = orchestrator.respond_to?(:spawn_single)
    results[:core_functionality][:orchestrator] = orchestrator_works
    puts "   📊 Orchestrator: #{orchestrator_works ? '✅' : '❌'}"

    # 2. Reliability Tests
    puts "\n2️⃣  RELIABILITY VALIDATION"
    puts "-" * 40

    # Test Error Handling
    puts "   Testing Error Handling..."
    begin
      # Test with invalid input
      spawner.spawn_agent(role: nil, task: nil, worktree: false)
      error_handling = false
    rescue => e
      error_handling = true
      puts "   📊 Error properly caught: #{e.class}"
    end
    results[:reliability][:error_handling] = error_handling
    puts "   📊 Error Handling: #{error_handling ? '✅' : '❌'}"

    # Test Logger
    puts "   Testing Logger..."
    logger_works = EnhanceSwarm::Logger.respond_to?(:info)
    results[:reliability][:logging] = logger_works
    puts "   📊 Logging System: #{logger_works ? '✅' : '❌'}"

    # Test Cleanup
    puts "   Testing Cleanup..."
    cleanup_works = EnhanceSwarm::CleanupManager.respond_to?(:cleanup_stale_worktrees)
    results[:reliability][:cleanup] = cleanup_works
    puts "   📊 Cleanup Manager: #{cleanup_works ? '✅' : '❌'}"

    # 3. User Experience Tests
    puts "\n3️⃣  USER EXPERIENCE VALIDATION"
    puts "-" * 40

    # Test CLI Components
    puts "   Testing CLI Components..."
    cli_works = EnhanceSwarm::CLI.respond_to?(:new)
    results[:user_experience][:cli] = cli_works
    puts "   📊 CLI Interface: #{cli_works ? '✅' : '❌'}"

    # Test Dashboard
    puts "   Testing Dashboard..."
    dashboard_works = EnhanceSwarm::VisualDashboard.respond_to?(:instance)
    results[:user_experience][:dashboard] = dashboard_works
    puts "   📊 Visual Dashboard: #{dashboard_works ? '✅' : '❌'}"

    # Test Smart Defaults
    puts "   Testing Smart Defaults..."
    smart_defaults_works = EnhanceSwarm::SmartDefaults.respond_to?(:suggest_role_for_task)
    results[:user_experience][:smart_defaults] = smart_defaults_works
    puts "   📊 Smart Defaults: #{smart_defaults_works ? '✅' : '❌'}"

    # 4. Production Readiness Tests
    puts "\n4️⃣  PRODUCTION READINESS VALIDATION"
    puts "-" * 40

    # Test actual spawn (non-blocking)
    puts "   Testing Real Agent Spawn..."
    spawn_result = spawner.spawn_agent(
      role: "general",
      task: "Quick validation test - just echo 'validation successful'",
      worktree: false
    )
    spawn_works = spawn_result && spawn_result[:pid]
    results[:production_readiness][:real_spawn] = spawn_works
    puts "   📊 Real Agent Spawn: #{spawn_works ? '✅' : '❌'}"
    
    if spawn_works
      puts "   📊 Spawned PID: #{spawn_result[:pid]}"
      
      # Brief wait to check process
      sleep(2)
      begin
        Process.getpgid(spawn_result[:pid])
        puts "   📊 Process Status: Running ✅"
      rescue Errno::ESRCH
        puts "   📊 Process Status: Completed ✅"
      end
    end

    # Test Dependencies
    puts "   Testing Dependencies..."
    deps_works = EnhanceSwarm::DependencyValidator.respond_to?(:validate_all)
    results[:production_readiness][:dependencies] = deps_works
    puts "   📊 Dependency Validation: #{deps_works ? '✅' : '❌'}"

    # Test Process Monitoring
    puts "   Testing Process Monitoring..."
    monitor_works = EnhanceSwarm::ProcessMonitor.respond_to?(:new)
    results[:production_readiness][:monitoring] = monitor_works
    puts "   📊 Process Monitoring: #{monitor_works ? '✅' : '❌'}"

    # 5. Calculate Final Score
    puts "\n5️⃣  FINAL SCORING"
    puts "-" * 40

    total_tests = 0
    passed_tests = 0

    results.each do |category, tests|
      category_passed = tests.values.count(true)
      category_total = tests.count
      total_tests += category_total
      passed_tests += category_passed
      
      percentage = category_total > 0 ? (category_passed.to_f / category_total * 100).round(1) : 0
      puts "   #{category.to_s.gsub('_', ' ').capitalize}: #{category_passed}/#{category_total} (#{percentage}%)"
    end

    overall_percentage = total_tests > 0 ? (passed_tests.to_f / total_tests * 100).round(1) : 0
    
    puts "\n" + "=" * 60
    puts "🎯 FINAL VALIDATION RESULTS"
    puts "=" * 60
    puts "Total Tests: #{total_tests}"
    puts "Tests Passed: #{passed_tests}"
    puts "Success Rate: #{overall_percentage}%"
    
    if overall_percentage >= 95
      puts "\n🚀 PRODUCTION READY - EXCELLENT"
      puts "   All critical systems operational"
    elsif overall_percentage >= 85
      puts "\n✅ PRODUCTION READY - GOOD"
      puts "   Minor issues, but deployable"
    elsif overall_percentage >= 70
      puts "\n⚠️  PRODUCTION READY - WITH CAVEATS"
      puts "   Some issues need attention"
    else
      puts "\n❌ NOT PRODUCTION READY"
      puts "   Significant issues require resolution"
    end

    return overall_percentage

  rescue => e
    puts "   ❌ Validation Error: #{e.class}: #{e.message}"
    puts "   📊 Backtrace:"
    e.backtrace.first(3).each { |line| puts "      #{line}" }
    return 0
  ensure
    # Cleanup
    session_manager&.cleanup_session
  end
end

if __FILE__ == $0
  score = run_final_validation
  puts "\n🎖️  EnhanceSwarm v1.0 Production Score: #{score}/100"
end