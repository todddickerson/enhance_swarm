# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::ResourceManager do
  let(:resource_manager) { described_class.new }
  let(:mock_config) { instance_double(EnhanceSwarm::Configuration) }

  before do
    allow(EnhanceSwarm).to receive(:configuration).and_return(mock_config)
    allow(mock_config).to receive(:max_concurrent_agents).and_return(4)
    allow(mock_config).to receive(:max_memory_mb).and_return(2048)
    allow(mock_config).to receive(:max_disk_mb).and_return(1024)
  end

  describe '#initialize' do
    it 'initializes with configuration' do
      expect(resource_manager.instance_variable_get(:@config)).to eq(mock_config)
    end
  end

  describe '#can_spawn_agent?' do
    context 'when all resources are within limits' do
      before do
        allow(resource_manager).to receive(:count_active_agents).and_return(2)
        allow(resource_manager).to receive(:memory_usage_too_high?).and_return(false)
        allow(resource_manager).to receive(:disk_usage_too_high?).and_return(false)
        allow(resource_manager).to receive(:system_load_too_high?).and_return(false)
      end

      it 'allows spawning' do
        result = resource_manager.can_spawn_agent?
        
        expect(result[:allowed]).to be true
        expect(result[:reasons]).to be_empty
      end
    end

    context 'when concurrent agent limit is exceeded' do
      before do
        allow(resource_manager).to receive(:count_active_agents).and_return(5)
        allow(resource_manager).to receive(:memory_usage_too_high?).and_return(false)
        allow(resource_manager).to receive(:disk_usage_too_high?).and_return(false)
        allow(resource_manager).to receive(:system_load_too_high?).and_return(false)
      end

      it 'prevents spawning' do
        result = resource_manager.can_spawn_agent?
        
        expect(result[:allowed]).to be false
        expect(result[:reasons]).to include(/Maximum concurrent agents reached/)
      end
    end

    context 'when memory usage is too high' do
      before do
        allow(resource_manager).to receive(:count_active_agents).and_return(2)
        allow(resource_manager).to receive(:memory_usage_too_high?).and_return(true)
        allow(resource_manager).to receive(:disk_usage_too_high?).and_return(false)
        allow(resource_manager).to receive(:system_load_too_high?).and_return(false)
      end

      it 'prevents spawning' do
        result = resource_manager.can_spawn_agent?
        
        expect(result[:allowed]).to be false
        expect(result[:reasons]).to include('System memory usage too high')
      end
    end

    context 'when disk usage is too high' do
      before do
        allow(resource_manager).to receive(:count_active_agents).and_return(2)
        allow(resource_manager).to receive(:memory_usage_too_high?).and_return(false)
        allow(resource_manager).to receive(:disk_usage_too_high?).and_return(true)
        allow(resource_manager).to receive(:system_load_too_high?).and_return(false)
      end

      it 'prevents spawning' do
        result = resource_manager.can_spawn_agent?
        
        expect(result[:allowed]).to be false
        expect(result[:reasons]).to include('Insufficient disk space')
      end
    end

    context 'when system load is too high' do
      before do
        allow(resource_manager).to receive(:count_active_agents).and_return(2)
        allow(resource_manager).to receive(:memory_usage_too_high?).and_return(false)
        allow(resource_manager).to receive(:disk_usage_too_high?).and_return(false)
        allow(resource_manager).to receive(:system_load_too_high?).and_return(true)
      end

      it 'prevents spawning' do
        result = resource_manager.can_spawn_agent?
        
        expect(result[:allowed]).to be false
        expect(result[:reasons]).to include('System load too high')
      end
    end

    context 'when multiple limits are exceeded' do
      before do
        allow(resource_manager).to receive(:count_active_agents).and_return(5)
        allow(resource_manager).to receive(:memory_usage_too_high?).and_return(true)
        allow(resource_manager).to receive(:disk_usage_too_high?).and_return(false)
        allow(resource_manager).to receive(:system_load_too_high?).and_return(false)
      end

      it 'includes all exceeded limits in reasons' do
        result = resource_manager.can_spawn_agent?
        
        expect(result[:allowed]).to be false
        expect(result[:reasons].size).to eq(2)
        expect(result[:reasons]).to include(/Maximum concurrent agents reached/)
        expect(result[:reasons]).to include('System memory usage too high')
      end
    end
  end

  describe '#get_resource_stats' do
    before do
      allow(resource_manager).to receive(:count_active_agents).and_return(3)
      allow(resource_manager).to receive(:get_memory_usage_mb).and_return(1024)
      allow(resource_manager).to receive(:get_disk_usage_mb).and_return(512)
      allow(resource_manager).to receive(:get_system_load).and_return(2.5)
    end

    it 'returns comprehensive resource statistics' do
      stats = resource_manager.get_resource_stats
      
      expect(stats[:active_agents]).to eq(3)
      expect(stats[:max_agents]).to eq(4)
      expect(stats[:memory_usage_mb]).to eq(1024)
      expect(stats[:disk_usage_mb]).to eq(512)
      expect(stats[:system_load]).to eq(2.5)
    end
  end

  describe '#enforce_limits!' do
    context 'when agent limit is exceeded' do
      before do
        allow(resource_manager).to receive(:get_resource_stats).and_return({
          active_agents: 6,
          max_agents: 4,
          memory_usage_mb: 1024,
          disk_usage_mb: 512,
          system_load: 2.0
        })
        allow(resource_manager).to receive(:cleanup_oldest_agents)
      end

      it 'cleans up excess agents' do
        expect(resource_manager).to receive(:cleanup_oldest_agents).with(2)
        resource_manager.enforce_limits!
      end
    end

    context 'when within limits' do
      before do
        allow(resource_manager).to receive(:get_resource_stats).and_return({
          active_agents: 3,
          max_agents: 4,
          memory_usage_mb: 1024,
          disk_usage_mb: 512,
          system_load: 2.0
        })
      end

      it 'does not clean up agents' do
        expect(resource_manager).not_to receive(:cleanup_oldest_agents)
        resource_manager.enforce_limits!
      end
    end
  end

  describe 'private methods' do
    describe '#count_active_agents' do
      it 'counts running enhance-swarm processes' do
        allow(resource_manager).to receive(:`).with(/ps aux/).and_return("user 1234 enhance-swarm\nuser 5678 enhance-swarm\n")
        
        count = resource_manager.send(:count_active_agents)
        expect(count).to eq(1) # Subtracts 1 for current process
      end

      it 'handles errors gracefully' do
        allow(resource_manager).to receive(:`).and_raise(StandardError)
        
        count = resource_manager.send(:count_active_agents)
        expect(count).to eq(0)
      end
    end

    describe '#memory_usage_too_high?' do
      it 'compares current usage to configured limit' do
        allow(resource_manager).to receive(:get_memory_usage_mb).and_return(3000)
        
        result = resource_manager.send(:memory_usage_too_high?)
        expect(result).to be true
      end

      it 'returns false when within limits' do
        allow(resource_manager).to receive(:get_memory_usage_mb).and_return(1000)
        
        result = resource_manager.send(:memory_usage_too_high?)
        expect(result).to be false
      end
    end

    describe '#disk_usage_too_high?' do
      it 'compares current usage to configured limit' do
        allow(resource_manager).to receive(:get_disk_usage_mb).and_return(2000)
        
        result = resource_manager.send(:disk_usage_too_high?)
        expect(result).to be true
      end

      it 'returns false when within limits' do
        allow(resource_manager).to receive(:get_disk_usage_mb).and_return(500)
        
        result = resource_manager.send(:disk_usage_too_high?)
        expect(result).to be false
      end
    end

    describe '#system_load_too_high?' do
      before do
        allow(resource_manager).to receive(:get_cpu_count).and_return(4)
      end

      it 'compares load average to CPU count threshold' do
        allow(resource_manager).to receive(:get_system_load).and_return(7.0)
        
        result = resource_manager.send(:system_load_too_high?)
        expect(result).to be true # 7.0 > 4 * 1.5
      end

      it 'returns false when within threshold' do
        allow(resource_manager).to receive(:get_system_load).and_return(3.0)
        
        result = resource_manager.send(:system_load_too_high?)
        expect(result).to be false # 3.0 < 4 * 1.5
      end
    end

    describe '#get_memory_usage_mb' do
      it 'calculates memory usage from ps output' do
        allow(resource_manager).to receive(:`).with(/ps aux/).and_return("1048576\n") # 1GB in KB
        
        usage = resource_manager.send(:get_memory_usage_mb)
        expect(usage).to eq(1024) # 1024MB
      end

      it 'handles errors gracefully' do
        allow(resource_manager).to receive(:`).and_raise(StandardError)
        
        usage = resource_manager.send(:get_memory_usage_mb)
        expect(usage).to eq(0)
      end
    end

    describe '#get_disk_usage_mb' do
      context 'when .enhance_swarm directory exists' do
        before do
          allow(Dir).to receive(:exist?).with('.enhance_swarm').and_return(true)
          allow(resource_manager).to receive(:`).with(/du -sm/).and_return("512\n")
        end

        it 'returns disk usage in MB' do
          usage = resource_manager.send(:get_disk_usage_mb)
          expect(usage).to eq(512)
        end
      end

      context 'when .enhance_swarm directory does not exist' do
        before do
          allow(Dir).to receive(:exist?).with('.enhance_swarm').and_return(false)
        end

        it 'returns 0' do
          usage = resource_manager.send(:get_disk_usage_mb)
          expect(usage).to eq(0)
        end
      end
    end

    describe '#get_system_load' do
      it 'extracts load average from uptime command' do
        allow(resource_manager).to receive(:`).with('uptime').and_return('load averages: 2.50 2.00 1.80')
        
        load = resource_manager.send(:get_system_load)
        expect(load).to eq(2.5)
      end

      it 'handles errors gracefully' do
        allow(resource_manager).to receive(:`).and_raise(StandardError)
        
        load = resource_manager.send(:get_system_load)
        expect(load).to eq(0.0)
      end
    end

    describe '#cleanup_oldest_agents' do
      it 'terminates specified number of oldest processes' do
        ps_output = "user 1234 enhance-swarm\nuser 5678 enhance-swarm\n"
        allow(resource_manager).to receive(:`).with(/ps aux/).and_return(ps_output)
        allow(Process).to receive(:kill)
        
        expect(Process).to receive(:kill).with('TERM', 1234)
        resource_manager.send(:cleanup_oldest_agents, 1)
      end

      it 'handles process termination errors' do
        ps_output = "user 1234 enhance-swarm\n"
        allow(resource_manager).to receive(:`).with(/ps aux/).and_return(ps_output)
        allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
        
        expect { resource_manager.send(:cleanup_oldest_agents, 1) }.not_to raise_error
      end
    end
  end
end