# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'fileutils'

RSpec.describe EnhanceSwarm::AgentSpawner do
  let(:spawner) { described_class.new }
  let(:mock_session_manager) { instance_double(EnhanceSwarm::SessionManager) }
  let(:mock_resource_manager) { instance_double(EnhanceSwarm::ResourceManager) }

  before do
    allow(EnhanceSwarm::SessionManager).to receive(:new).and_return(mock_session_manager)
    allow(EnhanceSwarm::ResourceManager).to receive(:new).and_return(mock_resource_manager)
    allow(mock_session_manager).to receive(:read_session).and_return(nil)
  end

  describe '#initialize' do
    it 'initializes with configuration, session manager, and resource manager' do
      expect(spawner.instance_variable_get(:@config)).to be_an_instance_of(EnhanceSwarm::Configuration)
      expect(spawner.instance_variable_get(:@session_manager)).to eq(mock_session_manager)
      expect(spawner.instance_variable_get(:@resource_manager)).to eq(mock_resource_manager)
    end
  end

  describe '#spawn_agent' do
    let(:role) { 'backend' }
    let(:task) { 'Create user authentication system' }

    context 'when resource limits allow spawning' do
      before do
        allow(mock_resource_manager).to receive(:can_spawn_agent?).and_return(
          { allowed: true, reasons: [] }
        )
        allow(spawner).to receive(:create_agent_worktree).and_return('/tmp/test-worktree')
        allow(spawner).to receive(:spawn_claude_process).and_return(12345)
        allow(mock_session_manager).to receive(:add_agent).and_return(true)
      end

      it 'successfully spawns an agent' do
        result = spawner.spawn_agent(role: role, task: task)
        
        expect(result).to be_a(Hash)
        expect(result[:pid]).to eq(12345)
        expect(result[:role]).to eq(role)
        expect(result[:worktree_path]).to eq('/tmp/test-worktree')
      end

      it 'calls resource manager to check limits' do
        expect(mock_resource_manager).to receive(:can_spawn_agent?)
        spawner.spawn_agent(role: role, task: task)
      end

      it 'registers agent in session manager' do
        expect(mock_session_manager).to receive(:add_agent).with(role, 12345, '/tmp/test-worktree', task)
        spawner.spawn_agent(role: role, task: task)
      end
    end

    context 'when resource limits prevent spawning' do
      before do
        allow(mock_resource_manager).to receive(:can_spawn_agent?).and_return(
          { allowed: false, reasons: ['Too many concurrent agents'] }
        )
      end

      it 'returns false and does not spawn' do
        result = spawner.spawn_agent(role: role, task: task)
        expect(result).to be false
      end

      it 'does not create worktree' do
        expect(spawner).not_to receive(:create_agent_worktree)
        spawner.spawn_agent(role: role, task: task)
      end
    end

    context 'when worktree creation fails' do
      before do
        allow(mock_resource_manager).to receive(:can_spawn_agent?).and_return(
          { allowed: true, reasons: [] }
        )
        allow(spawner).to receive(:create_agent_worktree).and_return(nil)
      end

      it 'returns false' do
        result = spawner.spawn_agent(role: role, task: task)
        expect(result).to be false
      end
    end
  end

  describe '#spawn_multiple_agents' do
    let(:agents) do
      [
        { role: 'backend', task: 'Create API', worktree: true },
        { role: 'frontend', task: 'Create UI', worktree: true }
      ]
    end

    before do
      allow(spawner).to receive(:spawn_agent).and_return({ pid: 12345, role: 'backend' })
    end

    it 'spawns multiple agents with jitter' do
      expect(spawner).to receive(:spawn_agent).twice
      allow(spawner).to receive(:sleep) # Allow sleep with any arguments since rand(0..2) varies
      
      results = spawner.spawn_multiple_agents(agents)
      expect(results.size).to eq(2)
    end
  end

  describe '#sanitize_task_description' do
    it 'removes dangerous characters' do
      dangerous_task = 'test`rm -rf /`; echo $PATH'
      safe_task = spawner.send(:sanitize_task_description, dangerous_task)
      
      expect(safe_task).not_to include('`')
      expect(safe_task).not_to include(';')
      expect(safe_task).not_to include('$')
      expect(safe_task).to eq('testrm -rf / echo PATH')
    end

    it 'preserves safe characters' do
      safe_task = 'Create user authentication with OAuth2'
      result = spawner.send(:sanitize_task_description, safe_task)
      
      expect(result).to eq(safe_task)
    end

    it 'handles empty input' do
      result = spawner.send(:sanitize_task_description, '')
      expect(result).to eq('')
    end
  end

  describe '#sanitize_role' do
    it 'allows known safe roles' do
      %w[ux backend frontend qa general].each do |role|
        result = spawner.send(:sanitize_role, role)
        expect(result).to eq(role)
      end
    end

    it 'defaults unknown roles to general' do
      result = spawner.send(:sanitize_role, 'hacker')
      expect(result).to eq('general')
    end

    it 'handles nil input' do
      result = spawner.send(:sanitize_role, nil)
      expect(result).to eq('general')
    end
  end

  describe '#claude_cli_available?' do
    context 'when Claude CLI is available' do
      before do
        process_status = double('process_status', success?: true)
        allow(spawner).to receive(:`).with('claude --version 2>/dev/null').and_return('Claude CLI v1.0')
        allow(spawner).to receive(:$?).and_return(process_status)
      end

      it 'returns true' do
        expect(spawner.claude_cli_available?).to be true
      end
    end

    context 'when Claude CLI is not available' do
      before do
        process_status = double('process_status', success?: false)
        allow(spawner).to receive(:`).with('claude --version 2>/dev/null').and_return('')
        allow(spawner).to receive(:$?).and_return(process_status)
      end

      it 'returns false' do
        expect(spawner.claude_cli_available?).to be false
      end
    end
  end

  describe '#stop_agent' do
    let(:pid) { 12345 }

    context 'when process exists' do
      before do
        allow(Process).to receive(:kill).with('TERM', pid)
        allow(mock_session_manager).to receive(:update_agent_status).and_return(true)
      end

      it 'sends TERM signal and updates session' do
        expect(Process).to receive(:kill).with('TERM', pid)
        expect(mock_session_manager).to receive(:update_agent_status).with(pid, 'stopped', an_instance_of(String))
        
        result = spawner.stop_agent(pid)
        expect(result).to be true
      end
    end

    context 'when process does not exist' do
      before do
        allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
        allow(mock_session_manager).to receive(:update_agent_status).and_return(true)
      end

      it 'handles ESRCH gracefully' do
        result = spawner.stop_agent(pid)
        expect(result).to be true
      end
    end
  end

  describe '#create_agent_script' do
    let(:prompt) { 'Test prompt' }
    let(:role) { 'backend' }
    let(:working_dir) { '/tmp/test' }

    it 'creates executable script file' do
      script_path = spawner.send(:create_agent_script, prompt, role, working_dir)
      
      expect(File.exist?(script_path)).to be true
      expect(File.executable?(script_path)).to be true
      
      content = File.read(script_path)
      expect(content).to include(prompt)
      expect(content).to include(role)
      expect(content).to include('EOF')
      
      File.delete(script_path)
    end

    it 'handles dangerous content safely with heredoc' do
      dangerous_prompt = 'test"; echo "hacked" > /tmp/pwned; echo "'
      script_path = spawner.send(:create_agent_script, dangerous_prompt, role, working_dir)
      
      content = File.read(script_path)
      expect(content).to include("'EOF'")
      expect(content).to include('cat > "$PROMPT_FILE" << \'EOF\'')
      
      File.delete(script_path)
    end
  end

  describe 'error handling' do
    let(:role) { 'backend' }
    let(:task) { 'Test task' }

    it 'handles exceptions during spawn and cleans up' do
      allow(mock_resource_manager).to receive(:can_spawn_agent?).and_return(
        { allowed: true, reasons: [] }
      )
      allow(spawner).to receive(:create_agent_worktree).and_raise(StandardError, 'Test error')
      expect(spawner).to receive(:cleanup_failed_spawn)
      
      result = spawner.spawn_agent(role: role, task: task)
      expect(result).to be false
    end
  end
end