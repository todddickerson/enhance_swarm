# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe EnhanceSwarm::Configuration do
  let(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(config.project_name).to eq('Project')
      expect(config.test_command).to eq('bundle exec rails test')
      expect(config.max_concurrent_agents).to eq(4)
    end
  end

  describe 'validation methods' do
    describe '#validate_string' do
      it 'sanitizes dangerous characters' do
        result = config.send(:validate_string, 'test`command')
        expect(result).to eq('testcommand')
      end

      it 'returns nil for empty strings' do
        result = config.send(:validate_string, '`$\\;|&')
        expect(result).to be_nil
      end

      it 'preserves safe content' do
        result = config.send(:validate_string, 'normal text')
        expect(result).to eq('normal text')
      end
    end

    describe '#validate_command' do
      it 'allows safe commands' do
        result = config.send(:validate_command, 'bundle exec test')
        expect(result).to eq('bundle exec test')
      end

      it 'rejects dangerous patterns' do
        result = config.send(:validate_command, 'rm -rf /')
        expect(result).to be_nil
      end

      it 'removes shell metacharacters' do
        result = config.send(:validate_command, 'echo hello; rm file')
        expect(result).to eq('echo hello rm file')
      end
    end

    describe '#validate_positive_integer' do
      it 'accepts positive integers' do
        expect(config.send(:validate_positive_integer, 5)).to eq(5)
        expect(config.send(:validate_positive_integer, '10')).to eq(10)
      end

      it 'rejects negative numbers and zero' do
        expect(config.send(:validate_positive_integer, 0)).to be_nil
        expect(config.send(:validate_positive_integer, -5)).to be_nil
      end

      it 'rejects non-numeric strings' do
        expect(config.send(:validate_positive_integer, 'abc')).to be_nil
      end
    end
  end

  describe '#load_from_file' do
    it 'handles missing files gracefully' do
      allow(File).to receive(:exist?).and_return(false)
      expect { config.send(:load_from_file) }.not_to raise_error
    end

    it 'handles invalid YAML gracefully' do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return('invalid: yaml: content:')
      
      expect do
        config.send(:load_from_file)
      end.not_to raise_error
    end
  end
end