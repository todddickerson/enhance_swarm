# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::ErrorRecovery do
  let(:error_recovery) { described_class.instance }
  let(:recovery_dir) { '.enhance_swarm' }
  let(:strategies_file) { '.enhance_swarm/error_recovery_strategies.json' }
  let(:patterns_file) { '.enhance_swarm/error_patterns.json' }

  before do
    # Clean up any existing recovery data
    FileUtils.rm_rf(recovery_dir) if Dir.exist?(recovery_dir)
    
    # Reset singleton instance
    described_class.instance_variable_set(:@instance, nil)
  end

  after do
    # Clean up test files
    FileUtils.rm_rf(recovery_dir) if Dir.exist?(recovery_dir)
  end

  describe '#initialize' do
    it 'initializes with default recovery strategies' do
      expect(error_recovery.instance_variable_get(:@recovery_strategies)).to be_a(Hash)
      expect(error_recovery.instance_variable_get(:@error_patterns)).to be_a(Hash)
      expect(error_recovery.instance_variable_get(:@recovery_history)).to be_an(Array)
    end

    it 'creates recovery directory' do
      # Force initialization by accessing the instance
      error_recovery
      # Check that the directory was created
      expect(Dir.exist?(File.dirname(strategies_file))).to be(true)
    end
  end

  describe '#analyze_error' do
    let(:test_error) { StandardError.new('Connection timeout after 30 seconds') }

    it 'analyzes error and returns structured information' do
      result = error_recovery.analyze_error(test_error, { agent_id: 'test-123' })
      
      expect(result).to have_key(:error)
      expect(result).to have_key(:patterns)
      expect(result).to have_key(:suggestions)
      expect(result).to have_key(:auto_recoverable)
      
      expect(result[:error][:message]).to eq(test_error.message)
      expect(result[:error][:type]).to eq('StandardError')
      expect(result[:error][:context]).to include(agent_id: 'test-123')
    end

    it 'identifies network errors correctly' do
      network_error = StandardError.new('Connection refused')
      result = error_recovery.analyze_error(network_error)
      
      expect(result[:suggestions]).to be_an(Array)
      expect(result[:suggestions].any? { |s| s['description']&.include?('network') || s[:description]&.include?('network') }).to be(true)
    end

    it 'identifies file not found errors correctly' do
      file_error = StandardError.new('No such file or directory')
      result = error_recovery.analyze_error(file_error)
      
      expect(result[:suggestions]).to be_an(Array)
      expect(result[:suggestions].any? { |s| s['description']&.include?('file') || s[:description]&.include?('file') }).to be(true)
    end

    it 'logs error occurrence' do
      error_recovery.analyze_error(test_error)
      
      history = error_recovery.instance_variable_get(:@recovery_history)
      expect(history).not_to be_empty
      expect(history.last[:error][:message]).to eq(test_error.message)
    end
  end

  describe '#explain_error' do
    it 'provides human-readable explanation for known patterns' do
      error = StandardError.new('Connection timeout')
      explanation = error_recovery.explain_error(error, { context: 'network_request' })
      
      expect(explanation).to have_key(:explanation)
      expect(explanation).to have_key(:likely_cause)
      expect(explanation).to have_key(:prevention_tips)
      expect(explanation[:prevention_tips]).to be_an(Array)
    end

    it 'provides generic explanation for unknown errors' do
      error = RuntimeError.new('Unknown mysterious error')
      explanation = error_recovery.explain_error(error)
      
      expect(explanation[:explanation]).to include('RuntimeError')
      expect(explanation[:likely_cause]).to include('unclear')
      expect(explanation[:prevention_tips]).to be_an(Array)
    end
  end

  describe '#attempt_recovery' do
    let(:test_error) { StandardError.new('Connection timeout') }
    let(:error_analysis) { error_recovery.analyze_error(test_error) }

    it 'returns false for non-auto-recoverable errors' do
      allow(error_recovery).to receive(:auto_recoverable?).and_return(false)
      analysis = { auto_recoverable: false, suggestions: [] }
      
      result = error_recovery.attempt_recovery(analysis)
      expect(result).to be(false)
    end

    it 'attempts recovery for auto-recoverable errors' do
      analysis = {
        auto_recoverable: true,
        suggestions: [
          { 'auto_executable' => true, 'action' => 'retry_with_backoff', 'description' => 'Retry with backoff' }
        ],
        error: { message: 'test error', type: 'StandardError' }
      }
      
      # Mock the execute_recovery_action method
      allow(error_recovery).to receive(:execute_recovery_action).and_return({ success: true })
      
      result = error_recovery.attempt_recovery(analysis, {})
      expect(result[:success]).to be(true)
    end

    it 'logs recovery attempts' do
      analysis = {
        auto_recoverable: true,
        suggestions: [
          { 'auto_executable' => true, 'action' => 'retry_with_backoff', 'description' => 'Retry with backoff' }
        ],
        error: { message: 'test error', type: 'StandardError' }
      }
      
      allow(error_recovery).to receive(:execute_recovery_action).and_return({ success: false })
      
      result = error_recovery.attempt_recovery(analysis, {})
      expect(result[:attempts]).to be_an(Array)
      expect(result[:attempts]).not_to be_empty
    end
  end

  describe '#learn_from_manual_recovery' do
    let(:test_error) { StandardError.new('Build failed') }
    let(:recovery_steps) { ['Check dependencies', 'Run bundle install', 'Retry build'] }

    it 'learns from successful manual recovery' do
      error_recovery.learn_from_manual_recovery(test_error, recovery_steps, { context: 'build_failure' })
      
      patterns = error_recovery.instance_variable_get(:@error_patterns)
      expect(patterns).not_to be_empty
      
      # Should have created a pattern for this error
      pattern = patterns.values.first
      expect(pattern['successful_recoveries']).not_to be_empty
      expect(pattern['successful_recoveries'].first['steps']).to eq(recovery_steps)
    end

    it 'saves patterns to file' do
      error_recovery.learn_from_manual_recovery(test_error, recovery_steps)
      
      expect(File.exist?(patterns_file)).to be(true)
      patterns_data = JSON.parse(File.read(patterns_file))
      expect(patterns_data).not_to be_empty
    end

    it 'updates existing patterns' do
      # Learn first recovery
      error_recovery.learn_from_manual_recovery(test_error, recovery_steps)
      initial_patterns = error_recovery.instance_variable_get(:@error_patterns)
      first_pattern = initial_patterns.values.first
      initial_count = first_pattern['successful_recoveries'].count
      
      # Learn second recovery - same error type should go to same pattern
      error_recovery.learn_from_manual_recovery(test_error, ['Clear cache', 'Rebuild'])
      
      updated_patterns = error_recovery.instance_variable_get(:@error_patterns)
      updated_pattern = updated_patterns.values.find { |p| p['successful_recoveries'].count > initial_count }
      
      expect(updated_pattern).not_to be_nil
      expect(updated_pattern['successful_recoveries'].count).to be > initial_count
    end
  end

  describe '#recovery_statistics' do
    before do
      # Add some test recovery history
      error_recovery.instance_variable_set(:@recovery_history, [
        {
          error: { type: 'NetworkError', message: 'Connection failed' },
          timestamp: Time.now.iso8601,
          recovery_attempted: true,
          recovery_successful: true
        },
        {
          error: { type: 'FileError', message: 'File not found' },
          timestamp: Time.now.iso8601,
          recovery_attempted: true,
          recovery_successful: false
        },
        {
          error: { type: 'NetworkError', message: 'Timeout' },
          timestamp: Time.now.iso8601,
          recovery_attempted: false,
          recovery_successful: false
        }
      ])
    end

    it 'calculates recovery statistics correctly' do
      stats = error_recovery.recovery_statistics
      
      expect(stats[:total_errors_processed]).to eq(3)
      expect(stats[:successful_automatic_recoveries]).to eq(1)
      expect(stats[:recovery_success_rate]).to eq(33.3)
      expect(stats[:most_common_errors]).to have_key('NetworkError')
      expect(stats[:most_common_errors]['NetworkError']).to eq(2)
    end

    it 'handles empty history gracefully' do
      error_recovery.instance_variable_set(:@recovery_history, [])
      
      stats = error_recovery.recovery_statistics
      expect(stats[:total_errors_processed]).to eq(0)
      expect(stats[:recovery_success_rate]).to eq(0.0)
    end
  end

  describe '#cleanup_old_data' do
    before do
      # Add test data with old timestamps
      old_time = (Time.now - 40 * 24 * 60 * 60).iso8601 # 40 days ago
      recent_time = (Time.now - 10 * 24 * 60 * 60).iso8601 # 10 days ago
      
      error_recovery.instance_variable_set(:@recovery_history, [
        { error: { type: 'OldError' }, timestamp: old_time, recovery_attempted: false, recovery_successful: false },
        { error: { type: 'RecentError' }, timestamp: recent_time, recovery_attempted: false, recovery_successful: false }
      ])
      
      error_recovery.instance_variable_set(:@error_patterns, {
        'old_pattern' => { 'last_seen' => old_time, 'successful_recoveries' => [] },
        'recent_pattern' => { 'last_seen' => recent_time, 'successful_recoveries' => [] }
      })
    end

    it 'removes old recovery history' do
      error_recovery.cleanup_old_data(30) # Keep last 30 days
      
      history = error_recovery.instance_variable_get(:@recovery_history)
      expect(history.count).to eq(1)
      expect(history.first[:error][:type]).to eq('RecentError')
    end

    it 'removes old error patterns' do
      error_recovery.cleanup_old_data(30)
      
      patterns = error_recovery.instance_variable_get(:@error_patterns)
      expect(patterns.keys).to contain_exactly('recent_pattern')
    end
  end

  describe 'singleton pattern' do
    it 'provides singleton access' do
      expect(described_class.instance).to be_a(described_class)
      expect(described_class.instance).to eq(described_class.instance)
    end

    it 'delegates class methods to instance' do
      test_error = StandardError.new('test')
      expect(described_class.analyze_error(test_error)).to be_a(Hash)
      expect(described_class.recovery_statistics).to be_a(Hash)
    end
  end

  describe 'private helper methods' do
    describe '#network_error?' do
      it 'identifies network errors correctly' do
        network_error = { message: 'Connection timeout occurred' }
        result = error_recovery.send(:network_error?, network_error)
        expect(result).to be(true)
      end

      it 'returns false for non-network errors' do
        other_error = { message: 'Invalid syntax error' }
        result = error_recovery.send(:network_error?, other_error)
        expect(result).to be(false)
      end
    end

    describe '#file_system_error?' do
      it 'identifies file system errors correctly' do
        fs_error = { message: 'No such file or directory' }
        result = error_recovery.send(:file_system_error?, fs_error)
        expect(result).to be(true)
      end

      it 'returns false for non-filesystem errors' do
        other_error = { message: 'Network connection failed' }
        result = error_recovery.send(:file_system_error?, other_error)
        expect(result).to be(false)
      end
    end

    describe '#dependency_error?' do
      it 'identifies dependency errors correctly' do
        dep_error = { message: 'Cannot load such file -- missing_gem' }
        result = error_recovery.send(:dependency_error?, dep_error)
        expect(result).to be(true)
      end
    end

    describe '#timeout_error?' do
      it 'identifies timeout errors by type' do
        timeout_error = { type: 'TimeoutError', message: 'Operation timed out' }
        result = error_recovery.send(:timeout_error?, timeout_error)
        expect(result).to be(true)
      end

      it 'identifies timeout errors by message' do
        timeout_error = { type: 'StandardError', message: 'Request timeout after 30s' }
        result = error_recovery.send(:timeout_error?, timeout_error)
        expect(result).to be(true)
      end
    end

    describe '#memory_error?' do
      it 'identifies memory errors correctly' do
        memory_error = { message: 'Cannot allocate memory' }
        result = error_recovery.send(:memory_error?, memory_error)
        expect(result).to be(true)
      end
    end

    describe '#critical_error?' do
      it 'identifies critical system errors' do
        critical_error = { message: 'Segmentation fault occurred' }
        result = error_recovery.send(:critical_error?, critical_error)
        expect(result).to be(true)
      end

      it 'returns false for non-critical errors' do
        normal_error = { message: 'Invalid input provided' }
        result = error_recovery.send(:critical_error?, normal_error)
        expect(result).to be(false)
      end
    end

    describe '#generate_default_file_content' do
      it 'generates appropriate content for Ruby files' do
        content = error_recovery.send(:generate_default_file_content, 'test.rb')
        expect(content).to include('frozen_string_literal')
        expect(content).to include('Ruby')
      end

      it 'generates appropriate content for JavaScript files' do
        content = error_recovery.send(:generate_default_file_content, 'test.js')
        expect(content).to include('JavaScript')
      end

      it 'generates appropriate content for JSON files' do
        content = error_recovery.send(:generate_default_file_content, 'test.json')
        expect(content.strip).to eq('{}')
      end

      it 'generates appropriate content for Markdown files' do
        content = error_recovery.send(:generate_default_file_content, 'my-awesome-file.md')
        expect(content).to include('# My Awesome File')
      end
    end

    describe '#extract_message_pattern' do
      it 'extracts patterns from error messages' do
        message = 'No such file or directory - /path/to/file.txt'
        pattern = error_recovery.send(:extract_message_pattern, message)
        expect(pattern).to include('<PATH>')
        expect(pattern).not_to include('/path/to/file.txt')
      end

      it 'replaces numbers with placeholders' do
        message = 'Connection timeout after 30 seconds'
        pattern = error_recovery.send(:extract_message_pattern, message)
        expect(pattern).to include('<NUMBER>')
        expect(pattern).not_to include('30')
      end
    end

    describe '#calculate_pattern_match_confidence' do
      let(:error_info) do
        {
          type: 'StandardError',
          message: 'Connection timeout after 30 seconds',
          context: { agent_id: 'test-123' }
        }
      end

      let(:pattern) do
        {
          error_signatures: [
            {
              error_type: 'StandardError',
              message_pattern: 'connection timeout',
              context_patterns: ['agent_id']
            }
          ]
        }
      end

      it 'calculates high confidence for exact matches' do
        confidence = error_recovery.send(:calculate_pattern_match_confidence, error_info, pattern)
        expect(confidence).to be > 0.5
      end

      it 'returns zero confidence for no signatures' do
        empty_pattern = { error_signatures: [] }
        confidence = error_recovery.send(:calculate_pattern_match_confidence, error_info, empty_pattern)
        expect(confidence).to eq(0.0)
      end
    end
  end

  describe 'recovery action execution' do
    describe '#retry_with_backoff' do
      it 'succeeds when retry block is provided and succeeds' do
        suggestion = { 'max_attempts' => 2, 'base_delay' => 0.1 }
        context = { retry_block: proc { 'success' } }
        
        result = error_recovery.send(:retry_with_backoff, suggestion, context)
        expect(result[:success]).to be(true)
        expect(result[:result]).to eq('success')
        expect(result[:attempts]).to eq(1)
      end

      it 'retries on failure and eventually succeeds' do
        attempt_count = 0
        suggestion = { 'max_attempts' => 3, 'base_delay' => 0.01 }
        context = {
          retry_block: proc do
            attempt_count += 1
            raise StandardError, 'fail' if attempt_count < 3
            'success'
          end
        }
        
        result = error_recovery.send(:retry_with_backoff, suggestion, context)
        expect(result[:success]).to be(true)
        expect(result[:attempts]).to eq(3)
      end

      it 'fails after max attempts' do
        suggestion = { 'max_attempts' => 2, 'base_delay' => 0.01 }
        context = { retry_block: proc { raise StandardError, 'persistent failure' } }
        
        result = error_recovery.send(:retry_with_backoff, suggestion, context)
        expect(result[:success]).to be(false)
        expect(result[:attempts]).to eq(2)
      end
    end

    describe '#create_default_file' do
      let(:test_file_path) { File.join(recovery_dir, 'test_file.rb') }

      it 'creates file with default content' do
        suggestion = {}
        context = { file_path: test_file_path }
        
        result = error_recovery.send(:create_default_file, suggestion, context)
        expect(result[:success]).to be(true)
        expect(File.exist?(test_file_path)).to be(true)
        expect(File.read(test_file_path)).to include('frozen_string_literal')
      end

      it 'creates directory if it does not exist' do
        nested_path = File.join(recovery_dir, 'nested', 'deep', 'test.rb')
        suggestion = {}
        context = { file_path: nested_path }
        
        result = error_recovery.send(:create_default_file, suggestion, context)
        expect(result[:success]).to be(true)
        expect(File.exist?(nested_path)).to be(true)
      end

      it 'returns error when no file path provided' do
        suggestion = {}
        context = {}
        
        result = error_recovery.send(:create_default_file, suggestion, context)
        expect(result[:success]).to be(false)
        expect(result[:error]).to include('No file path provided')
      end
    end

    describe '#find_similar_files' do
      before do
        # Create some test files
        FileUtils.mkdir_p(recovery_dir)
        File.write(File.join(recovery_dir, 'test_file.rb'), 'content')
        File.write(File.join(recovery_dir, 'test_helper.rb'), 'content')
        File.write(File.join(recovery_dir, 'other_file.js'), 'content')
      end

      it 'finds similar files by extension and name pattern' do
        suggestion = {}
        missing_file = File.join(recovery_dir, 'test_new.rb')
        context = { file_path: missing_file }
        
        result = error_recovery.send(:find_similar_files, suggestion, context)
        expect(result[:success]).to be(true)
        expect(result[:similar_files]).to be_an(Array)
        
        # The method searches for files that contain the basename pattern
        # Since we have 'test_file.rb' and 'test_helper.rb' and we're looking for 'test_new.rb'
        # it should find files that contain 'test'
        expect(result[:similar_files].count).to be > 0
      end
    end

    describe '#install_dependencies' do
      it 'detects npm project and suggests npm install' do
        allow(File).to receive(:exist?).with('package.json').and_return(true)
        allow(error_recovery).to receive(:system).with('npm install').and_return(true)
        
        result = error_recovery.send(:install_dependencies, {}, {})
        expect(result[:success]).to be(true)
        expect(result[:package_manager]).to eq('npm')
      end

      it 'detects bundler project and suggests bundle install' do
        allow(File).to receive(:exist?).with('package.json').and_return(false)
        allow(File).to receive(:exist?).with('Gemfile').and_return(true)
        allow(error_recovery).to receive(:system).with('bundle install').and_return(true)
        
        result = error_recovery.send(:install_dependencies, {}, {})
        expect(result[:success]).to be(true)
        expect(result[:package_manager]).to eq('bundler')
      end

      it 'returns error when no dependency file found' do
        allow(File).to receive(:exist?).and_return(false)
        
        result = error_recovery.send(:install_dependencies, {}, {})
        expect(result[:success]).to be(false)
        expect(result[:error]).to include('No recognized dependency file')
      end
    end
  end

  describe 'file persistence' do
    it 'saves and loads error patterns' do
      test_error = StandardError.new('test error')
      error_recovery.learn_from_manual_recovery(test_error, ['step1', 'step2'])
      
      # Create new instance to test loading
      described_class.instance_variable_set(:@instance, nil)
      new_instance = described_class.instance
      
      patterns = new_instance.instance_variable_get(:@error_patterns)
      expect(patterns).not_to be_empty
    end

    it 'handles corrupted pattern files gracefully' do
      # Clean up any existing data first
      FileUtils.rm_rf(recovery_dir) if Dir.exist?(recovery_dir)
      described_class.instance_variable_set(:@instance, nil)
      
      # Create corrupted patterns file
      FileUtils.mkdir_p(recovery_dir)
      File.write(patterns_file, 'invalid json content')
      
      # Should not raise error and use empty patterns
      expect { described_class.instance }.not_to raise_error
      
      patterns = described_class.instance.instance_variable_get(:@error_patterns)
      expect(patterns).to eq({})
    end
  end
end