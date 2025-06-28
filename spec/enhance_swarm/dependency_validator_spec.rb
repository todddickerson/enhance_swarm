# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::DependencyValidator do
  describe '.validate_all' do
    it 'validates all required dependencies' do
      # Mock successful command execution
      allow(EnhanceSwarm::CommandExecutor).to receive(:execute)
        .with('git', '--version', timeout: 10)
        .and_return('git version 2.30.0')
      
      allow(EnhanceSwarm::CommandExecutor).to receive(:execute)
        .with('claude-swarm', '--version', timeout: 10)
        .and_raise(EnhanceSwarm::CommandExecutor::CommandError.new('Command not found'))

      result = described_class.validate_all

      expect(result[:results]).to have_key('git')
      expect(result[:results]).to have_key('claude-swarm')
      expect(result[:results]).to have_key('ruby')
      
      expect(result[:results]['git'][:passed]).to be(true)
      expect(result[:results]['git'][:version]).to eq('2.30.0')
      
      expect(result[:results]['claude-swarm'][:passed]).to be(false)
      expect(result[:results]['claude-swarm'][:available]).to be(false)
    end
  end

  describe '.validate_tool' do
    let(:git_config) do
      {
        min_version: '2.20.0',
        check_command: 'git --version',
        version_regex: /git version (\d+\.\d+\.\d+)/,
        critical: true
      }
    end

    it 'validates tool with sufficient version' do
      allow(EnhanceSwarm::CommandExecutor).to receive(:execute)
        .and_return('git version 2.30.0')

      result = described_class.validate_tool('git', git_config)

      expect(result[:passed]).to be(true)
      expect(result[:version]).to eq('2.30.0')
      expect(result[:available]).to be(true)
    end

    it 'fails validation for insufficient version' do
      allow(EnhanceSwarm::CommandExecutor).to receive(:execute)
        .and_return('git version 2.10.0')

      result = described_class.validate_tool('git', git_config)

      expect(result[:passed]).to be(false)
      expect(result[:version]).to eq('2.10.0')
      expect(result[:available]).to be(true)
      expect(result[:error]).to include('below required')
    end

    it 'handles unavailable tools' do
      allow(EnhanceSwarm::CommandExecutor).to receive(:execute)
        .and_raise(EnhanceSwarm::CommandExecutor::CommandError.new('Command not found'))

      result = described_class.validate_tool('nonexistent', git_config)

      expect(result[:passed]).to be(false)
      expect(result[:available]).to be(false)
      expect(result[:error]).to include('not available')
    end
  end

  describe '.version_meets_requirement?' do
    it 'compares versions correctly' do
      expect(described_class.version_meets_requirement?('2.30.0', '2.20.0')).to be(true)
      expect(described_class.version_meets_requirement?('2.10.0', '2.20.0')).to be(false)
      expect(described_class.version_meets_requirement?('2.20.0', '2.20.0')).to be(true)
    end

    it 'handles invalid version strings' do
      expect(described_class.version_meets_requirement?('invalid', '2.20.0')).to be(false)
      expect(described_class.version_meets_requirement?('2.30.0', 'invalid')).to be(false)
    end
  end
end