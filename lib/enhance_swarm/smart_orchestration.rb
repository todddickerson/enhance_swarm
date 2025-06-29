# frozen_string_literal: true

require_relative 'logger'
require_relative 'task_coordinator'

module EnhanceSwarm
  # Smart orchestration with intelligent defaults for all new installations
  # Implements real dev team patterns as the default user experience
  class SmartOrchestration
    def self.enhance_with_coordination(description)
      orchestrator = new
      orchestrator.smart_enhance(description)
    end

    def initialize
      @coordinator = TaskCoordinator.new
    end

    def smart_enhance(description)
      Logger.info("🎯 Smart Enhancement Protocol: #{description}")
      
      # Check if this looks like a review/polish task
      if review_task?(description)
        handle_review_task(description)
      else
        # Standard coordinated development
        @coordinator.coordinate_task(description)
      end
    end

    private

    def review_task?(description)
      description.downcase.match?(/review|polish|qa|test|merge|integrate|finish|complete|open browser/)
    end

    def handle_review_task(description)
      Logger.info("🔍 Detected review/polish task - using smart review workflow")
      
      # Create specialized review and polish tasks
      review_tasks = [
        "Review current codebase state and identify missing features or improvements",
        "Perform QA testing of all existing functionality and identify issues",
        "Polish and improve UI/UX consistency and user experience", 
        "Integrate all improvements and ensure everything works together",
        "Prepare for final review and browser testing"
      ]
      
      review_tasks.each_with_index do |task, index|
        Logger.info("📋 Review Phase #{index + 1}: #{task}")
        @coordinator.coordinate_task(task)
        
        # Brief pause between review phases
        sleep(1) if index < review_tasks.length - 1
      end
      
      Logger.info("✅ Smart review workflow completed")
    end
  end
end