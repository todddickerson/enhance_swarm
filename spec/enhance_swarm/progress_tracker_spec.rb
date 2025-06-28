# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::ProgressTracker do
  describe '#initialize' do
    it 'initializes with default values' do
      tracker = described_class.new
      
      expect(tracker.total_steps).to eq(100)
      expect(tracker.current_step).to eq(0)
      expect(tracker.start_time).to be_within(1).of(Time.now)
      expect(tracker.used_tokens).to eq(0)
    end

    it 'initializes with custom values' do
      tracker = described_class.new(total_steps: 50, estimated_tokens: 1000)
      
      expect(tracker.total_steps).to eq(50)
      expect(tracker.estimated_tokens).to eq(1000)
    end
  end

  describe '#advance' do
    let(:tracker) { described_class.new(total_steps: 10) }

    it 'advances progress by one step by default' do
      tracker.advance
      expect(tracker.current_step).to eq(1)
    end

    it 'advances progress by specified steps' do
      tracker.advance(5)
      expect(tracker.current_step).to eq(5)
    end

    it 'does not exceed total steps' do
      tracker.advance(15)
      expect(tracker.current_step).to eq(10)
    end

    it 'updates status message when provided' do
      # We can't directly test the private status message, but we can ensure no errors
      expect { tracker.advance(1, message: 'Processing...') }.not_to raise_error
    end
  end

  describe '#set_progress' do
    let(:tracker) { described_class.new(total_steps: 10) }

    it 'sets progress to specific step' do
      tracker.set_progress(7)
      expect(tracker.current_step).to eq(7)
    end

    it 'does not exceed total steps' do
      tracker.set_progress(15)
      expect(tracker.current_step).to eq(10)
    end
  end

  describe '#add_tokens' do
    let(:tracker) { described_class.new }

    it 'increments used tokens' do
      tracker.add_tokens(100)
      expect(tracker.used_tokens).to eq(100)
      
      tracker.add_tokens(50)
      expect(tracker.used_tokens).to eq(150)
    end
  end

  describe '#complete' do
    let(:tracker) { described_class.new(total_steps: 10) }

    it 'sets progress to 100%' do
      tracker.complete
      expect(tracker.current_step).to eq(10)
    end
  end

  describe '.track' do
    it 'yields tracker and completes on success' do
      result = nil
      described_class.track(total_steps: 5) do |tracker|
        expect(tracker).to be_a(described_class)
        tracker.advance(2)
        result = 'success'
      end
      
      expect(result).to eq('success')
    end

    it 'handles exceptions and fails gracefully' do
      expect do
        described_class.track do |tracker|
          tracker.advance(1)
          raise StandardError, 'test error'
        end
      end.to raise_error(StandardError, 'test error')
    end
  end

  describe '.track_agent_operation' do
    it 'tracks single agent operation' do
      result = described_class.track_agent_operation('test_operation') do |tracker|
        expect(tracker).to be_a(described_class)
        'operation_result'
      end
      
      expect(result).to eq('operation_result')
    end

    it 'handles operation failures' do
      expect do
        described_class.track_agent_operation('failing_operation') do |tracker|
          raise StandardError, 'operation failed'
        end
      end.to raise_error(StandardError, 'operation failed')
    end
  end

  describe '.estimate_tokens_for_operation' do
    it 'returns estimates for known operation types' do
      expect(described_class.estimate_tokens_for_operation('spawn_agent')).to eq(500)
      expect(described_class.estimate_tokens_for_operation('implementation')).to eq(2000)
    end

    it 'returns default estimate for unknown operations' do
      expect(described_class.estimate_tokens_for_operation('unknown_op')).to eq(1000)
    end
  end
end