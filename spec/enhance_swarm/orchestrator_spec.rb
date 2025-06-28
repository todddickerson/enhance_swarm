# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::Orchestrator do
  let(:orchestrator) { described_class.new }
  let(:mock_config) { double('config') }
  let(:mock_task_manager) { double('task_manager') }
  let(:mock_monitor) { double('monitor') }

  before do
    allow(EnhanceSwarm).to receive(:configuration).and_return(mock_config)
    allow(mock_config).to receive(:test_command).and_return('bundle exec test')
    allow(mock_config).to receive(:monitor_timeout).and_return(120)
    allow(mock_config).to receive(:worktree_enabled).and_return(true)
    
    allow(EnhanceSwarm::TaskManager).to receive(:new).and_return(mock_task_manager)
    allow(EnhanceSwarm::Monitor).to receive(:new).and_return(mock_monitor)
  end

  describe '#sanitize_role' do
    it 'allows valid roles' do
      result = orchestrator.send(:sanitize_role, 'backend')
      expect(result).to eq('backend')
    end

    it 'defaults invalid roles to general' do
      result = orchestrator.send(:sanitize_role, 'hacker')
      expect(result).to eq('general')
    end

    it 'handles case insensitive input' do
      result = orchestrator.send(:sanitize_role, 'FRONTEND')
      expect(result).to eq('frontend')
    end
  end

  describe '#sanitize_task_description' do
    it 'removes dangerous characters' do
      result = orchestrator.send(:sanitize_task_description, 'test`rm -rf /`task')
      expect(result).to eq('testrm -rf /task')
    end

    it 'preserves safe content' do
      result = orchestrator.send(:sanitize_task_description, 'implement user authentication')
      expect(result).to eq('implement user authentication')
    end
  end

  describe '#break_down_task' do
    let(:task) { { description: 'implement user interface with backend API' } }

    it 'identifies needed agent types' do
      agents = orchestrator.send(:break_down_task, task)
      
      expect(agents).to include(hash_including(role: 'ux'))
      expect(agents).to include(hash_including(role: 'backend'))
      expect(agents).to include(hash_including(role: 'qa'))
    end

    it 'creates general agent for unclear tasks' do
      unclear_task = { description: 'do something' }
      agents = orchestrator.send(:break_down_task, unclear_task)
      
      expect(agents).to include(hash_including(role: 'general'))
    end
  end

  describe '#spawn_single' do
    before do
      allow(EnhanceSwarm::CommandExecutor).to receive(:execute_async).and_return(12345)
    end

    it 'spawns agent with correct parameters' do
      expect(EnhanceSwarm::CommandExecutor).to receive(:execute_async)
        .with('claude-swarm', 'start', '-p', anything, '--worktree')
      
      orchestrator.spawn_single(task: 'test task', role: 'backend', worktree: true)
    end

    it 'handles command failures gracefully' do
      allow(EnhanceSwarm::CommandExecutor).to receive(:execute_async)
        .and_raise(EnhanceSwarm::CommandExecutor::CommandError.new('test error'))
      
      expect do
        orchestrator.spawn_single(task: 'test task', role: 'backend', worktree: true)
      end.not_to raise_error
    end
  end
end