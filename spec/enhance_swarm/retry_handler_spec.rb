# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::RetryHandler do
  describe '.with_retry' do
    it 'succeeds on first attempt' do
      result = described_class.with_retry { 'success' }
      expect(result).to eq('success')
    end

    it 'retries on retryable errors' do
      attempt = 0
      result = described_class.with_retry(max_retries: 2) do
        attempt += 1
        raise EnhanceSwarm::CommandExecutor::CommandError.new('Command timed out') if attempt < 2
        'success'
      end
      
      expect(result).to eq('success')
      expect(attempt).to eq(2)
    end

    it 'fails after max retries' do
      expect do
        described_class.with_retry(max_retries: 2) do
          raise EnhanceSwarm::CommandExecutor::CommandError.new('Command timed out')
        end
      end.to raise_error(EnhanceSwarm::RetryHandler::RetryError)
    end

    it 'does not retry non-retryable errors' do
      attempt = 0
      expect do
        described_class.with_retry(max_retries: 2) do
          attempt += 1
          raise ArgumentError, 'Invalid argument'
        end
      end.to raise_error(EnhanceSwarm::RetryHandler::RetryError)
      
      expect(attempt).to eq(1)
    end
  end

  describe '.retryable_error?' do
    it 'identifies retryable command errors' do
      timeout_error = EnhanceSwarm::CommandExecutor::CommandError.new('Command timed out')
      expect(described_class.retryable_error?(timeout_error)).to be(true)
      
      not_found_error = EnhanceSwarm::CommandExecutor::CommandError.new('Command not found')
      expect(described_class.retryable_error?(not_found_error)).to be(true)
    end

    it 'identifies non-retryable errors' do
      validation_error = EnhanceSwarm::CommandExecutor::CommandError.new('Invalid command')
      expect(described_class.retryable_error?(validation_error)).to be(false)
      
      argument_error = ArgumentError.new('Invalid argument')
      expect(described_class.retryable_error?(argument_error)).to be(false)
    end

    it 'identifies retryable system errors' do
      expect(described_class.retryable_error?(Errno::ENOENT.new)).to be(true)
      expect(described_class.retryable_error?(Errno::ETIMEDOUT.new)).to be(true)
    end
  end
end