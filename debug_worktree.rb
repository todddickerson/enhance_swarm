#!/usr/bin/env ruby
# Debug script to test worktree creation

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'enhance_swarm'

def test_worktree_creation
  puts "🔍 Testing Git Worktree Creation Debug"
  puts "=" * 50

  spawner = EnhanceSwarm::AgentSpawner.new
  
  # Test the private create_agent_worktree method
  begin
    puts "\n1️⃣  Testing worktree creation..."
    
    # Check current git status
    git_status = `git status --porcelain 2>&1`
    puts "   📊 Git status: #{git_status.strip}"
    
    # Check if we're in a git repository
    in_git_repo = system('git rev-parse --git-dir > /dev/null 2>&1')
    puts "   📊 In git repo: #{in_git_repo}"
    
    # Check current branch
    current_branch = `git branch --show-current 2>&1`.strip
    puts "   📊 Current branch: #{current_branch}"
    
    # Check if we have commits
    has_commits = system('git log --oneline -1 > /dev/null 2>&1')
    puts "   📊 Has commits: #{has_commits}"
    
    # Test directory creation
    worktree_dir = '.enhance_swarm/worktrees'
    puts "   📊 Creating directory: #{worktree_dir}"
    FileUtils.mkdir_p(worktree_dir) unless Dir.exist?(worktree_dir)
    puts "   📊 Directory exists: #{Dir.exist?(worktree_dir)}"
    
    # Try to call the create_agent_worktree method
    puts "\n2️⃣  Calling create_agent_worktree..."
    worktree_path = spawner.send(:create_agent_worktree, 'debug_test')
    
    if worktree_path
      puts "   ✅ Success! Worktree created at: #{worktree_path}"
      puts "   📊 Directory exists: #{Dir.exist?(worktree_path)}"
      
      # List contents
      if Dir.exist?(worktree_path)
        contents = Dir.entries(worktree_path).reject { |f| f.start_with?('.') }
        puts "   📊 Contents: #{contents.join(', ')}"
      end
    else
      puts "   ❌ Failed to create worktree"
    end
    
  rescue => e
    puts "   ❌ Error: #{e.class}: #{e.message}"
    puts "   📊 Backtrace: #{e.backtrace.first(3).join(', ')}"
  end
  
  puts "\n3️⃣  Checking existing worktrees..."
  existing_worktrees = `git worktree list 2>&1`
  puts "   📊 Existing worktrees:"
  existing_worktrees.each_line { |line| puts "      #{line.strip}" }
  
  puts "\n4️⃣  Testing CommandExecutor directly..."
  begin
    result = EnhanceSwarm::CommandExecutor.execute('git', 'worktree', 'list')
    puts "   ✅ CommandExecutor works: #{result}"
  rescue => e
    puts "   ❌ CommandExecutor error: #{e.message}"
  end
end

if __FILE__ == $0
  test_worktree_creation
end