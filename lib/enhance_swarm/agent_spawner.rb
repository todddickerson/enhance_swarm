# frozen_string_literal: true

require 'open3'
require 'tempfile'
require_relative 'command_executor'
require_relative 'session_manager'
require_relative 'logger'
require_relative 'resource_manager'

module EnhanceSwarm
  class AgentSpawner
    def initialize
      @config = EnhanceSwarm.configuration
      @session_manager = SessionManager.new
      @resource_manager = ResourceManager.new
    end

    def spawn_agent(role:, task:, worktree: true)
      Logger.info("Spawning #{role} agent for task: #{task}")
      
      # Check resource limits before spawning
      resource_check = @resource_manager.can_spawn_agent?
      unless resource_check[:allowed]
        Logger.error("Cannot spawn agent - resource limits exceeded:")
        resource_check[:reasons].each { |reason| Logger.error("  - #{reason}") }
        return false
      end
      
      begin
        # Create worktree if requested
        worktree_path = nil
        if worktree
          worktree_path = create_agent_worktree(role)
          return false unless worktree_path
        end

        # Generate agent prompt
        prompt = build_agent_prompt(task, role, worktree_path)
        
        # Spawn the agent process
        pid = spawn_claude_process(prompt, role, worktree_path)
        return false unless pid

        # Register agent in session
        success = @session_manager.add_agent(role, pid, worktree_path, task)
        
        if success
          Logger.info("Successfully spawned #{role} agent (PID: #{pid})")
          { pid: pid, worktree_path: worktree_path, role: role }
        else
          Logger.error("Failed to register agent in session")
          cleanup_failed_spawn(pid, worktree_path)
          false
        end

      rescue StandardError => e
        Logger.error("Failed to spawn #{role} agent: #{e.message}")
        cleanup_failed_spawn(nil, worktree_path)
        false
      end
    end

    def spawn_multiple_agents(agents)
      results = []
      
      agents.each_with_index do |agent_config, index|
        # Add jitter to prevent resource contention
        sleep(2 + rand(0..2)) if index > 0
        
        result = spawn_agent(
          role: agent_config[:role],
          task: agent_config[:task],
          worktree: agent_config.fetch(:worktree, true)
        )
        
        results << result if result
      end
      
      results
    end

    def get_running_agents
      @session_manager.check_agent_processes
    end

    def stop_agent(pid)
      begin
        Process.kill('TERM', pid.to_i)
        @session_manager.update_agent_status(pid, 'stopped', Time.now.iso8601)
        Logger.info("Stopped agent with PID: #{pid}")
        true
      rescue Errno::ESRCH
        # Process already stopped
        @session_manager.update_agent_status(pid, 'stopped', Time.now.iso8601)
        true
      rescue StandardError => e
        Logger.error("Failed to stop agent (PID: #{pid}): #{e.message}")
        false
      end
    end

    def stop_all_agents
      active_agents = @session_manager.get_active_agents
      stopped_count = 0
      
      active_agents.each do |agent|
        if stop_agent(agent[:pid])
          stopped_count += 1
        end
      end
      
      Logger.info("Stopped #{stopped_count}/#{active_agents.length} agents")
      stopped_count
    end

    def claude_cli_available?
      @claude_cli_available ||= begin
        result = `claude --version 2>/dev/null`
        $?.success? && result.strip.length > 0
      rescue StandardError
        false
      end
    end

    private

    def create_agent_worktree(role)
      timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
      worktree_name = "#{role}-#{timestamp}"
      worktree_path = File.join('.enhance_swarm', 'worktrees', worktree_name)
      
      begin
        # Ensure worktrees directory exists
        worktrees_dir = File.dirname(worktree_path)
        FileUtils.mkdir_p(worktrees_dir) unless Dir.exist?(worktrees_dir)
        
        # Check if we have any commits (required for git worktree)
        ensure_initial_commit
        
        # Create git worktree
        CommandExecutor.execute('git', 'worktree', 'add', worktree_path)
        
        Logger.info("Created worktree for #{role} agent: #{worktree_path}")
        File.expand_path(worktree_path)
        
      rescue CommandExecutor::CommandError => e
        Logger.error("Failed to create worktree for #{role}: #{e.message}")
        
        # If the error is about no commits, try to create one
        if e.message.include?('does not have any commits yet')
          Logger.info("No initial commit found, creating one...")
          if create_initial_commit
            retry
          end
        end
        
        nil
      end
    end

    def ensure_initial_commit
      # Check if we have any commits
      result = CommandExecutor.execute('git', 'log', '--oneline', '-1')
      true
    rescue CommandExecutor::CommandError
      # No commits exist, create initial commit
      create_initial_commit
    end

    def create_initial_commit
      begin
        # Add all files to git
        CommandExecutor.execute('git', 'add', '.')
        
        # Create initial commit
        CommandExecutor.execute('git', 'commit', '-m', 'Initial commit - EnhanceSwarm setup')
        
        Logger.info("Created initial git commit for EnhanceSwarm")
        true
      rescue CommandExecutor::CommandError => e
        Logger.error("Failed to create initial commit: #{e.message}")
        false
      end
    end

    def spawn_claude_process(prompt, role, worktree_path)
      begin
        # Check if Claude CLI is available
        unless claude_cli_available?
          Logger.error("Claude CLI not available - falling back to simulation mode")
          return spawn_simulated_process(role, worktree_path)
        end

        # Prepare the enhanced prompt for the agent
        enhanced_prompt = build_enhanced_agent_prompt(prompt, role, worktree_path)
        
        # Create working directory for the agent
        agent_dir = worktree_path || Dir.pwd
        
        # Prepare environment
        env = build_agent_environment(role, agent_dir)
        
        # Create a temporary script to handle the Claude interaction
        script_file = create_agent_script(enhanced_prompt, role, agent_dir)
        
        # Ensure logs directory exists
        FileUtils.mkdir_p(File.join('.enhance_swarm', 'logs'))
        
        # Spawn the Claude process
        pid = Process.spawn(
          env,
          '/bin/bash', script_file,
          chdir: agent_dir,
          out: File.join('.enhance_swarm', 'logs', "#{role}_output.log"),
          err: File.join('.enhance_swarm', 'logs', "#{role}_error.log")
        )

        # Don't wait for the process - let it run independently
        Process.detach(pid)
        
        Logger.info("Spawned Claude agent process: #{role} (PID: #{pid})")
        pid
        
      rescue StandardError => e
        Logger.error("Failed to spawn Claude process for #{role}: #{e.message}")
        
        # Enhanced debugging information
        if ENV['ENHANCE_SWARM_DEBUG'] == 'true'
          Logger.error("Debug info - Error class: #{e.class}")
          Logger.error("Debug info - Backtrace: #{e.backtrace.first(3).join(', ')}")
          Logger.error("Debug info - Working directory: #{agent_dir}")
          Logger.error("Debug info - Claude CLI available: #{claude_cli_available?}")
        end
        
        # Fall back to simulation mode
        spawn_simulated_process(role, worktree_path)
      end
    end

    def build_enhanced_agent_prompt(base_prompt, role, worktree_path)
      config = EnhanceSwarm.configuration
      
      <<~PROMPT
        You are a specialized #{role.upcase} agent working as part of an EnhanceSwarm multi-agent team.
        
        ## Your Role: #{role.capitalize}
        #{get_role_description(role)}
        
        ## Working Context:
        - Project: #{config.project_name}
        - Technology Stack: #{config.technology_stack}
        - Working Directory: #{worktree_path || Dir.pwd}
        - Code Standards: #{config.code_standards.join(', ')}
        
        ## Your Task:
        #{base_prompt}
        
        ## Critical Instructions:
        1. YOU MUST ACTUALLY IMPLEMENT CODE - Use Read, Edit, Write, and Bash tools to create real files
        2. Stay focused on your role as a #{role} specialist
        3. Follow the project's code standards and conventions  
        4. Work autonomously - DO NOT ASK FOR PERMISSION, JUST IMPLEMENT
        5. Create high-quality, production-ready code with proper validations
        6. 🚨 FOR BULLET TRAIN PROJECTS: ALWAYS use Super Scaffolding - NEVER create manual models!
        7. 🎨 FOR BULLET TRAIN PROJECTS: ALWAYS use Tailwind CSS - NEVER Bootstrap or custom CSS!
        8. Use Bash tool to run Rails generators, database migrations, and tests
        9. Commit your changes when complete using Git commands
        10. If you encounter any issues, fix them and continue until task is complete
        
        ## Available Tools:
        You have access to all Claude Code tools for file editing, terminal commands, and project analysis.
        Note: If file write operations fail due to permissions, focus on providing comprehensive 
        implementation details and code that could be manually applied.
        
        Begin working on your assigned task now.
      PROMPT
    end

    def get_role_description(role)
      config = EnhanceSwarm.configuration
      project_analyzer = ProjectAnalyzer.new
      project_context = project_analyzer.generate_smart_defaults
      
      # Check if this is a Bullet Train project
      is_bullet_train = has_bullet_train_stack?(config, project_context)
      
      base_description = case role.to_s.downcase
      when 'backend'
        'You specialize in server-side logic, APIs, database design, models, and business logic implementation.'
      when 'frontend'
        'You specialize in user interfaces, client-side code, styling, user experience, and presentation layer.'
      when 'qa'
        'You specialize in testing, quality assurance, test automation, edge case analysis, and validation.'
      when 'ux'
        'You specialize in user experience design, interaction flows, accessibility, and user-centric improvements.'
      when 'general'
        'You are a general-purpose agent capable of handling various development tasks across the full stack.'
      when 'scaffolding'
        'You specialize in Bullet Train Super Scaffolding, following Andrew Culver\'s conventions for team-scoped architecture, model relationships, and framework configuration.'
      else
        "You are a #{role} specialist agent focusing on your area of expertise."
      end
      
      # Add Bullet Train specific instructions if this is a BT project
      if is_bullet_train
        base_description + get_bullet_train_role_enhancement(role)
      else
        base_description
      end
    end
    
    def has_bullet_train_stack?(config, project_context)
      # Check Gemfile for bullet_train gems
      return true if File.exist?('Gemfile') && File.read('Gemfile').include?('bullet_train')
      
      # Check technology stack
      tech_stack = config.technology_stack || project_context[:technology_stack] || []
      tech_stack.include?('Bullet Train')
    rescue
      false
    end
    
    def get_bullet_train_role_enhancement(role)
      case role.to_s.downcase
      when 'backend'
        <<~BT_ENHANCEMENT
        
        
        ## 🚅 BULLET TRAIN BACKEND SPECIALIZATION:
        
        **CRITICAL: Use Super Scaffolding for ALL model generation**
        - NEVER create models manually - always use: rails generate super_scaffold ModelName Team field:field_type
        - Use bin/resolve ClassName --eject --open before modifying any existing models
        - ALL models must inherit team-scoped architecture: belongs_to :team
        
        **Model Structure (EXACT pattern):**
        ```ruby
        class Contact < ApplicationRecord
          include Contacts::Base  # Gem concern with core logic
          include Webhooks::Outgoing::TeamSupport
          # 🚅 add concerns above.
          
          # 🚅 add belongs_to associations above.
          # 🚅 add has_many associations above.
          # 🚅 add scopes above.
          # 🚅 add validations above.
          # 🚅 add callbacks above.
          # 🚅 add methods above.
        end
        ```
        
        **🚨 MANDATORY EXECUTION SEQUENCE - NO EXCEPTIONS:**
        1. FIRST: bundle exec rails generate super_scaffold Contact Team name:text_field email:email_field phone:phone_field company:text_field
        2. THEN: bundle exec rails db:migrate
        3. THEN: bundle exec rails test (to verify everything works)
        4. ONLY IF NEEDED: bin/resolve Contacts::Base --eject --open (for customization)
        5. Configure config/models/roles.yml with proper permissions
        
        **🚨 CRITICAL: You MUST actually run these commands using the Bash tool - not just describe them!**
        **🚨 DO NOT create manual Rails models/controllers - ONLY use Super Scaffolding!**
        **🚨 NEVER skip step 1 - Super Scaffolding is MANDATORY for Bullet Train projects!**
        
        **API Routes (add to config/routes/api/v1.rb):**
        ```ruby
        namespace :api do
          namespace :v1 do
            shallow do
              resources :teams do
                resources :contacts
              end
            end
          end
        end
        ```
        BT_ENHANCEMENT
      when 'frontend'
        <<~BT_ENHANCEMENT
        
        
        ## 🚅 BULLET TRAIN FRONTEND SPECIALIZATION:
        
        **CRITICAL: Customize generated views, don't create from scratch**
        - Super Scaffolding generates account/contacts/* views automatically
        - Use bin/resolve account/contacts/_form --eject for view customization
        - All views follow account-scoped pattern: app/views/account/contacts/
        
        **Required View Structure:**
        - app/views/account/contacts/index.html.erb (team-scoped listing)
        - app/views/account/contacts/show.html.erb (individual contact)
        - app/views/account/contacts/_form.html.erb (create/edit form)
        - Use Bullet Train themes and components
        
        **🎨 STYLING: Use Tailwind CSS (Bullet Train Default)**
        - ALWAYS use Tailwind CSS classes (bg-blue-500, text-white, etc.)
        - NEVER use Bootstrap or custom CSS - BT uses Tailwind by default
        - Use BT's Tailwind theme tokens and design system
        - Follow BT responsive patterns: sm:, md:, lg: breakpoints
        - Use BT component classes: .btn, .card, .form-control (Tailwind-based)
        
        **Navigation Integration:**
        - Add to account navigation (usually in app/views/account/shared/_menu.html.erb)
        - Use BT icon helpers and Tailwind styling patterns
        - Ensure mobile-responsive with Tailwind responsive classes
        
        **Commands:**
        1. bin/resolve account/contacts --eject (to customize views)
        2. bin/resolve shared/fields --open (for field customization)
        3. Use existing BT theme patterns and components
        BT_ENHANCEMENT
      when 'qa'
        <<~BT_ENHANCEMENT
        
        
        ## 🚅 BULLET TRAIN QA SPECIALIZATION:
        
        **CRITICAL: Test team-scoped behavior and permissions**
        - Test models with proper team association and scoping
        - Validate role-based permissions from config/models/roles.yml
        - Test API endpoints with proper authentication and authorization
        
        **Required Test Structure:**
        ```ruby
        # spec/models/contact_spec.rb
        require 'rails_helper'
        
        RSpec.describe Contact, type: :model do
          let(:team) { create(:team) }
          let(:contact) { create(:contact, team: team) }
          
          it "belongs to team" do
            expect(contact.team).to eq(team)
          end
          
          it "validates required fields" do
            # Test BT field validations
          end
          
          it "respects team scoping" do
            # Test team isolation
          end
        end
        ```
        
        **API Testing:**
        - spec/requests/api/v1/contacts_spec.rb with proper authentication
        - Test team-scoped API access and permissions
        - Validate webhook payload generation
        
        **Commands:**
        1. bundle exec rspec spec/models/contact_spec.rb
        2. bundle exec rspec spec/requests/api/v1/contacts_spec.rb
        3. Test with different user roles and team memberships
        BT_ENHANCEMENT
      when 'scaffolding'
        <<~BT_ENHANCEMENT
        
        
        ## 🚅 BULLET TRAIN SCAFFOLDING MASTER PROTOCOL:
        
        **🚨 MANDATORY EXECUTION SEQUENCE (MUST RUN THESE EXACT COMMANDS) - NO EXCEPTIONS:**
        1. bundle exec rails generate super_scaffold Contact Team name:text_field email:email_field phone:phone_field company:text_field
        2. bundle exec rails db:migrate
        3. bundle exec rails test (verify everything works)
        4. Configure roles in config/models/roles.yml
        5. Add API routes to config/routes/api/v1.rb
        6. bundle exec rails test (final verification)
        
        **🚨 YOU MUST USE THE BASH TOOL TO ACTUALLY EXECUTE THESE COMMANDS - NOT JUST WRITE CODE FILES!**
        **🚨 FAILURE TO RUN SUPER_SCAFFOLD COMMAND IS A CRITICAL ERROR!**
        **🚨 DO NOT CREATE MANUAL MODELS/CONTROLLERS - BULLET TRAIN REQUIRES SUPER SCAFFOLDING!**
        
        **POST-SCAFFOLDING OPTIMIZATION:**
        - bin/resolve Contacts::Base --eject --open (for model customization)
        - bin/resolve account/contacts/_form --eject (for view customization)
        - Add custom validations and business logic
        - Configure webhooks and integrations
        
        **TEAM ARCHITECTURE VERIFICATION:**
        - Ensure all models use team-scoped ownership
        - Validate proper role inheritance in config/models/roles.yml
        - Test API endpoints respect team boundaries
        - Confirm webhook payloads include team context
        BT_ENHANCEMENT
      else
        ''
      end
    end

    def create_agent_script(prompt, role, working_dir)
      # Create a temporary script file that will run Claude
      script_file = Tempfile.new(['agent_script', '.sh'])
      
      begin
        script_content = <<~SCRIPT
          #!/bin/bash
          set -e
          
          # Agent script for #{role} agent
          echo "Starting #{role} agent in #{working_dir}"
          
          # Change to working directory
          cd "#{working_dir}"
          
          # Create a unique temporary prompt file using PID and timestamp
          TIMESTAMP=$(date +%s)
          PROMPT_FILE="/tmp/claude_prompt_#{role}_$${TIMESTAMP}_$$.md"
          
          # Ensure unique filename by adding counter if needed
          COUNTER=0
          while [[ -e "$PROMPT_FILE" ]]; do
            COUNTER=$((COUNTER + 1))
            PROMPT_FILE="/tmp/claude_prompt_#{role}_$${TIMESTAMP}_$$_${COUNTER}.md"
          done
          
          cat > "$PROMPT_FILE" << 'EOF'
          #{prompt}
          EOF
          
          # Run Claude with the prompt in interactive mode with full permissions
          echo "Executing Claude for #{role} agent..."
          claude --dangerously-skip-permissions < "$PROMPT_FILE"
          
          # Cleanup
          rm -f "$PROMPT_FILE"
          
          echo "#{role} agent completed successfully"
        SCRIPT
        
        script_file.write(script_content)
        script_file.flush
        script_file.close
        
        # Make the script executable
        File.chmod(0755, script_file.path)
        
        script_file.path
      rescue StandardError => e
        Logger.error("Failed to create agent script: #{e.message}")
        script_file.close if script_file && !script_file.closed?
        raise e
      end
    end

    def spawn_simulated_process(role, worktree_path)
      # Fallback simulation when Claude CLI is not available
      Logger.warn("Using simulation mode for #{role} agent")
      
      # Create a simple background process that simulates agent work
      pid = Process.spawn(
        '/bin/bash', '-c', 
        "sleep 30 && echo 'Simulated #{role} agent completed' > /dev/null",
        chdir: worktree_path || Dir.pwd
      )
      
      Process.detach(pid)
      Logger.info("Spawned simulated agent: #{role} (PID: #{pid})")
      pid
    end

    def build_agent_environment(role, worktree_path)
      env = ENV.to_h
      env['ENHANCE_SWARM_ROLE'] = role
      env['ENHANCE_SWARM_WORKTREE'] = worktree_path if worktree_path
      env['ENHANCE_SWARM_SESSION'] = @session_manager.read_session&.dig(:session_id)
      env
    end

    def build_agent_prompt(task, role, worktree_path)
      # Sanitize inputs
      safe_task = sanitize_task_description(task)
      safe_role = sanitize_role(role)
      safe_test_command = sanitize_command(@config.test_command)

      timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
      task_words = safe_task.split.first(5).join(' ')
      working_dir = worktree_path || Dir.pwd

      base_prompt = <<~PROMPT
        AUTONOMOUS EXECUTION REQUIRED - #{safe_role.upcase} SPECIALIST

        TASK: #{safe_task}

        WORKING DIRECTORY: #{working_dir}

        CRITICAL INSTRUCTIONS:
        1. You have FULL PERMISSION to read, write, edit files and run commands
        2. Work in the directory: #{working_dir}
        3. DO NOT wait for any permissions - proceed immediately
        4. Complete the task fully and thoroughly
        5. Test your implementation using: #{safe_test_command}
        6. When complete:
           - Run: git add -A
           - Run: git commit -m '#{safe_role}: #{task_words}...'
           - Create completion marker: echo "completed" > .enhance_swarm/completed/#{safe_role}_completed.txt
        7. Document what was implemented in your final message

        PROJECT CONTEXT:
        - Technology stack: #{Array(@config.technology_stack).join(', ')}
        - Test command: #{safe_test_command}
        - Project type: #{@config.project_name}

        Remember: You are autonomous. Make all decisions needed to complete this task successfully.
      PROMPT

      # Add role-specific instructions
      case safe_role
      when 'ux'
        base_prompt += "\n\nFOCUS: UI/UX design, templates, user experience, styling, and accessibility."
      when 'backend'
        base_prompt += "\n\nFOCUS: Models, services, APIs, business logic, database operations, and security."
      when 'frontend'
        base_prompt += "\n\nFOCUS: Controllers, views, JavaScript, forms, user interactions, and integration."
      when 'qa'
        base_prompt += "\n\nFOCUS: Comprehensive testing, edge cases, quality assurance, and validation."
      when 'scaffolding'
        base_prompt += "\n\nFOCUS: Bullet Train Super Scaffolding, Andrew Culver's best practices, team-scoped architecture, and framework setup."
      end

      base_prompt
    end

    def cleanup_failed_spawn(pid, worktree_path)
      # Clean up process if it was started
      if pid
        begin
          Process.kill('KILL', pid.to_i)
        rescue StandardError
          # Process may not exist, ignore
        end
      end

      # Clean up worktree if it was created
      if worktree_path && Dir.exist?(worktree_path)
        begin
          CommandExecutor.execute('git', 'worktree', 'remove', '--force', worktree_path)
        rescue StandardError => e
          Logger.warn("Failed to cleanup worktree #{worktree_path}: #{e.message}")
        end
      end
    end

    def sanitize_task_description(task)
      # Remove potentially dangerous characters while preserving readability
      task.to_s.gsub(/[`$\\;|&><]/, '').strip
    end

    def sanitize_role(role)
      # Only allow known safe roles
      allowed_roles = %w[ux backend frontend qa general scaffolding]
      role = role.to_s.downcase.strip
      allowed_roles.include?(role) ? role : 'general'
    end

    def sanitize_command(command)
      # Basic command sanitization - remove shell metacharacters
      command.to_s.gsub(/[;&|`$\\]/, '').strip
    end
  end
end