#!/bin/bash
set -e

# EnhanceSwarm Auto-Setup Script
# This script can be run directly from GitHub to set up EnhanceSwarm in any project

echo "🚀 EnhanceSwarm Auto-Setup"
echo "========================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check dependencies
echo -e "\n${YELLOW}Checking dependencies...${NC}"

check_dependency() {
    if command -v $1 &> /dev/null; then
        echo -e "  ✅ $1 found"
        return 0
    else
        echo -e "  ❌ $1 not found"
        return 1
    fi
}

MISSING_DEPS=0
check_dependency "ruby" || MISSING_DEPS=1
check_dependency "git" || MISSING_DEPS=1
check_dependency "bundle" || MISSING_DEPS=1

if [ $MISSING_DEPS -eq 1 ]; then
    echo -e "\n${RED}Missing required dependencies. Please install them first.${NC}"
    exit 1
fi

# Clone or update enhance_swarm
ENHANCE_DIR="$HOME/.enhance_swarm"

if [ -d "$ENHANCE_DIR" ]; then
    echo -e "\n${YELLOW}Updating EnhanceSwarm...${NC}"
    cd "$ENHANCE_DIR"
    git pull origin main
else
    echo -e "\n${YELLOW}Installing EnhanceSwarm...${NC}"
    git clone https://github.com/todddickerson/enhance_swarm.git "$ENHANCE_DIR"
    cd "$ENHANCE_DIR"
fi

# Install gem dependencies
echo -e "\n${YELLOW}Installing dependencies...${NC}"
bundle install

# Build and install the gem
echo -e "\n${YELLOW}Building and installing gem...${NC}"
rake build
gem install pkg/enhance_swarm-*.gem

# Check optional dependencies
echo -e "\n${YELLOW}Checking optional dependencies...${NC}"
check_dependency "claude-swarm" || echo "  ⚠️  Install claude-swarm for full functionality"
check_dependency "gemini" || echo "  ⚠️  Install Gemini CLI for large context analysis"

# Initialize in current project if we're in a project directory
if [ -f "Gemfile" ] || [ -f "package.json" ] || [ -f ".git/config" ]; then
    echo -e "\n${YELLOW}Detected project directory. Initialize EnhanceSwarm here?${NC}"
    read -p "Initialize EnhanceSwarm in current directory? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        enhance-swarm init
    fi
else
    echo -e "\n${GREEN}✅ EnhanceSwarm installed successfully!${NC}"
    echo -e "\nTo initialize in a project, run:"
    echo -e "  ${YELLOW}cd your-project${NC}"
    echo -e "  ${YELLOW}enhance-swarm init${NC}"
fi

echo -e "\n${GREEN}🎉 Setup complete!${NC}"
echo -e "\nAvailable commands:"
echo "  enhance-swarm init      - Initialize in a project"
echo "  enhance-swarm enhance   - Run ENHANCE protocol"
echo "  enhance-swarm doctor    - Check system setup"
echo "  enhance-swarm --help    - See all commands"