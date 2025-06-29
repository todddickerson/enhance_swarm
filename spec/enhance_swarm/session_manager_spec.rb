# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tempfile'
require 'fileutils'

RSpec.describe EnhanceSwarm::SessionManager do
  let(:session_manager) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir('enhance_swarm_test') }
  let(:session_file) { File.join(temp_dir, '.enhance_swarm', 'session.json') }

  before do
    # Mock the session path to use temp directory
    allow(Dir).to receive(:pwd).and_return(temp_dir)
    allow(session_manager).to receive(:instance_variable_get).with(:@session_path).and_return(session_file)
    session_manager.instance_variable_set(:@session_path, session_file)
    
    # Create session directory
    FileUtils.mkdir_p(File.dirname(session_file))
  end

  after do
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  describe '#initialize' do
    it 'sets up session path and ensures directory exists' do
      expect(session_manager.instance_variable_get(:@session_path)).to eq(session_file)
      expect(Dir.exist?(File.dirname(session_file))).to be true
    end
  end

  describe '#create_session' do
    let(:task_description) { 'Test task for session' }

    it 'creates a new session with proper structure' do
      session_data = session_manager.create_session(task_description)
      
      expect(session_data[:session_id]).to be_a(String)
      expect(session_data[:start_time]).to be_a(String)
      expect(session_data[:task_description]).to eq(task_description)
      expect(session_data[:agents]).to eq([])
      expect(session_data[:status]).to eq('active')
    end

    it 'writes session to file' do
      session_manager.create_session(task_description)
      
      expect(File.exist?(session_file)).to be true
      
      content = JSON.parse(File.read(session_file), symbolize_names: true)
      expect(content[:task_description]).to eq(task_description)
      expect(content[:status]).to eq('active')
    end

    it 'generates unique session IDs' do
      session1 = session_manager.create_session('Task 1')
      session2 = session_manager.create_session('Task 2')
      
      expect(session1[:session_id]).not_to eq(session2[:session_id])
    end
  end

  describe '#add_agent' do
    let(:role) { 'backend' }
    let(:pid) { 12345 }
    let(:worktree_path) { '/tmp/test-worktree' }
    let(:task) { 'Create authentication system' }

    before do
      session_manager.create_session('Test session')
    end

    it 'adds agent to existing session' do
      result = session_manager.add_agent(role, pid, worktree_path, task)
      
      expect(result).to be true
      
      session = session_manager.read_session
      agent = session[:agents].first
      
      expect(agent[:role]).to eq(role)
      expect(agent[:pid]).to eq(pid)
      expect(agent[:worktree_path]).to eq(worktree_path)
      expect(agent[:task]).to eq(task)
      expect(agent[:status]).to eq('running')
      expect(agent[:start_time]).to be_a(String)
    end

    it 'returns false when no session exists' do
      File.delete(session_file)
      
      result = session_manager.add_agent(role, pid, worktree_path, task)
      expect(result).to be false
    end

    it 'handles multiple agents' do
      session_manager.add_agent('backend', 12345, '/path1', 'Task 1')
      session_manager.add_agent('frontend', 54321, '/path2', 'Task 2')
      
      session = session_manager.read_session
      expect(session[:agents].size).to eq(2)
      expect(session[:agents].map { |a| a[:role] }).to contain_exactly('backend', 'frontend')
    end
  end

  describe '#update_agent_status' do
    let(:pid) { 12345 }

    before do
      session_manager.create_session('Test session')
      session_manager.add_agent('backend', pid, '/tmp/test', 'Test task')
    end

    it 'updates agent status successfully' do
      completion_time = Time.now.iso8601
      result = session_manager.update_agent_status(pid, 'completed', completion_time)
      
      expect(result).to be true
      
      session = session_manager.read_session
      agent = session[:agents].find { |a| a[:pid] == pid }
      
      expect(agent[:status]).to eq('completed')
      expect(agent[:completion_time]).to eq(completion_time)
    end

    it 'returns false for non-existent agent' do
      result = session_manager.update_agent_status(99999, 'completed')
      expect(result).to be false
    end

    it 'returns false when no session exists' do
      File.delete(session_file)
      
      result = session_manager.update_agent_status(pid, 'completed')
      expect(result).to be false
    end
  end

  describe '#remove_agent' do
    let(:pid) { 12345 }

    before do
      session_manager.create_session('Test session')
      session_manager.add_agent('backend', pid, '/tmp/test', 'Test task')
    end

    it 'removes agent from session' do
      result = session_manager.remove_agent(pid)
      
      expect(result).to be true
      
      session = session_manager.read_session
      expect(session[:agents]).to be_empty
    end

    it 'returns false for non-existent agent' do
      result = session_manager.remove_agent(99999)
      expect(result).to be false
    end

    it 'only removes specified agent' do
      session_manager.add_agent('frontend', 54321, '/tmp/test2', 'Test task 2')
      
      session_manager.remove_agent(pid)
      
      session = session_manager.read_session
      expect(session[:agents].size).to eq(1)
      expect(session[:agents].first[:pid]).to eq(54321)
    end
  end

  describe '#get_active_agents' do
    before do
      session_manager.create_session('Test session')
      session_manager.add_agent('backend', 12345, '/tmp/test1', 'Task 1')
      session_manager.add_agent('frontend', 54321, '/tmp/test2', 'Task 2')
      session_manager.update_agent_status(54321, 'completed', Time.now.iso8601)
    end

    it 'returns only running agents' do
      active_agents = session_manager.get_active_agents
      
      expect(active_agents.size).to eq(1)
      expect(active_agents.first[:pid]).to eq(12345)
      expect(active_agents.first[:status]).to eq('running')
    end

    it 'returns empty array when no session exists' do
      File.delete(session_file)
      
      active_agents = session_manager.get_active_agents
      expect(active_agents).to eq([])
    end
  end

  describe '#get_all_agents' do
    before do
      session_manager.create_session('Test session')
      session_manager.add_agent('backend', 12345, '/tmp/test1', 'Task 1')
      session_manager.add_agent('frontend', 54321, '/tmp/test2', 'Task 2')
    end

    it 'returns all agents regardless of status' do
      all_agents = session_manager.get_all_agents
      
      expect(all_agents.size).to eq(2)
      expect(all_agents.map { |a| a[:pid] }).to contain_exactly(12345, 54321)
    end

    it 'returns empty array when no session exists' do
      File.delete(session_file)
      
      all_agents = session_manager.get_all_agents
      expect(all_agents).to eq([])
    end
  end

  describe '#session_exists?' do
    it 'returns true when session file exists' do
      session_manager.create_session('Test session')
      expect(session_manager.session_exists?).to be true
    end

    it 'returns false when session file does not exist' do
      expect(session_manager.session_exists?).to be false
    end
  end

  describe '#session_status' do
    context 'when session exists' do
      before do
        session_manager.create_session('Test session')
        session_manager.add_agent('backend', 12345, '/tmp/test1', 'Task 1')
        session_manager.add_agent('frontend', 54321, '/tmp/test2', 'Task 2')
        session_manager.update_agent_status(54321, 'completed', Time.now.iso8601)
      end

      it 'returns comprehensive session status' do
        status = session_manager.session_status
        
        expect(status[:exists]).to be true
        expect(status[:session_id]).to be_a(String)
        expect(status[:start_time]).to be_a(String)
        expect(status[:task_description]).to eq('Test session')
        expect(status[:status]).to eq('active')
        expect(status[:total_agents]).to eq(2)
        expect(status[:active_agents]).to eq(1)
        expect(status[:completed_agents]).to eq(1)
        expect(status[:failed_agents]).to eq(0)
        expect(status[:agents]).to have(2).items
      end
    end

    context 'when session does not exist' do
      it 'returns non-existent session status' do
        status = session_manager.session_status
        expect(status[:exists]).to be false
      end
    end
  end

  describe '#close_session' do
    before do
      session_manager.create_session('Test session')
    end

    it 'marks session as completed' do
      result = session_manager.close_session
      
      expect(result).to be true
      
      session = session_manager.read_session
      expect(session[:status]).to eq('completed')
      expect(session[:end_time]).to be_a(String)
    end

    it 'returns false when no session exists' do
      File.delete(session_file)
      
      result = session_manager.close_session
      expect(result).to be false
    end
  end

  describe '#check_agent_processes' do
    before do
      session_manager.create_session('Test session')
      session_manager.add_agent('backend', 12345, '/tmp/test1', 'Task 1')
      session_manager.add_agent('frontend', 54321, '/tmp/test2', 'Task 2')
    end

    context 'when processes are running' do
      before do
        allow(session_manager).to receive(:process_running?).and_return(true)
      end

      it 'returns running agents' do
        running_agents = session_manager.check_agent_processes
        
        expect(running_agents.size).to eq(2)
        expect(running_agents.map { |a| a[:pid] }).to contain_exactly(12345, 54321)
      end
    end

    context 'when some processes have stopped' do
      before do
        allow(session_manager).to receive(:process_running?).with(12345).and_return(true)
        allow(session_manager).to receive(:process_running?).with(54321).and_return(false)
      end

      it 'updates stopped processes and returns running ones' do
        running_agents = session_manager.check_agent_processes
        
        expect(running_agents.size).to eq(1)
        expect(running_agents.first[:pid]).to eq(12345)
        
        # Check that stopped agent was updated
        session = session_manager.read_session
        stopped_agent = session[:agents].find { |a| a[:pid] == 54321 }
        expect(stopped_agent[:status]).to eq('stopped')
        expect(stopped_agent[:completion_time]).to be_a(String)
      end
    end
  end

  describe '#read_session' do
    it 'handles corrupted JSON gracefully' do
      # Write invalid JSON
      File.write(session_file, '{ invalid json }')
      
      result = session_manager.read_session
      expect(result).to be_nil
    end

    it 'handles missing file gracefully' do
      result = session_manager.read_session
      expect(result).to be_nil
    end

    it 'parses valid JSON correctly' do
      session_manager.create_session('Test session')
      
      result = session_manager.read_session
      expect(result).to be_a(Hash)
      expect(result[:task_description]).to eq('Test session')
    end
  end

  describe 'private methods' do
    describe '#process_running?' do
      context 'when process exists' do
        it 'returns true' do
          allow(Process).to receive(:kill).with(0, 12345)
          
          result = session_manager.send(:process_running?, 12345)
          expect(result).to be true
        end
      end

      context 'when process does not exist' do
        it 'returns false for ESRCH' do
          allow(Process).to receive(:kill).with(0, 12345).and_raise(Errno::ESRCH)
          
          result = session_manager.send(:process_running?, 12345)
          expect(result).to be false
        end
      end

      context 'when permission denied' do
        it 'returns true for EPERM' do
          allow(Process).to receive(:kill).with(0, 12345).and_raise(Errno::EPERM)
          
          result = session_manager.send(:process_running?, 12345)
          expect(result).to be true
        end
      end
    end

    describe '#generate_session_id' do
      it 'generates unique session IDs' do
        id1 = session_manager.send(:generate_session_id)
        id2 = session_manager.send(:generate_session_id)
        
        expect(id1).not_to eq(id2)
        expect(id1).to match(/^\d+_[a-f0-9]{8}$/)
      end
    end
  end
end