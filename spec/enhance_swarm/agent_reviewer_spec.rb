# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::AgentReviewer do
  describe '.list_swarm_worktrees' do
    it 'parses git worktree list output' do
      output = <<~OUTPUT
        worktree /path/to/main
        HEAD abc123
        branch main

        worktree /path/to/swarm/feature-1
        HEAD def456
        branch swarm/feature-1

        worktree /path/to/other
        HEAD ghi789
        branch other-branch

        worktree /path/to/swarm/feature-2
        HEAD jkl012
        branch swarm/feature-2
      OUTPUT

      allow(EnhanceSwarm::CommandExecutor).to receive(:execute)
        .with('git', 'worktree', 'list', '--porcelain')
        .and_return(output)

      worktrees = described_class.list_swarm_worktrees

      expect(worktrees.size).to eq(2)
      expect(worktrees[0][:path]).to eq('/path/to/swarm/feature-1')
      expect(worktrees[0][:branch]).to eq('swarm/feature-1')
      expect(worktrees[1][:path]).to eq('/path/to/swarm/feature-2')
      expect(worktrees[1][:branch]).to eq('swarm/feature-2')
    end
  end

  describe '.determine_worktree_status' do
    it 'identifies stale worktrees' do
      review = { last_activity: Time.now - 7200 } # 2 hours ago
      status = described_class.determine_worktree_status(review)
      expect(status).to eq('stale')
    end

    it 'identifies active worktrees' do
      review = { 
        last_activity: Time.now - 1800, # 30 minutes ago
        files_changed: ['M file.rb']
      }
      status = described_class.determine_worktree_status(review)
      expect(status).to eq('active')
    end

    it 'identifies completed worktrees' do
      review = { 
        last_activity: Time.now - 1800,
        files_changed: [],
        commits: ['abc123 Implement feature']
      }
      status = described_class.determine_worktree_status(review)
      expect(status).to eq('completed')
    end

    it 'identifies initialized worktrees' do
      review = { 
        last_activity: Time.now - 1800,
        files_changed: [],
        commits: []
      }
      status = described_class.determine_worktree_status(review)
      expect(status).to eq('initialized')
    end
  end

  describe '.detect_issues' do
    it 'detects merge conflicts' do
      review = { files_changed: ['UU conflicted_file.rb', 'M normal_file.rb'] }
      issues = described_class.detect_issues('/tmp', review)
      expect(issues).to include('merge conflicts detected')
    end

    it 'detects untracked source files' do
      review = { files_changed: ['?? new_feature.rb', '?? README.txt'] }
      issues = described_class.detect_issues('/tmp', review)
      expect(issues).to include('untracked source files')
    end

    it 'returns empty array when no issues' do
      review = { files_changed: ['M existing_file.rb'] }
      issues = described_class.detect_issues('/tmp', review)
      expect(issues).to be_empty
    end
  end

  describe '.extract_task_progress' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:claude_dir) { File.join(temp_dir, '.claude', 'tasks') }

    before do
      FileUtils.mkdir_p(claude_dir)
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    it 'extracts completed tasks' do
      File.write(File.join(claude_dir, 'feature-1.md'), "Task description\n✅ completed")
      
      progress = described_class.extract_task_progress(temp_dir)
      expect(progress['feature-1']).to eq('completed')
    end

    it 'extracts in-progress tasks' do
      File.write(File.join(claude_dir, 'feature-2.md'), "Task description\n🔄 in progress")
      
      progress = described_class.extract_task_progress(temp_dir)
      expect(progress['feature-2']).to eq('in_progress')
    end

    it 'extracts blocked tasks' do
      File.write(File.join(claude_dir, 'feature-3.md'), "Task description\n❌ blocked")
      
      progress = described_class.extract_task_progress(temp_dir)
      expect(progress['feature-3']).to eq('blocked')
    end

    it 'defaults to pending for unknown status' do
      File.write(File.join(claude_dir, 'feature-4.md'), "Task description")
      
      progress = described_class.extract_task_progress(temp_dir)
      expect(progress['feature-4']).to eq('pending')
    end
  end

  describe '.generate_summary' do
    it 'generates correct summary statistics' do
      results = {
        worktrees: [
          { status: 'active', issues: ['issue1'] },
          { status: 'stale', issues: [] },
          { status: 'completed', issues: ['issue2', 'issue3'] }
        ],
        completed_tasks: [{ task: 'task1' }, { task: 'task2' }],
        active_tasks: [{ task: 'task3' }],
        blocked_tasks: []
      }

      summary = described_class.generate_summary(results)

      expect(summary[:total_worktrees]).to eq(3)
      expect(summary[:active_worktrees]).to eq(1)
      expect(summary[:stale_worktrees]).to eq(1)
      expect(summary[:completed_tasks]).to eq(2)
      expect(summary[:active_tasks]).to eq(1)
      expect(summary[:blocked_tasks]).to eq(0)
      expect(summary[:total_issues]).to eq(3)
    end
  end

  describe '.format_duration' do
    it 'formats seconds correctly' do
      expect(described_class.format_duration(30)).to eq('30s')
      expect(described_class.format_duration(90)).to eq('1m')
      expect(described_class.format_duration(3661)).to eq('1h')
    end
  end
end