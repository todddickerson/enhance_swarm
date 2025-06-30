# 🚀 Production Installation & Test Guide - v2.1.0

## ✅ Quick Test with Published Gem

### 1. Install Latest Version
```bash
# Install the latest version with all critical fixes
gem install enhance_swarm

# Verify version 2.1.0+
enhance-swarm --version
```

### 2. Create Test Project
```bash
# Create fresh Rails app
rails new enhance_test_production && cd enhance_test_production

# Initialize git (required)
git init && git add -A && git commit -m "Initial Rails app"
```

### 3. Run Production Test
```bash
# Test detached orchestration (recommended)
enhance-swarm orchestrate "Create a Contact management system with name, email, phone, company fields and full CRUD operations" --detached

# Monitor progress
enhance-swarm status

# Watch logs
tail -f .enhance_swarm/logs/orchestration.log
```

### 4. Verify Results (2-3 minutes)
```bash
# Check completion
cat .enhance_swarm/logs/orchestration_status.txt
# Should show: COMPLETED

# Verify files created
find . -name "*contact*" -type f | head -10

# Check git commit
git log --oneline -5 | grep "EnhanceSwarm"
```

## 🚅 Bullet Train Test

### 1. Setup Bullet Train Project
```bash
# Clone Bullet Train starter
git clone https://github.com/bullet-train-co/bullet_train.git bt_production_test
cd bt_production_test

# Setup (follow BT docs)
bundle install && yarn install
rails db:create db:migrate db:seed
git add -A && git commit -m "Initial BT setup"
```

### 2. Test with Bullet Train Conventions
```bash
# Run orchestration with BT-specific task
enhance-swarm orchestrate "Create a Project management system using Bullet Train Super Scaffolding with title, description, status, due_date fields" --detached

# Monitor until completion
enhance-swarm status && tail -f .enhance_swarm/logs/orchestration.log
```

### 3. Verify Bullet Train Results
```bash
# Should create files with:
# ✅ Proper BT includes (include Projects::Base)
# ✅ Magic comments (🚅 add associations above)
# ✅ Tailwind CSS styling (NOT Bootstrap)
# ✅ Team-scoped architecture
# ✅ Super Scaffolding patterns

grep -r "include.*Base" app/models/
grep -r "🚅" app/models/
grep -r "bg-white\|text-gray" app/views/
```

## 🎯 Expected Results

### ✅ Success Indicators
- **Status**: `COMPLETED` in 2-3 minutes
- **Files**: 10-15 files created including models, controllers, views, migrations
- **Quality**: Professional validations, responsive UI, comprehensive tests
- **Git**: Automatic commit with descriptive message
- **Styling**: Tailwind CSS for BT, Bootstrap/Tailwind for Rails

### ⚠️ Troubleshooting
```bash
# If orchestration hangs
enhance-swarm status

# Check for errors
cat .enhance_swarm/logs/orchestration.log | grep ERROR

# Verify Claude CLI
claude --version
```

---

## 📋 What's New in v2.1.0

✅ **Detached Mode**: Non-blocking orchestration with `--detached`  
✅ **Status Monitoring**: Real-time progress with `enhance-swarm status`  
✅ **Worktree Merging**: Agents properly merge changes to main project  
✅ **Tailwind Default**: Bullet Train projects use Tailwind CSS automatically  
✅ **Enhanced Prompting**: Mandatory Super Scaffolding for BT projects  
✅ **Timeout Controls**: 120-second timeouts with proper error handling  

**🚀 Ready for production with `gem install enhance_swarm`!**