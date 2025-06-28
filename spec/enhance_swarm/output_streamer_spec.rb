# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::OutputStreamer do
  let(:streamer) { described_class.new(max_lines: 5) }

  describe '#initialize' do
    it 'initializes with default values' do
      expect(streamer.agent_outputs).to eq({})
      expect(streamer.active_agents).to eq({})
    end

    it 'accepts custom max_lines' do
      custom_streamer = described_class.new(max_lines: 10)
      expect(custom_streamer.instance_variable_get(:@max_lines)).to eq(10)
    end
  end

  describe '#add_agent' do
    it 'adds agent to tracking' do
      streamer.add_agent('test-agent', 12345, role: 'backend')
      
      expect(streamer.active_agents).to have_key('test-agent')
      expect(streamer.active_agents['test-agent'][:pid]).to eq(12345)
      expect(streamer.active_agents['test-agent'][:role]).to eq('backend')
      expect(streamer.active_agents['test-agent'][:status]).to eq('running')
      
      expect(streamer.agent_outputs).to have_key('test-agent')
      expect(streamer.agent_outputs['test-agent'][:lines]).to eq([])
    end
  end

  describe '#remove_agent' do
    before do
      streamer.add_agent('test-agent', 12345, role: 'backend')
    end

    it 'marks agent as completed' do
      streamer.remove_agent('test-agent', status: 'completed')
      
      expect(streamer.active_agents['test-agent'][:status]).to eq('completed')
      expect(streamer.active_agents['test-agent']).to have_key(:end_time)
    end

    it 'marks agent as failed' do
      streamer.remove_agent('test-agent', status: 'failed')
      
      expect(streamer.active_agents['test-agent'][:status]).to eq('failed')
    end
  end

  describe '#add_output_line' do
    before do
      streamer.add_agent('test-agent', 12345, role: 'backend')
    end

    it 'adds output line to agent' do
      streamer.add_output_line('test-agent', 'Test output line')
      
      lines = streamer.agent_outputs['test-agent'][:lines]
      expect(lines.size).to eq(1)
      expect(lines.first[:text]).to eq('Test output line')
      expect(lines.first[:timestamp]).to be_within(1).of(Time.now)
    end

    it 'limits number of lines to max_lines' do
      6.times { |i| streamer.add_output_line('test-agent', "Line #{i}") }
      
      lines = streamer.agent_outputs['test-agent'][:lines]
      expect(lines.length).to eq(5) # max_lines = 5
      expect(lines.first[:text]).to eq('Line 1') # First line removed
      expect(lines.last[:text]).to eq('Line 5')
    end

    it 'ignores empty lines' do
      streamer.add_output_line('test-agent', '')
      streamer.add_output_line('test-agent', '   ')
      
      lines = streamer.agent_outputs['test-agent'][:lines]
      expect(lines).to be_empty
    end

    it 'cleans ANSI color codes' do
      # Mock the private method for testing
      allow(streamer).to receive(:clean_output_line).and_call_original
      
      streamer.add_output_line('test-agent', "\e[31mRed text\e[0m")
      
      expect(streamer).to have_received(:clean_output_line).with("\e[31mRed text\e[0m")
    end
  end

  describe 'private methods' do
    describe '#format_duration' do
      it 'formats durations correctly' do
        expect(streamer.send(:format_duration, 30)).to eq('30s')
        expect(streamer.send(:format_duration, 90)).to eq('1m') # 90/60 = 1.5, rounds to 1
        expect(streamer.send(:format_duration, 3661)).to eq('1h')
      end
    end

    describe '#role_icon' do
      it 'returns correct icons for roles' do
        expect(streamer.send(:role_icon, 'backend')).to eq('🔧')
        expect(streamer.send(:role_icon, 'frontend')).to eq('🎨')
        expect(streamer.send(:role_icon, 'unknown')).to eq('🤖')
      end
    end

    describe '#clean_output_line' do
      it 'removes ANSI color codes' do
        result = streamer.send(:clean_output_line, "\e[31mRed\e[0m text")
        expect(result).to eq('Red text')
      end

      it 'removes carriage returns' do
        result = streamer.send(:clean_output_line, "Line 1\r\nLine 2")
        expect(result).to eq('Line 1Line 2')
      end

      it 'limits line length' do
        long_line = 'a' * 100
        result = streamer.send(:clean_output_line, long_line)
        expect(result.length).to eq(55)
      end
    end

    describe '#process_running?' do
      it 'returns true for valid process' do
        # Use current process PID which should be running
        expect(streamer.send(:process_running?, Process.pid)).to be(true)
      end

      it 'returns false for invalid process' do
        # Use a PID that definitely doesn't exist
        expect(streamer.send(:process_running?, 999999)).to be(false)
      end
    end
  end

  describe '.stream_agents' do
    it 'creates streamer and processes agents' do
      agents = [
        { id: 'test-1', pid: Process.pid, role: 'backend' }
      ]
      
      # Mock the streamer instance
      mock_streamer = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(mock_streamer)
      allow(mock_streamer).to receive(:start_streaming)
      allow(mock_streamer).to receive(:stop_streaming)
      allow(mock_streamer).to receive(:add_agent)
      allow(mock_streamer).to receive(:active_agents).and_return({})
      
      # Mock signal handling to avoid actually trapping signals in tests
      allow_any_instance_of(Object).to receive(:trap)
      
      described_class.stream_agents(agents)
      
      expect(mock_streamer).to have_received(:start_streaming)
      expect(mock_streamer).to have_received(:add_agent).with('test-1', Process.pid, role: 'backend')
      expect(mock_streamer).to have_received(:stop_streaming)
    end
  end
end