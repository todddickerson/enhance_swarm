# EnhanceSwarm 🚀

**Production-ready intelligent multi-agent orchestration for Claude with real dev team coordination.**

EnhanceSwarm transforms Claude into a sophisticated development team that works like real developers - with specialized agents for Backend, Frontend, QA, and Integration that collaborate intelligently with minimal overlap.

## ✨ What Makes EnhanceSwarm Different

- **🧠 Intelligent Orchestration**: Control agent delegates tasks to specialized agents like a real project manager
- **🤖 Real Claude CLI Integration**: Spawns authentic Claude agents using your local Claude CLI  
- **👥 Dev Team Simulation**: Backend → Frontend → QA → Integration workflow with smart handoffs
- **🎯 Zero Overlap**: Agents work on specialized tasks with dependency-aware coordination
- **📊 Smart Defaults**: Auto-detects project type and creates optimal team coordination
- **🛡️ Production Ready**: Enterprise security, resource management, and comprehensive testing

## 🚀 Quick Start

### Installation
```bash
gem install enhance_swarm
# Version 2.1.0+ required for critical fixes and detached mode
```

### Initialize in Your Project
```bash
cd your_project
enhance-swarm init
```

### Run Intelligent Multi-Agent Development

**Recommended: Detached Mode (Non-blocking)**
```bash
# Start orchestration in background - returns immediately
enhance-swarm orchestrate "Create a Contact management system with CRUD operations" --detached

# Monitor progress
enhance-swarm status

# Check logs
tail -f .enhance_swarm/logs/orchestration.log
```

**Alternative: Interactive Mode**
```bash
# Or use the enhanced ENHANCE protocol (interactive)
enhance-swarm enhance
# Then enter: "Build a todo management system with real-time updates"

# Standard orchestration (blocking)
enhance-swarm orchestrate "Add user authentication with email verification"
```

## 🎯 How It Works

### Intelligent Task Delegation
1. **Control Agent** analyzes your request and project context
2. **Task Decomposition** breaks complex features into specialized subtasks  
3. **Smart Coordination** assigns tasks to specialist agents with dependencies
4. **Quality Assurance** QA agent reviews each implementation
5. **Integration** Lead agent merges everything seamlessly

### Agent Specialization
| Agent | Role | Responsibilities |
|-------|------|------------------|
| **Backend** | API & Logic Developer | Models, APIs, business logic, database design |
| **Frontend** | UI/UX Developer | Components, styling, user experience, interactions |
| **QA** | Quality Engineer | Testing, validation, security, edge cases |
| **Integration** | Tech Lead | Merging, refining, final polish, deployment prep |

### Smart Coordination Example
```bash
enhance-swarm orchestrate "Add contact management to the app"
```

**Behind the scenes:**
1. 🎯 Control agent creates specialized subtasks
2. 🔧 Backend agent: Creates Contact model, API endpoints, validations  
3. 🎨 Frontend agent: Builds contact forms, list views, search functionality
4. 🧪 QA agent: Creates comprehensive test suites for all features
5. 🔗 Integration agent: Merges everything, resolves conflicts, final polish

## 📋 Command Reference

### Core Commands
```bash
# Intelligent multi-agent orchestration (recommended)
enhance-swarm orchestrate "your feature description"

# Enhanced protocol with smart coordination  
enhance-swarm enhance

# Manual single agent (for specific tasks)
enhance-swarm spawn --role backend "Create user authentication API"

# Monitor all agents in real-time
enhance-swarm dashboard

# Check status and progress
enhance-swarm status
```

### Project Management
```bash
# Initialize smart defaults for your project
enhance-swarm init

# Check system and project configuration
enhance-swarm config

# Validate system setup
enhance-swarm doctor

# Clean up completed work
enhance-swarm cleanup
```

## 📋 Real-World Example

**Task**: "Create a comprehensive Contact management system with name, email, phone, company fields, and full CRUD operations with proper validation and testing"

