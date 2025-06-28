# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::SmartDefaults do
  let(:smart_defaults) { described_class.instance }
  let(:settings_dir) { '.enhance_swarm' }
  let(:settings_file) { '.enhance_swarm/smart_defaults.yml' }
  let(:patterns_file) { '.enhance_swarm/user_patterns.json' }

  before do
    # Clean up any existing settings
    FileUtils.rm_rf(settings_dir) if Dir.exist?(settings_dir)
    
    # Reset singleton instance
    described_class.instance_variable_set(:@instance, nil)
  end

  after do
    # Clean up test files
    FileUtils.rm_rf(settings_dir) if Dir.exist?(settings_dir)
  end

  describe '#initialize' do
    it 'initializes with default settings' do
      expect(smart_defaults.instance_variable_get(:@settings)).to be_a(Hash)
      expect(smart_defaults.instance_variable_get(:@user_patterns)).to be_a(Hash)
      expect(smart_defaults.instance_variable_get(:@project_context)).to be_a(Hash)
    end

    it 'creates settings directory' do
      smart_defaults
      expect(Dir.exist?(settings_dir)).to be(true)
    end
  end

  describe '#suggest_role_for_task' do
    it 'suggests backend role for API tasks' do
      result = smart_defaults.suggest_role_for_task('Build REST API endpoints')
      expect(result).to eq('backend')
    end

    it 'suggests frontend role for UI tasks' do
      result = smart_defaults.suggest_role_for_task('Create user interface components')
      expect(result).to eq('frontend')
    end

    it 'suggests qa role for testing tasks' do
      result = smart_defaults.suggest_role_for_task('Write unit tests and run integration testing')
      expect(result).to eq('qa')
    end

    it 'suggests ux role for design tasks' do
      result = smart_defaults.suggest_role_for_task('Design user experience wireframes')
      expect(result).to eq('ux')
    end

    it 'returns general role for ambiguous tasks' do
      result = smart_defaults.suggest_role_for_task('Update documentation')
      expect(result).to eq('general')
    end

    it 'considers user patterns in role suggestion' do
      # Set up user patterns favoring backend
      patterns = {
        'role_preferences' => { 'backend' => 2.0, 'frontend' => 0.5 }
      }
      smart_defaults.instance_variable_set(:@user_patterns, patterns)
      
      result = smart_defaults.suggest_role_for_task('General development task')
      expect(result).to eq('backend')
    end
  end

  describe '#suggest_configuration' do
    it 'returns configuration hash with all sections' do
      config = smart_defaults.suggest_configuration
      
      expect(config).to have_key(:project_type)
      expect(config).to have_key(:technology_stack)
      expect(config).to have_key(:commands)
      expect(config).to have_key(:orchestration)
      expect(config).to have_key(:mcp_tools)
    end

    it 'detects Rails project type' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('Gemfile').and_return(true)
      allow(File).to receive(:exist?).with('config/application.rb').and_return(true)
      
      config = smart_defaults.suggest_configuration
      expect(config[:project_type]).to eq('rails')
      expect(config[:technology_stack]).to include('Ruby on Rails')
    end

    it 'detects Node.js project type' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('package.json').and_return(true)
      allow(File).to receive(:exist?).with('Gemfile').and_return(false)
      allow(File).to receive(:exist?).with('config/application.rb').and_return(false)
      
      # Mock package.json content for Node stack detection
      package_json_content = {
        'dependencies' => { 'react' => '^17.0.0', 'express' => '^4.17.0' },
        'devDependencies' => { 'typescript' => '^4.0.0' }
      }
      allow(File).to receive(:read).with('package.json').and_return(JSON.generate(package_json_content))
      
      config = smart_defaults.suggest_configuration
      expect(config[:project_type]).to eq('node')
      expect(config[:technology_stack]).to include('Node.js')
    end
  end

  describe '#auto_retry_with_backoff' do
    it 'succeeds on first attempt' do
      result = smart_defaults.auto_retry_with_backoff('test_operation') do
        'success'
      end
      
      expect(result).to eq('success')
    end

    it 'retries on failure and eventually succeeds' do
      attempt_count = 0
      
      result = smart_defaults.auto_retry_with_backoff('test_operation', max_retries: 3) do
        attempt_count += 1
        raise StandardError, 'failure' if attempt_count < 3
        'success'
      end
      
      expect(result).to eq('success')
      expect(attempt_count).to eq(3)
    end

    it 'raises error after max retries' do
      expect do
        smart_defaults.auto_retry_with_backoff('test_operation', max_retries: 2) do
          raise StandardError, 'persistent failure'
        end
      end.to raise_error(StandardError, 'persistent failure')
    end

    it 'records retry patterns' do
      allow(smart_defaults).to receive(:record_success_pattern)
      
      smart_defaults.auto_retry_with_backoff('test_operation') { 'success' }
      
      expect(smart_defaults).to have_received(:record_success_pattern).with('test_operation', 1)
    end
  end

  describe '#suggest_next_actions' do
    it 'returns array of suggestions' do
      suggestions = smart_defaults.suggest_next_actions
      expect(suggestions).to be_an(Array)
    end

    it 'suggests cleanup for stale worktrees' do
      allow(smart_defaults).to receive(:stale_worktrees_detected?).and_return(true)
      
      suggestions = smart_defaults.suggest_next_actions
      cleanup_suggestion = suggestions.find { |s| s[:action] == 'cleanup' }
      
      expect(cleanup_suggestion).not_to be_nil
      expect(cleanup_suggestion[:command]).to include('cleanup')
      expect(cleanup_suggestion[:priority]).to eq(:medium)
    end

    it 'suggests communication for pending messages' do
      allow(smart_defaults).to receive(:pending_agent_messages?).and_return(true)
      
      suggestions = smart_defaults.suggest_next_actions
      comm_suggestion = suggestions.find { |s| s[:action] == 'communicate' }
      
      expect(comm_suggestion).not_to be_nil
      expect(comm_suggestion[:command]).to include('communicate')
      expect(comm_suggestion[:priority]).to eq(:high)
    end

    it 'suggests running tests when needed' do
      allow(smart_defaults).to receive(:tests_need_running?).and_return(true)
      allow(smart_defaults).to receive(:determine_test_command).and_return('npm test')
      
      suggestions = smart_defaults.suggest_next_actions
      test_suggestion = suggestions.find { |s| s[:action] == 'test' }
      
      expect(test_suggestion).not_to be_nil
      expect(test_suggestion[:command]).to eq('npm test')
    end

    it 'sorts suggestions by priority' do
      allow(smart_defaults).to receive(:stale_worktrees_detected?).and_return(true)
      allow(smart_defaults).to receive(:pending_agent_messages?).and_return(true)
      
      suggestions = smart_defaults.suggest_next_actions
      expect(suggestions.first[:priority]).to eq(:high)
    end
  end

  describe '#auto_cleanup_if_needed' do
    it 'returns count of cleanup actions performed' do
      count = smart_defaults.auto_cleanup_if_needed
      expect(count).to be_a(Integer)
      expect(count).to be >= 0
    end

    it 'cleans up stale worktrees when threshold exceeded' do
      # Mock the cleanup manager since it might not have this method
      cleanup_manager = double('CleanupManager')
      allow(cleanup_manager).to receive(:cleanup_stale_worktrees)
      stub_const('EnhanceSwarm::CleanupManager', cleanup_manager)
      
      allow(smart_defaults).to receive(:find_stale_worktrees).and_return(['path1', 'path2', 'path3', 'path4'])
      
      count = smart_defaults.auto_cleanup_if_needed
      expect(count).to be > 0
    end

    it 'cleans up old communication files when threshold exceeded' do
      communicator = double('AgentCommunicator')
      allow(communicator).to receive(:cleanup_old_messages)
      allow(EnhanceSwarm::AgentCommunicator).to receive(:instance).and_return(communicator)
      
      allow(smart_defaults).to receive(:find_old_communication_files).and_return(Array.new(25) { "file#{rand}" })
      
      count = smart_defaults.auto_cleanup_if_needed
      expect(count).to be > 0
    end

    it 'cleans up notification history when size exceeded' do
      notification_manager = double('NotificationManager')
      allow(notification_manager).to receive(:clear_history)
      allow(EnhanceSwarm::NotificationManager).to receive(:instance).and_return(notification_manager)
      
      allow(smart_defaults).to receive(:notification_history_size).and_return(150)
      
      count = smart_defaults.auto_cleanup_if_needed
      expect(count).to be > 0
    end
  end

  describe '#learn_from_action' do
    it 'updates user patterns with action data' do
      smart_defaults.learn_from_action('spawn', { role: 'backend', worktree: true })
      
      patterns = smart_defaults.instance_variable_get(:@user_patterns)
      expect(patterns['actions']['spawn']['count']).to eq(1)
      expect(patterns['actions']['spawn']['preferences']['role']['backend']).to eq(1)
    end

    it 'increments count for repeated actions' do
      smart_defaults.learn_from_action('enhance', { control_agent: true })
      smart_defaults.learn_from_action('enhance', { control_agent: false })
      
      patterns = smart_defaults.instance_variable_get(:@user_patterns)
      expect(patterns['actions']['enhance']['count']).to eq(2)
    end

    it 'saves patterns to file' do
      expect(smart_defaults).to receive(:save_user_patterns)
      smart_defaults.learn_from_action('test_action', {})
    end
  end

  describe '#suggest_commands_for_context' do
    it 'suggests npm commands for Node.js projects' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('package.json').and_return(true)
      
      context = { changed_files: ['app.js', 'test.js'] }
      commands = smart_defaults.suggest_commands_for_context(context)
      
      expect(commands).to include('npm test')
    end

    it 'suggests bundle commands for Ruby projects' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('Gemfile').and_return(true)
      
      context = { changed_files: ['app.rb', 'spec.rb'] }
      commands = smart_defaults.suggest_commands_for_context(context)
      
      expect(commands).to include('bundle exec rspec')
    end

    it 'suggests git commands based on status' do
      context = {
        git_status: {
          modified_files: 2,
          untracked_files: 1
        }
      }
      
      commands = smart_defaults.suggest_commands_for_context(context)
      expect(commands).to include('git add .')
      expect(commands).to include('enhance-swarm review')
    end
  end

  describe '#suggest_concurrency_settings' do
    it 'returns concurrency configuration' do
      settings = smart_defaults.suggest_concurrency_settings
      
      expect(settings).to have_key(:max_concurrent_agents)
      expect(settings).to have_key(:monitor_interval)
      expect(settings).to have_key(:timeout_multiplier)
      expect(settings[:max_concurrent_agents]).to be > 0
    end

    it 'adjusts settings based on system resources' do
      allow(smart_defaults).to receive(:detect_cpu_cores).and_return(8)
      allow(smart_defaults).to receive(:detect_available_memory).and_return(16.0)
      
      settings = smart_defaults.suggest_concurrency_settings
      expect(settings[:max_concurrent_agents]).to be <= 8
    end

    it 'enforces minimum agent count' do
      allow(smart_defaults).to receive(:detect_cpu_cores).and_return(1)
      allow(smart_defaults).to receive(:detect_available_memory).and_return(2.0)
      
      settings = smart_defaults.suggest_concurrency_settings
      expect(settings[:max_concurrent_agents]).to be >= 2
    end
  end

  describe 'singleton pattern' do
    it 'provides singleton access' do
      expect(described_class.instance).to be_a(described_class)
      expect(described_class.instance).to eq(described_class.instance)
    end

    it 'delegates class methods to instance' do
      expect(described_class.suggest_role_for_task('test task')).to be_a(String)
      expect(described_class.suggest_configuration).to be_a(Hash)
      expect(described_class.auto_cleanup_if_needed).to be_a(Integer)
    end
  end

  describe 'private helper methods' do
    describe '#detect_project_type' do
      it 'detects Rails project' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('Gemfile').and_return(true)
        allow(File).to receive(:exist?).with('config/application.rb').and_return(true)
        
        result = smart_defaults.send(:detect_project_type)
        expect(result).to eq('rails')
      end

      it 'detects Node.js project' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('package.json').and_return(true)
        allow(File).to receive(:exist?).with('Gemfile').and_return(false)
        allow(File).to receive(:exist?).with('config/application.rb').and_return(false)
        
        result = smart_defaults.send(:detect_project_type)
        expect(result).to eq('node')
      end

      it 'defaults to general for unknown projects' do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('Gemfile').and_return(false)
        allow(File).to receive(:exist?).with('config/application.rb').and_return(false)
        allow(File).to receive(:exist?).with('package.json').and_return(false)
        allow(File).to receive(:exist?).with('requirements.txt').and_return(false)
        allow(File).to receive(:exist?).with('pyproject.toml').and_return(false)
        allow(File).to receive(:exist?).with('Dockerfile').and_return(false)
        allow(Dir).to receive(:glob).and_return([])
        
        result = smart_defaults.send(:detect_project_type)
        expect(result).to eq('general')
      end
    end

    describe '#stale_worktrees_detected?' do
      it 'returns false when no stale worktrees' do
        allow(smart_defaults).to receive(:find_stale_worktrees).and_return([])
        
        result = smart_defaults.send(:stale_worktrees_detected?)
        expect(result).to be(false)
      end

      it 'returns true when stale worktrees exceed threshold' do
        allow(smart_defaults).to receive(:find_stale_worktrees).and_return(['path1', 'path2', 'path3'])
        
        result = smart_defaults.send(:stale_worktrees_detected?)
        expect(result).to be(true)
      end
    end

    describe '#tests_need_running?' do
      before do
        # Mock project context with git info
        smart_defaults.instance_variable_set(:@project_context, { git: { branch: 'main' } })
      end

      it 'returns true when source files have changed' do
        allow(smart_defaults).to receive(:`).with('git status --porcelain').and_return(" M app.rb\n?? test.js\n")
        
        result = smart_defaults.send(:tests_need_running?)
        expect(result).to be(true)
      end

      it 'returns false when no source files changed' do
        allow(smart_defaults).to receive(:`).with('git status --porcelain').and_return(" M README.md\n?? doc.txt\n")
        
        result = smart_defaults.send(:tests_need_running?)
        expect(result).to be(false)
      end
    end

    describe '#determine_test_command' do
      it 'returns rspec for Rails projects' do
        allow(smart_defaults).to receive(:detect_project_type).and_return('rails')
        
        result = smart_defaults.send(:determine_test_command)
        expect(result).to eq('bundle exec rspec')
      end

      it 'returns npm test for Node projects' do
        allow(smart_defaults).to receive(:detect_project_type).and_return('node')
        
        result = smart_defaults.send(:determine_test_command)
        expect(result).to eq('npm test')
      end

      it 'returns pytest for Python projects' do
        allow(smart_defaults).to receive(:detect_project_type).and_return('python')
        
        result = smart_defaults.send(:determine_test_command)
        expect(result).to eq('pytest')
      end
    end

    describe '#detect_cpu_cores' do
      it 'returns positive integer' do
        result = smart_defaults.send(:detect_cpu_cores)
        expect(result).to be_a(Integer)
        expect(result).to be > 0
      end
    end

    describe '#detect_available_memory' do
      it 'returns positive float' do
        result = smart_defaults.send(:detect_available_memory)
        expect(result).to be_a(Float)
        expect(result).to be > 0
      end
    end
  end

  describe 'file persistence' do
    it 'saves and loads user patterns' do
      smart_defaults.learn_from_action('test_action', { option: 'value' })
      
      # Create new instance to test loading
      described_class.instance_variable_set(:@instance, nil)
      new_instance = described_class.instance
      
      patterns = new_instance.instance_variable_get(:@user_patterns)
      expect(patterns['actions']['test_action']['count']).to eq(1)
    end

    it 'handles corrupted pattern files gracefully' do
      # Create corrupted patterns file
      FileUtils.mkdir_p(settings_dir)
      File.write(patterns_file, 'invalid json content')
      
      # Should not raise error and use empty patterns
      expect { described_class.instance }.not_to raise_error
      
      patterns = described_class.instance.instance_variable_get(:@user_patterns)
      expect(patterns).to eq({})
    end
  end
end