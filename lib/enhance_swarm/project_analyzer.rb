# frozen_string_literal: true

require 'pathname'
require 'json'
require 'yaml'
require_relative 'logger'

module EnhanceSwarm
  class ProjectAnalyzer
    attr_reader :project_root, :analysis_results

    def initialize(project_root = Dir.pwd)
      @project_root = Pathname.new(project_root)
      @analysis_results = {}
    end

    def analyze
      Logger.info("Analyzing project at: #{@project_root}")
      
      @analysis_results = {
        project_type: detect_project_type,
        technology_stack: detect_technology_stack,
        documentation: analyze_documentation,
        testing_framework: detect_testing_framework,
        build_system: detect_build_system,
        deployment: detect_deployment_config,
        database: detect_database,
        frontend_framework: detect_frontend_framework,
        project_structure: analyze_project_structure,
        git_info: analyze_git_info,
        package_managers: detect_package_managers,
        ci_cd: detect_ci_cd,
        containerization: detect_containerization,
        recommended_agents: recommend_agents,
        smart_commands: generate_smart_commands
      }
      
      Logger.info("Project analysis completed. Type: #{@analysis_results[:project_type]}")
      @analysis_results
    end

    def generate_smart_defaults
      return {} unless @analysis_results.any?

      {
        project_name: detect_project_name,
        project_description: generate_project_description,
        technology_stack: @analysis_results[:technology_stack],
        test_command: @analysis_results[:smart_commands][:test],
        lint_command: @analysis_results[:smart_commands][:lint],
        build_command: @analysis_results[:smart_commands][:build],
        start_command: @analysis_results[:smart_commands][:start],
        max_concurrent_agents: recommend_agent_count,
        preferred_agents: @analysis_results[:recommended_agents],
        documentation_path: @analysis_results[:documentation][:primary_path],
        has_documentation: @analysis_results[:documentation][:has_docs]
      }
    end

    private

    def detect_project_type
      return 'rails' if rails_project?
      return 'react' if react_project?
      return 'vue' if vue_project?
      return 'angular' if angular_project?
      return 'nextjs' if nextjs_project?
      return 'django' if django_project?
      return 'flask' if flask_project?
      return 'express' if express_project?
      return 'ruby_gem' if ruby_gem?
      return 'npm_package' if npm_package?
      return 'python_package' if python_package?
      return 'static_site' if static_site?
      return 'monorepo' if monorepo?
      
      'unknown'
    end

    def detect_technology_stack
      stack = []
      
      # Languages
      stack << 'Ruby' if has_file?('Gemfile') || has_files_with_extension?('.rb')
      stack << 'JavaScript' if has_file?('package.json') || has_files_with_extension?('.js')
      stack << 'TypeScript' if has_file?('tsconfig.json') || has_files_with_extension?('.ts')
      stack << 'Python' if has_file?('requirements.txt') || has_file?('pyproject.toml') || has_files_with_extension?('.py')
      stack << 'Go' if has_file?('go.mod') || has_files_with_extension?('.go')
      stack << 'Rust' if has_file?('Cargo.toml')
      stack << 'Java' if has_file?('pom.xml') || has_file?('build.gradle')
      stack << 'PHP' if has_file?('composer.json') || has_files_with_extension?('.php')
      
      # Frameworks
      stack << 'Rails' if rails_project?
      stack << 'React' if react_project?
      stack << 'Vue.js' if vue_project?
      stack << 'Angular' if angular_project?
      stack << 'Next.js' if nextjs_project?
      stack << 'Django' if django_project?
      stack << 'Flask' if flask_project?
      stack << 'Express' if express_project?
      
      # Databases
      stack.concat(@analysis_results[:database] || detect_database)
      
      # Build tools
      stack << 'Webpack' if has_file?('webpack.config.js')
      stack << 'Vite' if has_file?('vite.config.js') || has_file?('vite.config.ts')
      stack << 'Rollup' if has_file?('rollup.config.js')
      stack << 'Parcel' if has_dependency?('parcel')
      
      # CSS frameworks
      stack << 'Tailwind CSS' if has_dependency?('tailwindcss') || has_file?('tailwind.config.js')
      stack << 'Bootstrap' if has_dependency?('bootstrap')
      stack << 'Sass' if has_files_with_extension?('.scss') || has_files_with_extension?('.sass')
      
      stack.uniq.compact
    end

    def analyze_documentation
      docs_info = {
        has_docs: false,
        primary_path: nil,
        doc_types: [],
        readme_quality: analyze_readme_quality
      }
      
      # Check for common documentation directories
      doc_paths = ['docs', 'doc', 'documentation', 'wiki', '.github']
      doc_paths.each do |path|
        if directory_exists?(path)
          docs_info[:has_docs] = true
          docs_info[:primary_path] ||= path
          docs_info[:doc_types] << path
        end
      end
      
      # Check for specific documentation files
      doc_files = ['API.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'DEPLOYMENT.md']
      doc_files.each do |file|
        if has_file?(file)
          docs_info[:has_docs] = true
          docs_info[:doc_types] << file.downcase.gsub('.md', '')
        end
      end
      
      # Check for documentation generators
      docs_info[:doc_types] << 'yard' if has_file?('.yardopts') || has_dependency?('yard')
      docs_info[:doc_types] << 'sphinx' if has_file?('conf.py') && has_files_with_extension?('.rst')
      docs_info[:doc_types] << 'jsdoc' if has_dependency?('jsdoc')
      docs_info[:doc_types] << 'typedoc' if has_dependency?('typedoc')
      
      docs_info
    end

    def detect_testing_framework
      frameworks = []
      
      # Ruby testing
      frameworks << 'RSpec' if has_dependency?('rspec') || directory_exists?('spec')
      frameworks << 'Minitest' if has_file?('test/test_helper.rb') || directory_exists?('test')
      
      # JavaScript/TypeScript testing
      frameworks << 'Jest' if has_dependency?('jest')
      frameworks << 'Mocha' if has_dependency?('mocha')
      frameworks << 'Cypress' if has_dependency?('cypress')
      frameworks << 'Playwright' if has_dependency?('playwright')
      frameworks << 'Vitest' if has_dependency?('vitest')
      
      # Python testing
      frameworks << 'pytest' if has_dependency?('pytest')
      frameworks << 'unittest' if has_files_with_pattern?('test_*.py')
      
      frameworks
    end

    def detect_build_system
      systems = []
      
      # JavaScript/Node.js
      systems << 'npm' if has_file?('package.json')
      systems << 'yarn' if has_file?('yarn.lock')
      systems << 'pnpm' if has_file?('pnpm-lock.yaml')
      
      # Ruby
      systems << 'bundler' if has_file?('Gemfile')
      systems << 'rake' if has_file?('Rakefile')
      
      # Python
      systems << 'pip' if has_file?('requirements.txt')
      systems << 'poetry' if has_file?('pyproject.toml')
      systems << 'pipenv' if has_file?('Pipfile')
      
      # Other
      systems << 'make' if has_file?('Makefile')
      systems << 'gradle' if has_file?('build.gradle')
      systems << 'maven' if has_file?('pom.xml')
      systems << 'cargo' if has_file?('Cargo.toml')
      
      systems
    end

    def detect_deployment_config
      configs = []
      
      # Container orchestration
      configs << 'kubernetes' if has_file?('kustomization.yaml') || directory_exists?('k8s')
      configs << 'docker-compose' if has_file?('docker-compose.yml') || has_file?('docker-compose.yaml')
      
      # Platform-specific
      configs << 'heroku' if has_file?('Procfile') || has_file?('app.json')
      configs << 'vercel' if has_file?('vercel.json')
      configs << 'netlify' if has_file?('netlify.toml') || has_file?('_redirects')
      configs << 'railway' if has_file?('railway.json')
      configs << 'fly.io' if has_file?('fly.toml')
      
      # Infrastructure as Code
      configs << 'terraform' if has_files_with_extension?('.tf')
      configs << 'ansible' if has_files_with_extension?('.yml') && directory_exists?('playbooks')
      
      # Rails specific
      configs << 'kamal' if has_file?('config/deploy.yml')
      
      configs
    end

    def detect_database
      databases = []
      
      # Check database gems/packages
      databases << 'PostgreSQL' if has_dependency?('pg') || has_dependency?('postgres')
      databases << 'MySQL' if has_dependency?('mysql2') || has_dependency?('mysql')
      databases << 'SQLite' if has_dependency?('sqlite3')
      databases << 'MongoDB' if has_dependency?('mongoid') || has_dependency?('mongoose')
      databases << 'Redis' if has_dependency?('redis')
      
      # Check configuration files
      if has_file?('config/database.yml')
        db_config = safe_load_yaml('config/database.yml')
        if db_config
          adapters = db_config.values.map { |env| env['adapter'] if env.is_a?(Hash) }.compact.uniq
          databases.concat(adapters.map(&:capitalize))
        end
      end
      
      databases.uniq
    end

    def detect_frontend_framework
      return 'React' if react_project?
      return 'Vue.js' if vue_project?
      return 'Angular' if angular_project?
      return 'Svelte' if has_dependency?('svelte')
      return 'Alpine.js' if has_dependency?('alpinejs')
      return 'Stimulus' if has_dependency?('@hotwired/stimulus')
      return 'Hotwire' if has_dependency?('@hotwired/turbo-rails')
      
      nil
    end

    def analyze_project_structure
      structure = {
        monorepo: monorepo?,
        has_src_dir: directory_exists?('src'),
        has_lib_dir: directory_exists?('lib'),
        has_app_dir: directory_exists?('app'),
        has_public_dir: directory_exists?('public'),
        has_config_dir: directory_exists?('config'),
        estimated_size: estimate_project_size
      }
      
      structure
    end

    def analyze_git_info
      return {} unless directory_exists?('.git')
      
      {
        has_git: true,
        has_gitignore: has_file?('.gitignore'),
        has_github_actions: directory_exists?('.github/workflows'),
        has_pre_commit: has_file?('.pre-commit-config.yaml')
      }
    end

    def detect_package_managers
      managers = []
      managers << 'bundler' if has_file?('Gemfile')
      managers << 'npm' if has_file?('package.json')
      managers << 'yarn' if has_file?('yarn.lock')
      managers << 'pnpm' if has_file?('pnpm-lock.yaml')
      managers << 'pip' if has_file?('requirements.txt')
      managers << 'poetry' if has_file?('pyproject.toml')
      managers << 'cargo' if has_file?('Cargo.toml')
      managers
    end

    def detect_ci_cd
      ci_systems = []
      ci_systems << 'GitHub Actions' if directory_exists?('.github/workflows')
      ci_systems << 'GitLab CI' if has_file?('.gitlab-ci.yml')
      ci_systems << 'CircleCI' if has_file?('.circleci/config.yml')
      ci_systems << 'Travis CI' if has_file?('.travis.yml')
      ci_systems << 'Jenkins' if has_file?('Jenkinsfile')
      ci_systems
    end

    def detect_containerization
      containers = []
      containers << 'Docker' if has_file?('Dockerfile')
      containers << 'Docker Compose' if has_file?('docker-compose.yml')
      containers << 'Podman' if has_file?('Containerfile')
      containers
    end

    def recommend_agents
      agents = []
      
      case @analysis_results[:project_type] || detect_project_type
      when 'rails'
        agents = ['backend', 'frontend', 'qa']
        agents << 'ux' if has_files_with_extension?('.erb') || has_files_with_extension?('.slim')
      when 'react', 'vue', 'angular', 'nextjs'
        agents = ['frontend', 'ux', 'qa']
        agents << 'backend' if has_api_routes?
      when 'django', 'flask', 'express'
        agents = ['backend', 'qa']
        agents << 'frontend' if has_templates?
      when 'static_site'
        agents = ['ux', 'frontend']
      when 'ruby_gem', 'npm_package', 'python_package'
        agents = ['backend', 'qa']
      else
        agents = ['general', 'qa']
      end
      
      agents.uniq
    end

    def generate_smart_commands
      commands = {}
      
      # Test commands
      if @analysis_results[:testing_framework]&.include?('RSpec')
        commands[:test] = 'bundle exec rspec'
      elsif @analysis_results[:testing_framework]&.include?('Minitest')
        commands[:test] = 'bundle exec ruby -Itest test/test_helper.rb'
      elsif @analysis_results[:testing_framework]&.include?('Jest')
        commands[:test] = 'npm test'
      elsif @analysis_results[:testing_framework]&.include?('pytest')
        commands[:test] = 'pytest'
      else
        commands[:test] = detect_test_command_from_package_json || 'echo "No test command configured"'
      end
      
      # Lint commands
      commands[:lint] = detect_lint_command
      
      # Build commands
      commands[:build] = detect_build_command
      
      # Start commands
      commands[:start] = detect_start_command
      
      commands
    end

    # Helper methods
    def rails_project?
      has_file?('Gemfile') && (has_dependency?('rails') || has_file?('config/application.rb'))
    end

    def react_project?
      has_dependency?('react')
    end

    def vue_project?
      has_dependency?('vue')
    end

    def angular_project?
      has_dependency?('@angular/core')
    end

    def nextjs_project?
      has_dependency?('next')
    end

    def django_project?
      has_file?('manage.py') && has_files_with_pattern?('*/settings.py')
    end

    def flask_project?
      has_dependency?('flask')
    end

    def express_project?
      has_dependency?('express')
    end

    def ruby_gem?
      has_file?('*.gemspec') || (has_file?('Gemfile') && has_file?('lib/**/*.rb'))
    end

    def npm_package?
      has_file?('package.json') && !has_dependency?('react') && !has_dependency?('vue')
    end

    def python_package?
      has_file?('setup.py') || has_file?('pyproject.toml')
    end

    def static_site?
      has_file?('index.html') && !has_file?('package.json') && !has_file?('Gemfile')
    end

    def monorepo?
      package_json_dirs = Dir.glob(@project_root.join('*/package.json')).size
      gemfile_dirs = Dir.glob(@project_root.join('*/Gemfile')).size
      
      package_json_dirs > 1 || gemfile_dirs > 1
    end

    def has_file?(pattern)
      Dir.glob(@project_root.join(pattern)).any?
    end

    def directory_exists?(path)
      @project_root.join(path).directory?
    end

    def has_files_with_extension?(extension)
      Dir.glob(@project_root.join("**/*#{extension}")).any?
    end

    def has_files_with_pattern?(pattern)
      Dir.glob(@project_root.join(pattern)).any?
    end

    def has_dependency?(gem_or_package)
      # Check Gemfile
      if has_file?('Gemfile')
        gemfile_content = safe_read_file('Gemfile')
        return true if gemfile_content&.include?("'#{gem_or_package}'") || gemfile_content&.include?("\"#{gem_or_package}\"")
      end
      
      # Check package.json
      if has_file?('package.json')
        package_json = safe_load_json('package.json')
        if package_json
          deps = package_json.dig('dependencies') || {}
          dev_deps = package_json.dig('devDependencies') || {}
          return deps.key?(gem_or_package) || dev_deps.key?(gem_or_package)
        end
      end
      
      false
    end

    def has_api_routes?
      # Rails API routes
      return true if has_file?('config/routes.rb') && safe_read_file('config/routes.rb')&.include?('api')
      
      # Express routes
      return true if has_files_with_pattern?('**/routes/**/*.js')
      
      false
    end

    def has_templates?
      has_files_with_extension?('.erb') || 
      has_files_with_extension?('.html') || 
      has_files_with_extension?('.jinja2') ||
      has_files_with_extension?('.ejs')
    end

    def detect_project_name
      # Try package.json first
      if has_file?('package.json')
        package_json = safe_load_json('package.json')
        return package_json['name'] if package_json&.dig('name')
      end
      
      # Try gemspec
      gemspec_files = Dir.glob(@project_root.join('*.gemspec'))
      if gemspec_files.any?
        return File.basename(gemspec_files.first, '.gemspec')
      end
      
      # Fall back to directory name
      @project_root.basename.to_s
    end

    def generate_project_description
      type = @analysis_results[:project_type] || detect_project_type
      stack = @analysis_results[:technology_stack] || []
      
      case type
      when 'rails'
        "Ruby on Rails application with #{stack.join(', ')}"
      when 'react'
        "React application built with #{stack.join(', ')}"
      when 'vue'
        "Vue.js application using #{stack.join(', ')}"
      when 'django'
        "Django web application with #{stack.join(', ')}"
      else
        "Software project using #{stack.join(', ')}"
      end
    end

    def recommend_agent_count
      size = estimate_project_size
      
      case size
      when :small then 2
      when :medium then 3
      when :large then 4
      else 3
      end
    end

    def estimate_project_size
      total_files = Dir.glob(@project_root.join('**/*')).reject { |f| File.directory?(f) }.size
      
      case total_files
      when 0..50 then :small
      when 51..200 then :medium
      when 201..500 then :large
      else :extra_large
      end
    end

    def detect_test_command_from_package_json
      package_json = safe_load_json('package.json')
      package_json&.dig('scripts', 'test')
    end

    def detect_lint_command
      return 'bundle exec rubocop' if has_dependency?('rubocop')
      return 'npm run lint' if has_package_script?('lint')
      return 'eslint .' if has_dependency?('eslint')
      return 'flake8' if has_dependency?('flake8')
      
      'echo "No lint command configured"'
    end

    def detect_build_command
      return 'npm run build' if has_package_script?('build')
      return 'yarn build' if has_file?('yarn.lock') && has_package_script?('build')
      return 'bundle exec rake build' if has_file?('Rakefile')
      
      nil
    end

    def detect_start_command
      if rails_project?
        'bundle exec rails server'
      elsif has_package_script?('start')
        'npm start'
      elsif has_package_script?('dev')
        'npm run dev'
      else
        nil
      end
    end

    def has_package_script?(script_name)
      package_json = safe_load_json('package.json')
      package_json&.dig('scripts', script_name)
    end

    def analyze_readme_quality
      return :none unless has_file?('README.md') || has_file?('README.rst') || has_file?('README.txt')
      
      readme_files = ['README.md', 'README.rst', 'README.txt']
      readme_content = readme_files.map { |f| safe_read_file(f) }.compact.first
      
      return :minimal if !readme_content || readme_content.length < 100
      return :good if readme_content.length > 500
      
      :basic
    end

    def safe_read_file(path)
      full_path = @project_root.join(path)
      return nil unless full_path.file?
      
      full_path.read
    rescue StandardError
      nil
    end

    def safe_load_json(path)
      content = safe_read_file(path)
      return nil unless content
      
      JSON.parse(content)
    rescue JSON::ParserError
      nil
    end

    def safe_load_yaml(path)
      content = safe_read_file(path)
      return nil unless content
      
      YAML.safe_load(content, aliases: true)
    rescue Psych::SyntaxError, Psych::AliasesNotEnabled
      nil
    end
  end
end