# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EnhanceSwarm::NotificationManager do
  let(:notification_manager) { described_class.new }

  describe '#initialize' do
    it 'initializes with default settings' do
      expect(notification_manager.enabled?).to be(true)
      expect(notification_manager.recent_notifications).to be_empty
    end
  end

  describe '#notify' do
    it 'creates and logs notification' do
      expect(EnhanceSwarm::Logger).to receive(:log_operation)
        .with('notification_agent_completed', 'sent', anything)
      
      notification = notification_manager.notify(:agent_completed, 'Test message', { test: true })
      
      expect(notification[:type]).to eq(:agent_completed)
      expect(notification[:message]).to eq('Test message')
      expect(notification[:details][:test]).to be(true)
      expect(notification[:priority]).to eq(:high)
    end

    it 'does not notify when disabled' do
      notification_manager.disable!
      
      expect(EnhanceSwarm::Logger).not_to receive(:log_operation)
      
      result = notification_manager.notify(:agent_completed, 'Test message')
      expect(result).to be_nil
    end

    it 'adds notification to history' do
      notification_manager.notify(:agent_completed, 'Test message')
      
      history = notification_manager.recent_notifications
      expect(history.size).to eq(1)
      expect(history.first[:message]).to eq('Test message')
    end
  end

  describe '#agent_completed' do
    it 'sends completion notification with details' do
      expect(notification_manager).to receive(:notify)
        .with(:agent_completed, "🎉 Agent 'backend' completed successfully!", {
          agent_id: 'backend-123',
          role: 'backend',
          duration: 120
        })
      
      notification_manager.agent_completed('backend-123', 'backend', 120)
    end
  end

  describe '#agent_failed' do
    it 'sends failure notification with suggestions' do
      suggestions = ['Restart agent', 'Check logs']
      
      expect(notification_manager).to receive(:notify)
        .with(:agent_failed, "❌ Agent 'frontend' failed: Connection timeout", {
          agent_id: 'frontend-456',
          role: 'frontend',
          error: 'Connection timeout',
          suggestions: suggestions
        })
      
      notification_manager.agent_failed('frontend-456', 'frontend', 'Connection timeout', suggestions)
    end
  end

  describe '#agent_stuck' do
    let(:last_activity) { Time.now - 600 } # 10 minutes ago
    
    it 'sends stuck notification with time information' do
      expect(notification_manager).to receive(:notify)
        .with(:agent_stuck, "⚠️ Agent 'qa' stuck for 10m", {
          agent_id: 'qa-789',
          role: 'qa',
          last_activity: last_activity,
          time_stuck: anything,
          current_task: 'Running tests'
        })
      
      notification_manager.agent_stuck('qa-789', 'qa', last_activity, 'Running tests')
    end
  end

  describe '#coordination_complete' do
    it 'sends coordination summary' do
      summary = { completed: 3, failed: 1 }
      
      expect(notification_manager).to receive(:notify)
        .with(:coordination_complete, "✅ Coordination complete: 3/4 agents succeeded", summary)
      
      notification_manager.coordination_complete(summary)
    end
  end

  describe '#intervention_needed' do
    it 'sends intervention notification with suggestions' do
      suggestions = ['Action 1', 'Action 2']
      
      expect(notification_manager).to receive(:notify)
        .with(:intervention_needed, "🚨 Intervention needed: Critical error", {
          reason: 'Critical error',
          agent_id: 'agent-123',
          suggestions: suggestions
        })
      
      notification_manager.intervention_needed('Critical error', 'agent-123', suggestions)
    end
  end

  describe '#progress_milestone' do
    it 'sends milestone notification' do
      eta = Time.now + 3600
      
      expect(notification_manager).to receive(:notify)
        .with(:progress_milestone, "📍 Backend complete (75% complete)", {
          milestone: 'Backend complete',
          progress: 75,
          eta: eta
        })
      
      notification_manager.progress_milestone('Backend complete', 75, eta)
    end
  end

  describe '#start_monitoring' do
    let(:agents) { [{ id: 'agent-1', pid: 12345, role: 'backend' }] }
    
    it 'starts background monitoring thread' do
      expect(notification_manager.instance_variable_get(:@monitoring_thread)).to be_nil
      
      notification_manager.start_monitoring(agents)
      
      thread = notification_manager.instance_variable_get(:@monitoring_thread)
      expect(thread).to be_a(Thread)
      expect(thread).to be_alive
      
      # Cleanup
      notification_manager.stop_monitoring
    end
  end

  describe '#stop_monitoring' do
    let(:agents) { [{ id: 'agent-1', pid: 12345, role: 'backend' }] }
    
    it 'stops monitoring thread' do
      notification_manager.start_monitoring(agents)
      thread = notification_manager.instance_variable_get(:@monitoring_thread)
      
      notification_manager.stop_monitoring
      
      sleep(0.1) # Give thread time to terminate
      expect(thread).not_to be_alive
    end
  end

  describe '#enable! and #disable!' do
    it 'enables notifications' do
      notification_manager.disable!
      expect(notification_manager.enabled?).to be(false)
      
      notification_manager.enable!
      expect(notification_manager.enabled?).to be(true)
    end

    it 'disables notifications' do
      expect(notification_manager.enabled?).to be(true)
      
      notification_manager.disable!
      expect(notification_manager.enabled?).to be(false)
    end
  end

  describe '#recent_notifications' do
    it 'returns limited number of recent notifications' do
      5.times { |i| notification_manager.notify(:progress_milestone, "Message #{i}") }
      
      recent = notification_manager.recent_notifications(3)
      expect(recent.size).to eq(3)
      expect(recent.last[:message]).to eq('Message 4')
    end
  end

  describe '#clear_history' do
    it 'clears notification history' do
      notification_manager.notify(:agent_completed, 'Test message')
      expect(notification_manager.recent_notifications).not_to be_empty
      
      notification_manager.clear_history
      expect(notification_manager.recent_notifications).to be_empty
    end
  end

  describe 'class methods' do
    it 'provides singleton access' do
      expect(described_class.instance).to be_a(described_class)
      expect(described_class.instance).to eq(described_class.instance)
    end

    it 'delegates to instance methods' do
      expect(described_class.instance).to receive(:notify).with(:test, 'message')
      described_class.notify(:test, 'message')
    end
  end

  describe 'private methods' do
    describe '#build_notification' do
      it 'builds notification with correct structure' do
        notification = notification_manager.send(:build_notification, :agent_completed, 'Test', { key: 'value' })
        
        expect(notification[:type]).to eq(:agent_completed)
        expect(notification[:message]).to eq('Test')
        expect(notification[:details][:key]).to eq('value')
        expect(notification[:priority]).to eq(:high)
        expect(notification[:desktop]).to be(true)
        expect(notification[:sound]).to be(true)
        expect(notification[:timestamp]).to be_within(1).of(Time.now)
      end
    end

    describe '#should_show_desktop?' do
      let(:high_notification) { { priority: :high, desktop: true } }
      let(:low_notification) { { priority: :low, desktop: true } }
      
      it 'shows desktop for high priority notifications' do
        allow(notification_manager).to receive(:instance_variable_get).with(:@desktop_notifications).and_return(true)
        expect(notification_manager.send(:should_show_desktop?, high_notification)).to be(true)
      end

      it 'does not show desktop for low priority notifications' do
        allow(notification_manager).to receive(:instance_variable_get).with(:@desktop_notifications).and_return(true)
        expect(notification_manager.send(:should_show_desktop?, low_notification)).to be(false)
      end
    end

    describe '#should_play_sound?' do
      let(:critical_notification) { { priority: :critical, sound: true } }
      let(:medium_notification) { { priority: :medium, sound: true } }
      
      it 'plays sound for critical notifications' do
        allow(notification_manager).to receive(:instance_variable_get).with(:@sound_enabled).and_return(true)
        expect(notification_manager.send(:should_play_sound?, critical_notification)).to be(true)
      end

      it 'does not play sound for medium priority notifications' do
        allow(notification_manager).to receive(:instance_variable_get).with(:@sound_enabled).and_return(true)
        expect(notification_manager.send(:should_play_sound?, medium_notification)).to be(false)
      end
    end
  end
end