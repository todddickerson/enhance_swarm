# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::ControlAgent do
  let(:task_description) { 'Implement user authentication system' }
  let(:config) { EnhanceSwarm.configuration }
  let(:control_agent) { described_class.new(task_description, config) }

  describe '#initialize' do
    it 'initializes with task and config' do
      expect(control_agent.task).to eq(task_description)
      expect(control_agent.config).to eq(config)
      expect(control_agent.status).to eq('initializing')
      expect(control_agent.worker_agents).to be_empty
      expect(control_agent.start_time).to be_within(1).of(Time.now)
    end

    it 'uses default config when none provided' do
      agent = described_class.new(task_description)
      expect(agent.config).to be_a(EnhanceSwarm::Configuration)
    end
  end

  describe '#current_status' do
    let(:status_file) { control_agent.instance_variable_get(:@communication_file) }

    context 'when communication file does not exist' do
      it 'returns default status' do
        status = control_agent.current_status
        
        expect(status['status']).to eq('initializing')
        expect(status['phase']).to eq('initializing')
        expect(status['active_agents']).to be_empty
        expect(status['progress_percentage']).to eq(0)
      end
    end

    context 'when communication file has valid JSON' do
      let(:mock_status) do
        {
          'status' => 'coordinating',
          'phase' => 'backend_implementation',
          'active_agents' => ['backend-auth-123'],
          'completed_agents' => [],
          'progress_percentage' => 30,
          'message' => 'Backend agent implementing User model'
        }
      end

      before do
        File.write(status_file, mock_status.to_json)
      end

      after do
        File.unlink(status_file) if File.exist?(status_file)
      end

      it 'parses and returns the status' do
        status = control_agent.current_status
        
        expect(status['status']).to eq('coordinating')
        expect(status['phase']).to eq('backend_implementation')
        expect(status['active_agents']).to eq(['backend-auth-123'])
        expect(status['progress_percentage']).to eq(30)
      end
    end

    context 'when communication file has invalid JSON' do
      before do
        File.write(status_file, 'invalid json{')
      end

      after do
        File.unlink(status_file) if File.exist?(status_file)
      end

      it 'returns default status and logs warning' do
        expect(EnhanceSwarm::Logger).to receive(:warn).with(/Failed to parse control agent status/)
        
        status = control_agent.current_status
        expect(status['status']).to eq('initializing')
      end
    end
  end

  describe '#worker_agent_summary' do
    it 'returns summary of worker agents' do
      # Mock current_status to return test data
      allow(control_agent).to receive(:current_status).and_return({
        'active_agents' => ['backend-123', 'frontend-456'],
        'completed_agents' => ['qa-789'],
        'progress_percentage' => 75,
        'phase' => 'frontend_integration',
        'estimated_completion' => '2025-06-28T20:30:00Z'
      })

      summary = control_agent.worker_agent_summary

      expect(summary[:total]).to eq(3)
      expect(summary[:active]).to eq(2)
      expect(summary[:completed]).to eq(1)
      expect(summary[:progress]).to eq(75)
      expect(summary[:phase]).to eq('frontend_integration')
      expect(summary[:estimated_completion]).to eq('2025-06-28T20:30:00Z')
    end
  end

  describe '#build_control_agent_prompt' do
    it 'builds comprehensive prompt for Control Agent' do
      prompt = control_agent.send(:build_control_agent_prompt)
      
      expect(prompt).to include('AUTONOMOUS CONTROL AGENT')
      expect(prompt).to include(task_description)
      expect(prompt).to include('backend: Models, APIs, database')
      expect(prompt).to include('frontend: Controllers, views, JavaScript')
      expect(prompt).to include('claude-swarm start --role=')
      expect(prompt).to include(Dir.pwd)
      expect(prompt).to include('JSON format')
    end

    it 'includes project configuration details' do
      prompt = control_agent.send(:build_control_agent_prompt)
      
      expect(prompt).to include(Array(config.technology_stack).join(', '))
      expect(prompt).to include(config.test_command)
      expect(prompt).to include(config.project_name)
    end
  end

  describe '#start_coordination' do
    before do
      # Mock the command executor to avoid actually spawning processes
      allow(EnhanceSwarm::CommandExecutor).to receive(:execute_async).and_return(12345)
      allow(control_agent).to receive(:coordinate_agents).and_return(double(join: nil))
    end

    it 'spawns control agent and starts coordination' do
      expect(EnhanceSwarm::Logger).to receive(:info).with(/Starting Control Agent/)
      expect(EnhanceSwarm::Logger).to receive(:info).with(/Control Agent spawned with PID/)
      expect(EnhanceSwarm::CommandExecutor).to receive(:execute_async)
        .with('claude', '--role=control', '--file', anything, '--output', anything, '--continuous')
      
      control_agent.start_coordination
      
      expect(control_agent.status).to eq('coordinating')
    end

    it 'handles spawn failures gracefully' do
      allow(EnhanceSwarm::CommandExecutor).to receive(:execute_async)
        .and_raise(EnhanceSwarm::CommandExecutor::CommandError.new('Command failed'))
      
      expect(EnhanceSwarm::Logger).to receive(:error).with(/Failed to spawn Control Agent/)
      
      expect { control_agent.start_coordination }.to raise_error(EnhanceSwarm::RetryHandler::RetryError)
      expect(control_agent.status).to eq('failed')
    end
  end

  describe '#stop_coordination' do
    before do
      control_agent.instance_variable_set(:@control_process, 12345)
    end

    it 'terminates control agent process and cleans up' do
      expect(Process).to receive(:kill).with('TERM', 12345)
      expect(Process).to receive(:wait).with(12345)
      expect(control_agent).to receive(:cleanup_resources)
      
      control_agent.stop_coordination
      
      expect(control_agent.status).to eq('stopping')
    end

    it 'handles process termination errors gracefully' do
      allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
      expect(control_agent).to receive(:cleanup_resources)
      
      expect { control_agent.stop_coordination }.not_to raise_error
    end
  end

  describe '.coordinate_task' do
    it 'creates and manages control agent lifecycle' do
      mock_agent = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:start_coordination).and_return(double(join: nil))
      allow(mock_agent).to receive(:current_status).and_return({ 'status' => 'completed' })
      allow(mock_agent).to receive(:stop_coordination)

      result = described_class.coordinate_task(task_description) do |agent|
        expect(agent).to eq(mock_agent)
      end

      expect(mock_agent).to have_received(:start_coordination)
      expect(mock_agent).to have_received(:stop_coordination)
      expect(result).to eq({ 'status' => 'completed' })
    end
  end

  describe '#update_worker_agents' do
    let(:agent_status) do
      {
        'active_agents' => ['backend-123'],
        'completed_agents' => ['qa-456']
      }
    end

    it 'tracks new active agents' do
      control_agent.send(:update_worker_agents, agent_status)
      
      expect(control_agent.worker_agents['backend-123']).to include(
        id: 'backend-123',
        status: 'active'
      )
    end

    it 'updates completed agents' do
      # First add an active agent
      control_agent.worker_agents['qa-456'] = { id: 'qa-456', status: 'active' }
      
      control_agent.send(:update_worker_agents, agent_status)
      
      expect(control_agent.worker_agents['qa-456'][:status]).to eq('completed')
      expect(control_agent.worker_agents['qa-456']).to have_key(:completion_time)
    end
  end

  describe '#create_communication_file' do
    it 'creates a temporary file for communication' do
      file_path = control_agent.send(:create_communication_file)
      
      expect(File.exist?(file_path)).to be(true)
      expect(file_path).to include('control_agent_status')
      expect(file_path).to end_with('.json')
      
      # Cleanup
      File.unlink(file_path)
    end
  end
end