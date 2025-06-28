# Changelog

All notable changes to EnhanceSwarm will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/todddickerson/enhance_swarm/releases/tag/v0.1.0