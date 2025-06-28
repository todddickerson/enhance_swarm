# EnhanceSwarm with Rails Projects

This example shows how to use EnhanceSwarm with a Rails 8 application.

## Initial Setup

```bash
cd your-rails-app
enhance-swarm init
```

## Customize Configuration

Edit `.enhance_swarm.yml`:

```yaml
project:
  name: "My Rails App"
  description: "E-commerce platform built with Rails 8"
  technology_stack: "Rails 8.0.2, PostgreSQL, Hotwire, ViewComponent"

commands:
  test: "bundle exec rails test"
  task: "bundle exec rails swarm:tasks"
  task_move: "bundle exec rails swarm:tasks:move"

orchestration:
  max_concurrent_agents: 4
  monitor_interval: 30
  monitor_timeout: 120
  worktree_enabled: true

mcp:
  tools:
    context7: true
    sequential: true
    magic_ui: true
    puppeteer: true
  gemini_enabled: true
  desktop_commander_enabled: true

standards:
  code:
    - "Follow Rails conventions"
    - "Use service objects in app/services/"
    - "Use form objects for complex forms"
    - "Keep controllers thin"
    - "Write system tests for features"
    - "Use strong parameters"
    - "Validate all user inputs"
  notes:
    - "Multi-tenant application using acts_as_tenant"
    - "Stripe integration via Pay gem"
    - "ActionMailer with Postmark"
```

## Example Tasks

### Task 1: Add Shopping Cart Feature

Create `tasks/backlog/add-shopping-cart.md`:

```markdown
# Add Shopping Cart Feature

## Description
Implement a shopping cart system that allows users to add products, update quantities, and proceed to checkout.

## Acceptance Criteria
- Users can add products to cart
- Cart persists across sessions
- Users can update quantities
- Users can remove items
- Cart shows total price
- Integration with existing checkout flow

## Technical Requirements
- Cart model with cart_items
- Session-based for guests
- Database-backed for logged-in users
- Hotwire for dynamic updates
- Full test coverage

## Estimated Hours: 8
```

### Running ENHANCE Protocol

In Claude, simply say:
```
enhance
```

Or from command line:
```bash
enhance-swarm enhance
```

This will:
1. Pick up the shopping cart task
2. Spawn 4 specialized agents:
   - **UX Agent**: Designs cart UI components and email templates
   - **Backend Agent**: Creates Cart and CartItem models, services
   - **Frontend Agent**: Implements controllers, views, and Stimulus
   - **QA Agent**: Writes comprehensive system and unit tests

### Monitoring Progress

```bash
# Quick status check
enhance-swarm status

# Watch agents work (2 min max)
enhance-swarm monitor

# See all worktrees
git worktree list
```

### Review and Merge

After agents complete:

```bash
# Check each worktree
cd .worktree_ux_1234
rails test
git log --oneline

cd .worktree_backend_5678
rails test
git diff main

# Merge approved changes
git checkout main
git merge swarm/backend-20240628-143022
git merge swarm/frontend-20240628-143025

# Clean up
git worktree remove .worktree_ux_1234
```

## Advanced Patterns

### Custom Agent for Rails

Add to `.enhance_swarm.yml`:

```yaml
agents:
  rails_migration_expert:
    focus: "Database migrations and schema design"
    trigger_keywords: ["migration", "schema", "index", "foreign key"]
    
  hotwire_specialist:
    focus: "Turbo frames, streams, and Stimulus controllers"
    trigger_keywords: ["turbo", "stimulus", "hotwire", "real-time"]
```

### Pre-flight Checks

Create `.claude/hooks/pre-enhance.rb`:

```ruby
#!/usr/bin/env ruby

# Check database is migrated
unless system("bundle exec rails db:migrate:status | grep -q down")
  puts "✅ Database is up to date"
else
  puts "❌ Pending migrations detected!"
  exit 1
end

# Check tests are passing
unless system("bundle exec rails test")
  puts "❌ Tests must pass before enhancement!"
  exit 1
end

puts "✅ Pre-flight checks passed!"
```

### Task Templates

Create reusable task templates in `tasks/templates/`:

```markdown
# Feature: <%= feature_name %>

## Description
<%= feature_description %>

## User Story
As a <%= user_type %>
I want to <%= user_goal %>
So that <%= user_benefit %>

## Acceptance Criteria
- [ ] <%= criterion_1 %>
- [ ] <%= criterion_2 %>
- [ ] <%= criterion_3 %>

## Technical Requirements
- Models: <%= required_models %>
- Controllers: <%= required_controllers %>
- Services: <%= required_services %>
- Jobs: <%= background_jobs %>

## Testing Requirements
- Unit tests for all models and services
- System tests for user flows
- API tests if applicable

## Estimated Hours: <%= estimate %>
```

## Tips for Rails Projects

1. **Database Migrations**: Agents will create migrations - review them before running
2. **Background Jobs**: Ensure Redis is running if using Sidekiq
3. **Asset Pipeline**: Agents understand Propshaft/Sprockets
4. **Testing**: Agents use Rails testing conventions by default
5. **Multi-tenancy**: Configure tenant switching in test setup

## Troubleshooting

### Gemfile Conflicts
If agents modify Gemfile:
```bash
cd .worktree_backend_1234
bundle install
# Resolve conflicts
git add Gemfile.lock
git commit --amend
```

### Database Issues
Agents create migrations but don't run them:
```bash
# In main branch after merging
bundle exec rails db:migrate
bundle exec rails db:test:prepare
```

### Test Failures
Each agent runs tests in isolation:
```bash
# Check test results in worktree
cd .worktree_qa_5678
bundle exec rails test
# Fix any issues before merging
```