**What EnhanceSwarm Creates**:
```
📁 Generated Files (14 files, 304 insertions):
├── app/models/contact.rb                 # Model with validations
├── app/controllers/contacts_controller.rb # Full CRUD controller  
├── app/views/contacts/
│   ├── index.html.erb                   # List all contacts
│   ├── show.html.erb                    # View contact details
│   ├── new.html.erb                     # Create new contact
│   ├── edit.html.erb                    # Edit existing contact
│   └── _form.html.erb                   # Shared form partial
├── db/migrate/create_contacts.rb         # Database migration
├── config/routes.rb                     # Updated routes
└── .enhance_swarm/logs/                 # Orchestration logs
```

**Multi-Agent Workflow**:
1. **Backend Agent**: Creates Contact model with validations, database migration
2. **Frontend Agent**: Builds complete view set with Tailwind CSS responsive design
3. **Integration Agent**: Updates routes, ensures everything works together
4. **Auto-commit**: All changes committed to git with proper message

**🎨 Styling Framework**:
- **Bullet Train Projects**: Tailwind CSS (default) - modern utility-first framework
- **Regular Rails Projects**: Bootstrap or Tailwind CSS based on project setup

**Total Time**: ~2 minutes (background execution)

## 🎭 Agent Roles & Specializations

### Backend Agent
**Focus**: Server-side logic, APIs, database design
- Implements secure business logic and data models
- Creates efficient API endpoints with proper validation
- Designs database schemas and migrations
- Follows framework best practices (Rails, Django, etc.)
- Ensures proper error handling and security

### Frontend Agent  
**Focus**: User interfaces, styling, user experience
- Creates intuitive and responsive interfaces
- Maintains consistent design patterns and components
- Implements modern CSS and JavaScript best practices
- Ensures accessibility and cross-browser compatibility
- Integrates seamlessly with backend APIs

### QA Agent
**Focus**: Testing, validation, quality assurance
- Creates comprehensive test suites (unit, integration, system)
- Validates functionality against requirements
- Checks for security vulnerabilities and edge cases
- Provides actionable feedback for improvements
- Ensures code quality and maintainability

### Integration Agent
**Focus**: Merging, coordination, final polish
- Intelligently merges work from all specialist agents
- Resolves conflicts and ensures system cohesion
- Performs final refactoring and optimization
- Validates complete feature functionality
- Prepares implementation for deployment

## 🏗️ Project Type Support

EnhanceSwarm automatically detects your project type and provides specialized coordination:

- **Rails**: Service objects, strong validations, Rails conventions
- **React/Next.js**: Component architecture, hooks, modern patterns  
- **Django**: MVT patterns, Django REST framework, security
- **Vue**: Composition API, Vuex/Pinia, component design
- **And more**: Intelligent defaults for any framework

## 🔧 Configuration

### Smart Defaults
EnhanceSwarm automatically configures itself based on your project:
```yaml
# .enhance_swarm.yml (auto-generated)
orchestration:
  max_concurrent_agents: 4
  coordination_enabled: true
  smart_handoffs: true

agents:
  backend:
    specialization: "APIs, models, business logic"
    best_practices: ["Rails conventions", "Service objects", "Strong validations"]
  frontend:
    specialization: "UI/UX, components, styling"  
    best_practices: ["Responsive design", "Component reuse", "Accessibility"]
```

### Resource Management
```yaml
resources:
  max_memory_mb: 2048
  max_disk_mb: 1024
  max_concurrent_agents: 10
```

## 🛡️ Production Features

### Security
- Command injection protection with comprehensive input sanitization
- Role-based agent validation and secure execution environments
- Automatic vulnerability scanning and security best practices

### Resource Management  
- Intelligent resource limits with automatic cleanup
- Memory, disk, and CPU monitoring per agent
- Graceful degradation when limits are reached

### Quality Assurance
- 100% test coverage for core functionality
- Comprehensive security testing framework
- Production validation and deployment readiness

## 📊 Monitoring & Status

### Check Orchestration Progress
```bash
# Check if orchestration is running
enhance-swarm status

# Monitor logs in real-time
tail -f .enhance_swarm/logs/orchestration.log

# View specific agent output
cat .enhance_swarm/logs/backend_output.log
```

