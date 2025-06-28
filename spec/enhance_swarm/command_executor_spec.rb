# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::CommandExecutor do
  describe '.execute' do
    it 'executes safe commands successfully' do
      result = described_class.execute('echo', 'hello')
      expect(result).to eq('hello')
    end

    it 'raises error for dangerous commands' do
      expect do
        described_class.execute('rm -rf /')
      end.to raise_error(ArgumentError, /Invalid command/)
    end

    it 'sanitizes arguments' do
      result = described_class.execute('echo', 'hello; rm -rf /')
      expect(result).to include('hello\\;')
      expect(result).to include('rm') # rm is escaped but still present
    end

    it 'handles command failures' do
      expect do
        described_class.execute('false')
      end.to raise_error(EnhanceSwarm::CommandExecutor::CommandError)
    end

    it 'handles timeouts' do
      expect do
        described_class.execute('sleep', '10', timeout: 1)
      end.to raise_error(EnhanceSwarm::CommandExecutor::CommandError, /timed out/)
    end
  end

  describe '.command_available?' do
    it 'returns true for available commands' do
      expect(described_class.command_available?('echo')).to be(true)
    end

    it 'returns false for unavailable commands' do
      expect(described_class.command_available?('nonexistent_command_12345')).to be(false)
    end
  end

  describe '.sanitize_command' do
    it 'allows safe commands' do
      expect(described_class.send(:sanitize_command, 'git')).to eq('git')
      expect(described_class.send(:sanitize_command, 'bundle')).to eq('bundle')
    end

    it 'rejects dangerous characters' do
      expect do
        described_class.send(:sanitize_command, 'rm -rf')
      end.to raise_error(ArgumentError)
    end
  end
end