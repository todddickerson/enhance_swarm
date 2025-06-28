# Changelog

All notable changes to EnhanceSwarm will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2024-06-28

### Security
- **CRITICAL**: Fixed command injection vulnerabilities in shell execution
- **CRITICAL**: Replaced unsafe backticks and `system()` calls with secure `Open3.capture3`
- **CRITICAL**: Added comprehensive input sanitization for all configuration values
- Added `CommandExecutor` class with argument escaping and command validation
- Implemented timeout protection against hanging processes
- Added validation patterns to prevent dangerous shell commands

### Quality
- Fixed 602 RuboCop violations (90% reduction from 670 to 68)
- Added comprehensive error handling across all modules
- Implemented proper exception hierarchies with custom error classes
- Added timeout handling and graceful degradation
- Improved code consistency and formatting

### Testing
- Added 30 comprehensive tests covering security-critical components
- Added `CommandExecutor` test suite with security validation
- Added `Configuration` validation tests
- Added `Orchestrator` sanitization tests
- Added RSpec test framework setup

### Changed
- All shell command execution now uses secure `CommandExecutor` class
- Configuration loading includes validation and sanitization
- Error messages are more descriptive and actionable
- Command arguments are properly escaped to prevent injection
- Shell metacharacters are stripped from configuration values

### Fixed
- Command injection vulnerabilities in `orchestrator.rb`, `task_manager.rb`, `mcp_integration.rb`, `generator.rb`
- Unsafe shell interpolation in Git hook generation
- Missing error handling for external command failures
- RuboCop violations for string literals, method complexity, and formatting
- Assignment in condition warnings

## [0.1.0] - 2024-06-28

### Added
- Initial release of EnhanceSwarm
- ENHANCE protocol implementation for multi-agent orchestration
- CLI with commands: init, enhance, spawn, monitor, status, doctor
- Automatic Claude configuration file generation
- Integration with swarm-tasks gem
- MCP tool support (Gemini CLI, Desktop Commander)
- Git hooks for quality control
- Comprehensive project templates
- Auto-setup script for easy installation
- Brief monitoring pattern (2 minutes max)
- Specialized agent roles (UX, Backend, Frontend, QA)
- Token optimization strategies
- ERB-based template system for customization

### Features
- Automatic task breakdown based on content analysis
- Parallel agent spawning with git worktrees
- Background execution with periodic monitoring
- Flexible configuration via .enhance_swarm.yml
- Fallback support for file-based task management
- System dependency checking with doctor command

[0.1.1]: https://github.com/todddickerson/enhance_swarm/releases/tag/v0.1.1
[0.1.0]: https://github.com/todddickerson/enhance_swarm/releases/tag/v0.1.0