### Understanding Output
```bash
🎯 Starting intelligent multi-agent orchestration
🚀 Orchestration started in detached mode
📁 Check .enhance_swarm/logs/ for progress updates

# Status responses:
📊 Orchestration running (PID: 12345)
Status: RUNNING
✅ Status: COMPLETED  
❌ Status: FAILED: <error message>
```

### Log Structure
```
.enhance_swarm/logs/
├── orchestration.log          # Main orchestration progress
├── orchestration_status.txt   # Current status (RUNNING/COMPLETED/FAILED)
├── orchestration.pid          # Process ID for monitoring
├── backend_output.log         # Backend agent output
├── frontend_output.log        # Frontend agent output
└── general_output.log         # General agent output
```

## 🎯 Real-World Examples

### Add Authentication System
```bash
enhance-swarm orchestrate "Add user authentication with JWT tokens and email verification"
```
**Result**: Complete auth system with backend APIs, frontend forms, email templates, and comprehensive tests.

### Build Todo Management
```bash
enhance-swarm orchestrate "Create todo management with categories, due dates, and real-time updates"
```
**Result**: Full-stack todo system with database models, REST APIs, interactive UI, and real-time features.

### E-commerce Integration
```bash
enhance-swarm orchestrate "Add shopping cart and checkout flow with Stripe integration"
```
**Result**: Complete e-commerce functionality with payment processing, order management, and secure checkout.

## 📊 Monitoring & Debugging

### Real-time Dashboard
```bash
enhance-swarm dashboard
```
- Live agent status and progress
- Resource usage monitoring  
- Task coordination visualization
- Interactive controls and logs

### Status Tracking
```bash
enhance-swarm status
```
- Active agents and their specializations
- Task dependencies and completion status
- Git worktree isolation and branch tracking
- Session management and progress metrics

## 🚦 Troubleshooting

### Common Issues
- **No Claude CLI**: Install from [Claude Code](https://claude.ai/code)
- **Permission Errors**: Ensure git repository is initialized
- **Resource Limits**: Adjust limits in `.enhance_swarm.yml`
- **Agent Conflicts**: Use `enhance-swarm cleanup` to reset state

### Debug Mode
```bash
ENHANCE_SWARM_DEBUG=true enhance-swarm orchestrate "your task"
```

## 📚 Quick Reference

### Essential Commands
```bash
# Setup
gem install enhance_swarm && enhance-swarm init

# Start orchestration (recommended)
enhance-swarm orchestrate "Your task description" --detached

# Monitor progress  
enhance-swarm status
tail -f .enhance_swarm/logs/orchestration.log

# Alternative: Interactive mode
enhance-swarm enhance
```

### Command Options
```bash
--detached          # Run in background (recommended)
--background        # Run with periodic updates
--follow            # Stream live output (blocking)
--coordination      # Enable task coordination (default: true)
```

### Common Tasks
```bash
# Full-stack features
enhance-swarm orchestrate "Create user registration with email verification" --detached

# CRUD systems  
enhance-swarm orchestrate "Build inventory management with categories and search" --detached

# API development
enhance-swarm orchestrate "Add REST API with JWT authentication" --detached

# UI components
enhance-swarm orchestrate "Create responsive dashboard with charts" --detached
```

## 🤝 Contributing

EnhanceSwarm is designed for production use and community contributions:

1. **Report Issues**: [GitHub Issues](https://github.com/todddickerson/enhance_swarm/issues)
2. **Request Features**: Orchestration improvements, new agent types, project support
3. **Submit PRs**: Agent specializations, coordination algorithms, integrations

## 📈 Roadmap

- **v1.1**: Advanced agent communication protocols
- **v1.2**: Visual workflow designer and task dependencies  
- **v1.3**: Custom agent types and specialization training
- **v1.4**: Multi-project coordination and team templates

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

**EnhanceSwarm v1.0** - Transform Claude into your intelligent development team. Built for production, optimized for collaboration, designed for the future of AI-powered development.

🚀 **Ready to revolutionize your development workflow?** `gem install enhance_swarm`