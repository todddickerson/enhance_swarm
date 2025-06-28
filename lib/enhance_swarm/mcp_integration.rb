# frozen_string_literal: true

module EnhanceSwarm
  class MCPIntegration
    def initialize
      @config = EnhanceSwarm.configuration
    end

    def gemini_available?
      @config.gemini_enabled && system('which gemini > /dev/null 2>&1')
    end

    def desktop_commander_available?
      @config.desktop_commander_enabled
    end

    def analyze_with_gemini(path, prompt)
      return nil unless gemini_available?

      full_prompt = "@#{path} #{prompt}"
      output = `gemini -p "#{full_prompt}" 2>/dev/null`

      output.empty? ? nil : output
    end

    def setup_gemini
      return if gemini_available?

      puts <<~SETUP

        🔧 Gemini CLI Setup Required:

        1. Install Gemini CLI (if not installed)
        2. Run: gemini auth login
        3. Choose Google auth
        4. Verify: gemini -p "test"

        Gemini provides large context analysis capabilities.
      SETUP
    end

    def setup_desktop_commander
      puts <<~SETUP

        🔧 Desktop Commander MCP Setup:

        Desktop Commander allows file operations outside the project directory.
        Configure in your Claude Desktop settings.

        Benefits:
        - Access global configuration files
        - Move files between projects
        - System-wide operations
      SETUP
    end

    def generate_mcp_settings
      settings = {
        'mcpServers' => {}
      }

      if @config.desktop_commander_enabled
        settings['mcpServers']['desktop-commander'] = {
          'command' => 'npx',
          'args' => ['-y', '@claude-ai/desktop-commander'],
          'env' => {}
        }
      end

      settings
    end

    private

    def sanitize_path(path)
      # Only allow safe path characters
      path.to_s.gsub(%r{[^a-zA-Z0-9_\-/.]}, '')
    end

    def sanitize_prompt(prompt)
      # Remove potentially dangerous characters while preserving readability
      prompt.to_s.gsub(/[`$\\]/, '').strip
    end
  end
end
