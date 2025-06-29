# frozen_string_literal: true

require_relative 'logger'
require_relative 'agent_spawner'
require_relative 'session_manager'
require_relative 'project_analyzer'

module EnhanceSwarm
  # Intelligent task coordination and delegation system
  # Implements real dev team patterns with minimal overlap and smart handoffs
  class TaskCoordinator
    def initialize
      @config = EnhanceSwarm.configuration
      @session_manager = SessionManager.new
      @agent_spawner = AgentSpawner.new
      @project_analyzer = ProjectAnalyzer.new
      @task_queue = []
      @agent_assignments = {}
    end

    def coordinate_task(description)
      Logger.info("🎯 Starting intelligent task coordination: #{description}")
      
      # 1. Analyze project context
      @project_analyzer.analyze
      project_context = @project_analyzer.generate_smart_defaults
      
      # 2. Break down task into specialized subtasks
      subtasks = decompose_task(description, project_context)
      
      # 3. Create dependency-aware execution plan
      execution_plan = create_execution_plan(subtasks)
      
      # 4. Execute plan with coordination
      execute_coordinated_plan(execution_plan)
    end

    private

    def decompose_task(description, context)
      # Smart task decomposition based on project type and description
      subtasks = []
      
      # Detect task complexity and type
      task_type = analyze_task_type(description)
      project_type = context[:project_type] || 'unknown'
      
      case task_type
      when :full_feature
        subtasks = create_full_feature_subtasks(description, project_type)
      when :backend_focused
        subtasks = create_backend_subtasks(description, project_type)
      when :frontend_focused
        subtasks = create_frontend_subtasks(description, project_type)
      when :infrastructure
        subtasks = create_infrastructure_subtasks(description, project_type)
      else
        subtasks = create_general_subtasks(description, project_type)
      end
      
      Logger.info("📋 Decomposed into #{subtasks.length} specialized subtasks")
      subtasks
    end

    def analyze_task_type(description)
      description_lower = description.downcase
      
      # Full feature indicators
      if description_lower.match?(/add|create|build|implement|new feature/i) &&
         description_lower.match?(/form|page|ui|interface|frontend/i) &&
         description_lower.match?(/model|database|api|backend/i)
        return :full_feature
      end
      
      # Backend-focused indicators
      if description_lower.match?(/api|model|database|migration|service|backend/i)
        return :backend_focused
      end
      
      # Frontend-focused indicators  
      if description_lower.match?(/ui|interface|form|page|component|styling|frontend/i)
        return :frontend_focused
      end
      
      # Infrastructure indicators
      if description_lower.match?(/deploy|config|setup|install|docker|environment/i)
        return :infrastructure
      end
      
      :general
    end

    def create_full_feature_subtasks(description, project_type)
      [
        {
          id: "backend-#{Time.now.to_i}",
          role: 'backend',
          description: "Implement backend logic, models, and API endpoints for: #{description}",
          dependencies: [],
          priority: 1,
          context: build_backend_context(project_type)
        },
        {
          id: "frontend-#{Time.now.to_i + 1}",
          role: 'frontend', 
          description: "Create user interface and frontend components for: #{description}",
          dependencies: ["backend-#{Time.now.to_i}"],
          priority: 2,
          context: build_frontend_context(project_type)
        },
        {
          id: "qa-#{Time.now.to_i + 2}",
          role: 'qa',
          description: "Create comprehensive tests and quality assurance for: #{description}",
          dependencies: ["backend-#{Time.now.to_i}", "frontend-#{Time.now.to_i + 1}"],
          priority: 3,
          context: build_qa_context(project_type)
        },
        {
          id: "integration-#{Time.now.to_i + 3}",
          role: 'general',
          description: "Integrate, refine, and polish the complete implementation of: #{description}",
          dependencies: ["qa-#{Time.now.to_i + 2}"],
          priority: 4,
          context: build_integration_context(project_type)
        }
      ]
    end

    def create_backend_subtasks(description, project_type)
      [
        {
          id: "backend-#{Time.now.to_i}",
          role: 'backend',
          description: description,
          dependencies: [],
          priority: 1,
          context: build_backend_context(project_type)
        },
        {
          id: "qa-backend-#{Time.now.to_i + 1}",
          role: 'qa',
          description: "Test and validate backend implementation: #{description}",
          dependencies: ["backend-#{Time.now.to_i}"],
          priority: 2,
          context: build_qa_context(project_type)
        }
      ]
    end

    def create_frontend_subtasks(description, project_type)
      [
        {
          id: "frontend-#{Time.now.to_i}",
          role: 'frontend',
          description: description,
          dependencies: [],
          priority: 1,
          context: build_frontend_context(project_type)
        },
        {
          id: "qa-frontend-#{Time.now.to_i + 1}",
          role: 'qa',
          description: "Test and validate frontend implementation: #{description}",
          dependencies: ["frontend-#{Time.now.to_i}"],
          priority: 2,
          context: build_qa_context(project_type)
        }
      ]
    end

    def create_infrastructure_subtasks(description, project_type)
      [
        {
          id: "infra-#{Time.now.to_i}",
          role: 'general',
          description: description,
          dependencies: [],
          priority: 1,
          context: build_infrastructure_context(project_type)
        }
      ]
    end

    def create_general_subtasks(description, project_type)
      [
        {
          id: "general-#{Time.now.to_i}",
          role: 'general',
          description: description,
          dependencies: [],
          priority: 1,
          context: build_general_context(project_type)
        }
      ]
    end

    def build_backend_context(project_type)
      {
        role_focus: "You are a Backend Developer specializing in #{project_type}",
        responsibilities: [
          "Implement business logic and data models",
          "Create secure and efficient API endpoints", 
          "Design proper database schemas and migrations",
          "Follow #{project_type} best practices and conventions",
          "Ensure proper error handling and validation"
        ],
        best_practices: get_backend_best_practices(project_type),
        shared_knowledge: "Always coordinate with frontend team for API contracts"
      }
    end

    def build_frontend_context(project_type)
      {
        role_focus: "You are a Frontend/UX Developer specializing in #{project_type}",
        responsibilities: [
          "Create intuitive and responsive user interfaces",
          "Implement consistent design patterns and components",
          "Ensure accessibility and cross-browser compatibility",
          "Integrate with backend APIs effectively",
          "Follow #{project_type} frontend best practices"
        ],
        best_practices: get_frontend_best_practices(project_type),
        shared_knowledge: "Maintain component library and design system consistency"
      }
    end

    def build_qa_context(project_type)
      {
        role_focus: "You are a QA Engineer specializing in #{project_type}",
        responsibilities: [
          "Create comprehensive test suites (unit, integration, system)",
          "Validate functionality against requirements",
          "Check for security vulnerabilities and edge cases",
          "Ensure code quality and maintainability",
          "Provide actionable feedback for improvements"
        ],
        best_practices: get_qa_best_practices(project_type),
        shared_knowledge: "Focus on preventing regressions and ensuring reliability"
      }
    end

    def build_integration_context(project_type)
      {
        role_focus: "You are a Lead Developer responsible for integration",
        responsibilities: [
          "Merge and integrate work from all team members",
          "Resolve conflicts and ensure system cohesion",
          "Perform final refactoring and optimization",
          "Validate complete feature functionality",
          "Prepare final implementation for deployment"
        ],
        best_practices: get_integration_best_practices(project_type),
        shared_knowledge: "Ensure all pieces work together seamlessly"
      }
    end

    def build_infrastructure_context(project_type)
      {
        role_focus: "You are a DevOps/Infrastructure specialist",
        responsibilities: [
          "Configure deployment and environment setup",
          "Implement CI/CD pipelines and automation",
          "Manage dependencies and system configuration",
          "Ensure scalability and performance",
          "Handle security and monitoring setup"
        ],
        best_practices: get_infrastructure_best_practices(project_type),
        shared_knowledge: "Focus on reliability and maintainability"
      }
    end

    def build_general_context(project_type)
      {
        role_focus: "You are a Full-Stack Developer",
        responsibilities: [
          "Handle diverse development tasks across the stack",
          "Apply best practices for #{project_type}",
          "Ensure code quality and maintainability",
          "Consider system-wide implications",
          "Coordinate with specialized team members when needed"
        ],
        best_practices: get_general_best_practices(project_type),
        shared_knowledge: "Balance speed with quality and maintainability"
      }
    end

    def get_backend_best_practices(project_type)
      case project_type
      when 'rails'
        [
          "Follow Rails conventions and RESTful design",
          "Use service objects for complex business logic",
          "Implement proper validations and error handling",
          "Write comprehensive model and controller tests",
          "Use Strong Parameters for security"
        ]
      when 'django'
        [
          "Follow Django patterns and MVT architecture",
          "Use Django REST framework for APIs",
          "Implement proper authentication and permissions",
          "Write comprehensive unit and integration tests",
          "Use Django forms for validation"
        ]
      else
        [
          "Follow framework conventions and best practices",
          "Implement proper error handling and validation",
          "Write comprehensive tests",
          "Ensure security and performance",
          "Document API contracts clearly"
        ]
      end
    end

    def get_frontend_best_practices(project_type)
      case project_type
      when 'rails'
        [
          "Use Stimulus.js for interactive behavior",
          "Follow Rails UJS patterns",
          "Implement responsive design with consistent styling",
          "Use partials and helpers for reusable components",
          "Ensure proper CSRF protection"
        ]
      when 'react', 'nextjs'
        [
          "Use functional components with hooks",
          "Implement proper state management",
          "Create reusable component library",
          "Ensure accessibility and performance",
          "Follow React best practices"
        ]
      else
        [
          "Create intuitive and accessible interfaces",
          "Implement responsive design patterns",
          "Use modern CSS and JavaScript practices",
          "Ensure cross-browser compatibility",
          "Optimize for performance"
        ]
      end
    end

    def get_qa_best_practices(project_type)
      [
        "Write tests that cover happy path and edge cases",
        "Implement integration tests for critical workflows",
        "Use appropriate testing frameworks and tools",
        "Focus on maintainable and readable test code",
        "Validate security and performance requirements",
        "Provide clear and actionable feedback"
      ]
    end

    def get_integration_best_practices(project_type)
      [
        "Carefully review all changes before integration",
        "Resolve merge conflicts thoughtfully",
        "Ensure consistent code style across all components",
        "Validate that integrated system meets requirements",
        "Perform final testing and optimization",
        "Document any architectural decisions"
      ]
    end

    def get_infrastructure_best_practices(project_type)
      [
        "Use infrastructure as code principles",
        "Implement proper security and monitoring",
        "Ensure scalability and reliability",
        "Document deployment procedures",
        "Use automated testing for infrastructure",
        "Follow security best practices"
      ]
    end

    def get_general_best_practices(project_type)
      [
        "Follow project conventions and standards",
        "Write clean, readable, and maintainable code",
        "Implement appropriate tests",
        "Consider security and performance implications",
        "Document important decisions and changes",
        "Collaborate effectively with team members"
      ]
    end

    def create_execution_plan(subtasks)
      # Sort by priority and dependencies
      plan = {
        phases: [],
        total_tasks: subtasks.length,
        estimated_duration: estimate_duration(subtasks)
      }
      
      # Group tasks by dependency level
      phases = group_by_dependencies(subtasks)
      phases.each_with_index do |phase_tasks, index|
        plan[:phases] << {
          phase_number: index + 1,
          description: describe_phase(phase_tasks),
          tasks: phase_tasks,
          estimated_duration: estimate_phase_duration(phase_tasks)
        }
      end
      
      plan
    end

    def group_by_dependencies(subtasks)
      phases = []
      remaining_tasks = subtasks.dup
      completed_task_ids = []
      
      while remaining_tasks.any?
        # Find tasks with no unfulfilled dependencies
        ready_tasks = remaining_tasks.select do |task|
          task[:dependencies].all? { |dep| completed_task_ids.include?(dep) }
        end
        
        break if ready_tasks.empty? # Circular dependency or other issue
        
        phases << ready_tasks
        completed_task_ids.concat(ready_tasks.map { |t| t[:id] })
        remaining_tasks -= ready_tasks
      end
      
      phases
    end

    def describe_phase(tasks)
      roles = tasks.map { |t| t[:role] }.uniq
      case roles
      when ['backend']
        "Backend Development Phase"
      when ['frontend'] 
        "Frontend Development Phase"
      when ['qa']
        "Quality Assurance Phase"
      when ['backend', 'frontend']
        "Parallel Development Phase"
      else
        "Integration & Coordination Phase"
      end
    end

    def estimate_duration(subtasks)
      # Basic estimation - can be enhanced with historical data
      subtasks.length * 5 # 5 minutes per subtask average
    end

    def estimate_phase_duration(tasks)
      # Parallel tasks in same phase
      [tasks.length * 3, 10].min # Max 10 minutes per phase
    end

    def execute_coordinated_plan(plan)
      Logger.info("🚀 Executing coordinated plan with #{plan[:phases].length} phases")
      
      plan[:phases].each_with_index do |phase, index|
        Logger.info("📍 Phase #{index + 1}: #{phase[:description]}")
        
        # Execute all tasks in this phase (they can run in parallel)
        phase_results = execute_phase(phase[:tasks])
        
        # Validate phase completion before proceeding
        if phase_results.all? { |result| result[:success] }
          Logger.info("✅ Phase #{index + 1} completed successfully")
        else
          Logger.error("❌ Phase #{index + 1} had failures, stopping execution")
          break
        end
        
        # Brief pause between phases for coordination
        sleep(2) if index < plan[:phases].length - 1
      end
    end

    def execute_phase(tasks)
      results = []
      
      # Spawn agents for all tasks in this phase
      tasks.each do |task|
        enhanced_prompt = build_enhanced_task_prompt(task)
        
        result = @agent_spawner.spawn_agent(
          role: task[:role],
          task: enhanced_prompt,
          worktree: true
        )
        
        if result
          @agent_assignments[task[:id]] = result
          results << { task_id: task[:id], success: true, agent_info: result }
          Logger.info("✅ Spawned #{task[:role]} agent for task: #{task[:id]}")
        else
          results << { task_id: task[:id], success: false }
          Logger.error("❌ Failed to spawn agent for task: #{task[:id]}")
        end
      end
      
      results
    end

    def build_enhanced_task_prompt(task)
      context = task[:context]
      
      <<~PROMPT
        #{context[:role_focus]}
        
        ## Your Mission
        #{task[:description]}
        
        ## Your Responsibilities
        #{context[:responsibilities].map { |r| "- #{r}" }.join("\n")}
        
        ## Best Practices to Follow
        #{context[:best_practices].map { |p| "- #{p}" }.join("\n")}
        
        ## Team Coordination Note
        #{context[:shared_knowledge]}
        
        ## Task Context
        - Task ID: #{task[:id]}
        - Priority: #{task[:priority]}
        - Dependencies: #{task[:dependencies].any? ? task[:dependencies].join(', ') : 'None'}
        
        ## Important Instructions
        1. Focus ONLY on your specialized area of expertise
        2. Follow the project's existing patterns and conventions
        3. Write high-quality, production-ready code
        4. Include appropriate tests for your implementation
        5. Consider how your work integrates with other team members
        6. Document any important decisions or changes
        7. If you encounter issues, provide detailed implementation guidance
        
        Begin your specialized work now. Be thorough and professional.
      PROMPT
    end
  end
end