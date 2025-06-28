# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::AgentCommunicator do
  let(:communicator) { described_class.instance }
  let(:test_agent_id) { 'backend-auth-123' }
  let(:communication_dir) { '.enhance_swarm/communication' }

  before do
    # Clean up any existing communication directory
    FileUtils.rm_rf(communication_dir) if Dir.exist?(communication_dir)
    # Reset the singleton instance state
    communicator.instance_variable_set(:@pending_messages, {})
    communicator.instance_variable_set(:@user_responses, {})
    # Ensure communication directory is recreated
    communicator.send(:ensure_communication_directory)
  end

  after do
    # Clean up test files
    FileUtils.rm_rf(communication_dir) if Dir.exist?(communication_dir)
    # Stop any monitoring
    communicator.stop_monitoring
  end

  describe '#initialize' do
    it 'creates communication directory' do
      described_class.instance
      expect(Dir.exist?(communication_dir)).to be(true)
    end

    it 'initializes with empty state' do
      expect(communicator.pending_messages).to be_empty
      expect(communicator.recent_messages).to be_empty
    end
  end

  describe '#agent_message' do
    it 'creates and saves a message' do
      message_id = communicator.agent_message(
        test_agent_id,
        :status,
        'Working on authentication',
        { role: 'backend', priority: :medium }
      )

      expect(message_id).to include(test_agent_id)
      
      # Check message file was created
      message_files = Dir.glob(File.join(communication_dir, 'agent_*.json'))
      expect(message_files.size).to eq(1)
      
      # Check message content
      message_data = JSON.parse(File.read(message_files.first))
      expect(message_data['agent_id']).to eq(test_agent_id)
      expect(message_data['type']).to eq('status')
      expect(message_data['content']).to eq('Working on authentication')
      expect(message_data['priority']).to eq('medium')
    end

    it 'adds message to pending if requires_response is true' do
      message_id = communicator.agent_message(
        test_agent_id,
        :question,
        'Should I use bcrypt?',
        { requires_response: true }
      )

      expect(communicator.pending_messages.size).to eq(1)
      expect(communicator.pending_messages.first[:id]).to eq(message_id)
    end
  end

  describe '#agent_question' do
    it 'creates a question message requiring response' do
      quick_actions = ['Yes, use bcrypt', 'No, use another method']
      
      message_id = communicator.agent_question(
        test_agent_id,
        'Should I implement password hashing with bcrypt?',
        quick_actions
      )

      expect(communicator.pending_messages.size).to eq(1)
      
      message = communicator.pending_messages.first
      expect(message[:type]).to eq(:question)
      expect(message[:requires_response]).to be(true)
      expect(message[:quick_actions]).to eq(quick_actions)
      expect(message[:priority]).to eq(:high)
    end
  end

  describe '#agent_status' do
    it 'creates a status message not requiring response' do
      communicator.agent_status(test_agent_id, 'Completed user model', { 
        tests_passed: 15 
      })

      expect(communicator.pending_messages.size).to eq(0)
      expect(communicator.recent_messages.size).to eq(1)
      
      message = communicator.recent_messages.first
      expect(message[:type]).to eq('status')
      expect(message[:requires_response]).to be(false)
      expect(message[:priority]).to eq('low')
      expect(message[:context][:tests_passed]).to eq(15)
    end
  end

  describe '#agent_progress' do
    it 'creates a progress message with percentage and eta' do
      eta = Time.now + 3600
      
      communicator.agent_progress(
        test_agent_id,
        'Authentication system 75% complete',
        75,
        eta
      )

      message = communicator.recent_messages.first
      expect(message[:type]).to eq('progress')
      expect(message[:content]).to eq('Authentication system 75% complete')
      expect(message[:context][:percentage]).to eq(75)
      expect(message[:context][:eta]).to eq(eta.iso8601)
    end
  end

  describe '#agent_decision' do
    it 'creates a decision message with immediate prompt' do
      options = ['Option A', 'Option B', 'Option C']
      
      message_id = communicator.agent_decision(
        test_agent_id,
        'Which authentication method should I implement?',
        options,
        'Option A'
      )

      expect(communicator.pending_messages.size).to eq(1)
      
      message = communicator.pending_messages.first
      expect(message[:type]).to eq(:decision)
      expect(message[:requires_response]).to be(true)
      expect(message[:quick_actions]).to eq(options)
      expect(message[:context][:default]).to eq('Option A')
      expect(message[:priority]).to eq(:high)
    end
  end

  describe '#user_respond' do
    let(:message_id) do
      communicator.agent_question(
        test_agent_id,
        'Test question?',
        ['Yes', 'No']
      )
    end

    it 'records user response and removes from pending' do
      result = communicator.user_respond(message_id, 'Yes')
      
      expect(result).to be(true)
      expect(communicator.pending_messages.size).to eq(0)
      
      # Check response file was created
      response_file = File.join(communication_dir, "response_#{message_id}.json")
      expect(File.exist?(response_file)).to be(true)
      
      response_data = JSON.parse(File.read(response_file))
      expect(response_data['response']).to eq('Yes')
      expect(response_data['message_id']).to eq(message_id)
    end

    it 'returns false for non-existent message ID' do
      result = communicator.user_respond('non-existent-id', 'Yes')
      expect(result).to be(false)
    end
  end

  describe '#agent_get_response' do
    let(:message_id) { 'test-message-123' }

    it 'returns response when available' do
      # Create a response file
      response_file = File.join(communication_dir, "response_#{message_id}.json")
      FileUtils.mkdir_p(communication_dir)
      File.write(response_file, JSON.generate({
        message_id: message_id,
        response: 'Test response'
      }))

      response = communicator.agent_get_response(message_id, 1)
      expect(response).to eq('Test response')
      
      # Response file should be deleted after reading
      expect(File.exist?(response_file)).to be(false)
    end

    it 'returns nil on timeout' do
      response = communicator.agent_get_response(message_id, 1)
      expect(response).to be_nil
    end
  end

  describe '#pending_messages' do
    it 'returns messages sorted by timestamp' do
      # Create multiple messages with slight time difference
      id1 = communicator.agent_question(test_agent_id, 'First question?', [])
      sleep(0.1)
      id2 = communicator.agent_question(test_agent_id, 'Second question?', [])
      
      pending = communicator.pending_messages
      expect(pending.size).to eq(2)
      expect(pending.first[:id]).to eq(id1)
      expect(pending.last[:id]).to eq(id2)
    end
  end

  describe '#recent_messages' do
    it 'returns limited number of recent messages' do
      5.times { |i| 
        communicator.agent_status(test_agent_id, "Status #{i}")
        sleep(0.01) # Ensure different timestamps
      }
      
      recent = communicator.recent_messages(3)
      expect(recent.size).to eq(3)
      
      # Check that we got some of the messages with Status prefix
      content_values = recent.map { |msg| msg[:content] }
      status_messages = content_values.select { |content| content.start_with?('Status') }
      expect(status_messages.size).to eq(3)
    end
  end

  describe '#cleanup_old_messages' do
    it 'removes messages older than specified days' do
      # Create a message
      message_id = communicator.agent_status(test_agent_id, 'Old status')
      
      # Modify file timestamp to simulate old message
      message_file = Dir.glob(File.join(communication_dir, 'agent_*.json')).first
      old_time = Time.now - (8 * 24 * 60 * 60) # 8 days ago
      File.utime(old_time, old_time, message_file)
      
      # Modify message content to have old timestamp
      message_data = JSON.parse(File.read(message_file))
      message_data['timestamp'] = old_time.iso8601
      File.write(message_file, JSON.generate(message_data))
      
      communicator.cleanup_old_messages(7)
      
      # Message file should be deleted
      expect(File.exist?(message_file)).to be(false)
    end
  end

  describe 'singleton pattern' do
    it 'provides singleton access' do
      expect(described_class.instance).to be_a(described_class)
      expect(described_class.instance).to eq(described_class.instance)
    end

    it 'delegates class methods to instance' do
      expect(described_class.instance).to receive(:agent_status)
        .with(test_agent_id, 'test message')
      
      described_class.agent_status(test_agent_id, 'test message')
    end
  end

  describe 'monitoring' do
    it 'starts and stops monitoring thread' do
      communicator.start_monitoring
      expect(communicator.instance_variable_get(:@monitoring_active)).to be(true)
      expect(communicator.instance_variable_get(:@monitoring_thread)).to be_a(Thread)
      
      communicator.stop_monitoring
      expect(communicator.instance_variable_get(:@monitoring_active)).to be(false)
    end
  end

  describe 'CLI integration methods' do
    before do
      # Create some test messages
      communicator.agent_question(test_agent_id, 'Test question?', ['Yes', 'No'])
      communicator.agent_status(test_agent_id, 'Working on auth')
      communicator.agent_progress(test_agent_id, '50% complete', 50)
    end

    describe '#show_pending_messages' do
      it 'displays pending messages without error' do
        expect { communicator.show_pending_messages }.not_to raise_error
      end
    end

    describe '#interactive_response_mode' do
      it 'handles empty pending messages' do
        # Clear pending messages
        communicator.instance_variable_set(:@pending_messages, {})
        
        expect { communicator.interactive_response_mode }.not_to raise_error
      end
    end
  end
end