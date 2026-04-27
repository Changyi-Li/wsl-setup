#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}==> $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warn() { echo -e "${YELLOW}! $*${NC}"; }
error() { echo -e "${RED}✗ $*${NC}"; }

update_apt() {
    info "Updating apt package index..."
    sudo apt update
    success "Apt package index updated"
}

install_unzip() {
    if command -v unzip >/dev/null 2>&1; then
        success "unzip is already installed"
    else
        info "Installing unzip..."
        sudo apt install unzip -y
        success "unzip installed"
    fi
}

install_node() {
    info "Setting up nvm and Node.js..."
    export NVM_DIR="$HOME/.nvm"
    if [ ! -d "$NVM_DIR" ]; then
        info "Installing nvm v0.40.3..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        success "nvm v0.40.3 installed"
    else
        success "nvm is already installed"
    fi

    # Load nvm for the current session
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if nvm ls 24 >/dev/null 2>&1; then
        success "Node.js 24 is already installed"
    else
        info "Installing Node.js 24..."
        nvm install 24
        success "Node.js 24 installed"
    fi
}

install_bun() {
    if command -v bun >/dev/null 2>&1; then
        success "Bun is already installed"
    else
        info "Installing Bun..."
        curl -fsSL https://bun.com/install | bash
        success "Bun installed"
    fi
}

install_opencode() {
    # Ensure Bun is in PATH for this session
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"

    if command -v opencode >/dev/null 2>&1; then
        success "OpenCode is already installed"
    else
        echo -n "OpenCode is not installed. Do you want to install it? (y/N): "
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            info "Installing OpenCode..."
            bun install -g opencode-ai
            success "OpenCode installed"
        else
            info "Skipping OpenCode installation"
            return 0
        fi
    fi

    CONFIG_DIR="$HOME/.config/opencode"
    CONFIG_FILE="$CONFIG_DIR/opencode.json"

    if [ ! -f "$CONFIG_FILE" ]; then
        info "Creating default OpenCode configuration..."
        mkdir -p "$CONFIG_DIR"
        echo '{"$schema": "https://opencode.ai/config.json", "plugin": []}' > "$CONFIG_FILE"
        success "OpenCode configuration created at $CONFIG_FILE"
    else
        success "OpenCode configuration already exists"
    fi

    echo -n "Do you want to install oh-my-openagent? (y/N): "
    read -r oh_my_response
    if [[ "$oh_my_response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        info "Installing oh-my-openagent..."
        
        if command -v bun >/dev/null 2>&1; then
            bunx oh-my-opencode install --no-tui --claude=no --gemini=no --copilot=yes --openai=no --opencode-go=no --opencode-zen=no --zai-coding-plan=yes --kimi-for-coding=no --vercel-ai-gateway=no --skip-auth
            success "oh-my-openagent installed"

            echo -n "Do you want to override oh-my-openagent default config? (Y/n): "
            read -r override_response
            if [[ -z "$override_response" || "$override_response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                info "Overriding oh-my-openagent configuration..."
                cp "$(dirname "$0")/oh-my-openagent/oh-my-openagent.json" "$CONFIG_DIR/oh-my-openagent.json"
                success "oh-my-openagent configuration overridden"
            fi
        else
            error "Bun is not installed. Cannot install oh-my-openagent."
        fi
    fi
}

verify_installation() {
    info "Verifying installation..."
    
    # Reload environment
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    # Ensure commands are available in current subshell
    if ! command -v node >/dev/null 2>&1 || ! command -v bun >/dev/null 2>&1; then
        warn "Some tools might not be in the current path. Please restart your terminal or run: source ~/.bashrc"
        return
    fi

    echo ""
    printf "  %-10s %-20s\n" "Tool" "Version"
    printf "  %-10s %-20s\n" "----" "-------"
    printf "  %-10s %-20s\n" "node" "$(node -v)"
    printf "  %-10s %-20s\n" "npm" "v$(npm -v)"
    printf "  %-10s %-20s\n" "bun" "$(bun -v)"
    if command -v opencode >/dev/null 2>&1; then
        printf "  %-10s %-20s\n" "opencode" "$(opencode --version)"
    fi
    echo ""
}

main() {
    update_apt
    install_unzip
    install_node
    install_bun
    install_opencode
    verify_installation
    success "Setup complete!"
}

main "$@"
