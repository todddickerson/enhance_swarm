# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::VisualDashboard do
  let(:dashboard) { described_class.instance }
  let(:test_agents) do
    [
      {
        id: 'backend-123',
        role: 'backend',
        status: 'active',
        start_time: Time.now.iso8601,
        current_task: 'Building API',
        progress_percentage: 65,
        pid: 12345,
        memory_mb: 128
      },
      {
        id: 'frontend-456', 
        role: 'frontend',
        status: 'completed',
        start_time: (Time.now - 300).iso8601,
        current_task: 'UI Components',
        progress_percentage: 100,
        pid: 23456,
        memory_mb: 95
      }
    ]
  end

  before do
    # Reset dashboard state
    dashboard.instance_variable_set(:@agents, {})
    dashboard.instance_variable_set(:@coordination_status, {})
    dashboard.instance_variable_set(:@dashboard_active, false)
  end

  describe '#initialize' do
    it 'initializes with default values' do
      expect(dashboard.instance_variable_get(:@agents)).to eq({})
      expect(dashboard.instance_variable_get(:@coordination_status)).to eq({})
      expect(dashboard.instance_variable_get(:@dashboard_active)).to be(false)
      expect(dashboard.instance_variable_get(:@refresh_rate)).to eq(2)
    end
  end

  describe '#add_agent' do
    it 'adds agent to dashboard' do
      agent = test_agents.first
      dashboard.add_agent(agent)
      
      agents = dashboard.instance_variable_get(:@agents)
      expect(agents[agent[:id]]).to eq(agent)
    end
  end

  describe '#update_agent' do
    it 'updates existing agent' do
      agent = test_agents.first
      dashboard.add_agent(agent)
      
      updates = { status: 'completed', progress_percentage: 100 }
      dashboard.update_agent(agent[:id], updates)
      
      agents = dashboard.instance_variable_get(:@agents)
      expect(agents[agent[:id]][:status]).to eq('completed')
      expect(agents[agent[:id]][:progress_percentage]).to eq(100)
    end

    it 'does nothing for non-existent agent' do
      expect { dashboard.update_agent('non-existent', { status: 'failed' }) }.not_to raise_error
    end
  end

  describe '#remove_agent' do
    it 'removes agent from dashboard' do
      agent = test_agents.first
      dashboard.add_agent(agent)
      
      dashboard.remove_agent(agent[:id])
      
      agents = dashboard.instance_variable_get(:@agents)
      expect(agents[agent[:id]]).to be_nil
    end
  end

  describe '#update_coordination' do
    it 'updates coordination status' do
      status = {
        phase: 'Backend Implementation',
        progress: 75,
        active_agents: ['backend-123'],
        completed_agents: ['frontend-456']
      }
      
      dashboard.update_coordination(status)
      
      coordination = dashboard.instance_variable_get(:@coordination_status)
      expect(coordination).to eq(status)
    end
  end

  describe 'singleton pattern' do
    it 'provides singleton access' do
      expect(described_class.instance).to be_a(described_class)
      expect(described_class.instance).to eq(described_class.instance)
    end

    it 'delegates class methods to instance' do
      agent = test_agents.first
      expect(dashboard).to receive(:add_agent).with(agent)
      
      described_class.add_agent(agent)
    end
  end

  describe 'private helper methods' do
    describe '#format_agent_status' do
      it 'formats active status' do
        result = dashboard.send(:format_agent_status, { status: 'active' })
        expect(result).to include('Active')
      end

      it 'formats completed status' do
        result = dashboard.send(:format_agent_status, { status: 'completed' })
        expect(result).to include('Done')
      end

      it 'formats failed status' do
        result = dashboard.send(:format_agent_status, { status: 'failed' })
        expect(result).to include('Failed')
      end

      it 'formats stuck status' do
        result = dashboard.send(:format_agent_status, { status: 'stuck' })
        expect(result).to include('Stuck')
      end

      it 'formats unknown status' do
        result = dashboard.send(:format_agent_status, { status: 'unknown' })
        expect(result).to include('Unknown')
      end
    end

    describe '#render_progress_bar' do
      it 'renders progress bar with correct width' do
        result = dashboard.send(:render_progress_bar, 50, 10)
        expect(result.length).to be >= 10 # May include color codes
      end

      it 'handles zero percentage' do
        result = dashboard.send(:render_progress_bar, 0, 10)
        expect(result).not_to be_empty
      end

      it 'handles full percentage' do
        result = dashboard.send(:render_progress_bar, 100, 10)
        expect(result).not_to be_empty
      end
    end

    describe '#render_mini_progress_bar' do
      it 'renders mini progress bar' do
        result = dashboard.send(:render_mini_progress_bar, 50, 10)
        expect(result.length).to eq(10)
        expect(result).to include('█')
        expect(result).to include('░')
      end
    end

    describe '#time_ago' do
      it 'formats seconds' do
        time = Time.now - 30
        result = dashboard.send(:time_ago, time)
        expect(result).to match(/\d+s/)
      end

      it 'formats minutes' do
        time = Time.now - 120
        result = dashboard.send(:time_ago, time)
        expect(result).to match(/\d+m/)
      end

      it 'formats hours' do
        time = Time.now - 7200
        result = dashboard.send(:time_ago, time)
        expect(result).to match(/\d+h/)
      end
    end

    describe '#format_time_duration' do
      it 'formats seconds' do
        result = dashboard.send(:format_time_duration, 45)
        expect(result).to eq('45s')
      end

      it 'formats minutes' do
        result = dashboard.send(:format_time_duration, 120)
        expect(result).to eq('2m')
      end

      it 'formats hours and minutes' do
        result = dashboard.send(:format_time_duration, 3720) # 1h 2m
        expect(result).to match(/1h\d+m/)
      end
    end

    describe '#get_terminal_size' do
      it 'returns terminal size hash with fallback values' do
        # Mock the stty command to fail (which is what happens in test environment)
        allow(dashboard).to receive(:`).with('stty size').and_return("")
        
        result = dashboard.send(:get_terminal_size)
        expect(result).to have_key(:width)
        expect(result).to have_key(:height)
        expect(result[:width]).to eq(80)
        expect(result[:height]).to eq(24)
      end

      it 'returns actual terminal size when available' do
        # Mock the stty command to return size
        allow(dashboard).to receive(:`).with('stty size').and_return("50 120")
        
        result = dashboard.send(:get_terminal_size)
        expect(result[:width]).to eq(120)
        expect(result[:height]).to eq(50)
      end
    end

    describe '#get_memory_info' do
      it 'returns memory information' do
        result = dashboard.send(:get_memory_info)
        expect(result).to have_key(:total_gb)
        expect(result).to have_key(:used_gb)
        expect(result).to have_key(:used_percent)
        expect(result[:total_gb]).to be > 0
        expect(result[:used_percent]).to be_between(0, 100)
      end
    end

    describe '#get_system_snapshot' do
      it 'returns system snapshot data' do
        result = dashboard.send(:get_system_snapshot)
        expect(result).to have_key(:memory)
        expect(result).to have_key(:terminal_size)
        expect(result).to have_key(:ruby_version)
        expect(result).to have_key(:platform)
        expect(result).to have_key(:timestamp)
      end
    end
  end

  describe 'rendering methods (non-interactive)' do
    before do
      # Add test agents
      test_agents.each { |agent| dashboard.add_agent(agent) }
      
      # Mock terminal methods to avoid actual terminal output
      allow(dashboard).to receive(:print)
      allow(dashboard).to receive(:puts)
      allow(dashboard).to receive(:clear_screen)
    end

    describe '#render_agent_status' do
      it 'renders without error' do
        expect { dashboard.send(:render_agent_grid) }.not_to raise_error
      end
    end

    describe '#render_coordination_overview' do
      it 'renders coordination status' do
        dashboard.update_coordination({
          phase: 'Testing',
          progress: 80,
          active_agents: ['backend-123']
        })
        
        expect { dashboard.send(:render_coordination_overview) }.not_to raise_error
      end

      it 'renders empty coordination status' do
        expect { dashboard.send(:render_coordination_overview) }.not_to raise_error
      end
    end

    describe '#render_status_bar' do
      it 'renders system status' do
        expect { dashboard.send(:render_status_bar) }.not_to raise_error
      end
    end

    describe '#render_controls' do
      it 'renders control help' do
        expect { dashboard.send(:render_controls) }.not_to raise_error
      end
    end
  end

  describe 'file operations' do
    let(:snapshot_dir) { '.enhance_swarm' }
    
    after do
      # Clean up any created snapshot files
      FileUtils.rm_rf(snapshot_dir) if Dir.exist?(snapshot_dir)
    end

    describe '#save_dashboard_snapshot' do
      it 'creates snapshot file' do
        test_agents.each { |agent| dashboard.add_agent(agent) }
        
        # Mock the flash_message method to avoid terminal operations
        allow(dashboard).to receive(:flash_message)
        
        dashboard.send(:save_dashboard_snapshot)
        
        snapshot_files = Dir.glob(File.join(snapshot_dir, 'dashboard_snapshot_*.json'))
        expect(snapshot_files).not_to be_empty
        
        # Verify snapshot content
        snapshot_data = JSON.parse(File.read(snapshot_files.first))
        expect(snapshot_data).to have_key('timestamp')
        expect(snapshot_data).to have_key('agents')
        expect(snapshot_data).to have_key('system_info')
      end
    end
  end

  describe 'integration with other components' do
    it 'works with notification manager when available' do
      # This test verifies the dashboard doesn't break when NotificationManager is present
      expect { dashboard.add_agent(test_agents.first) }.not_to raise_error
    end

    it 'works with agent communicator when available' do
      # This test verifies the dashboard can access pending messages
      expect { dashboard.send(:render_status_bar) }.not_to raise_error
    end
  end
end