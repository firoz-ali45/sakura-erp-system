#!/bin/bash

# Sakura Portal Mobile App - Quick Start Script
# This script will set up the mobile app project quickly

echo "🚀 Sakura Portal Mobile App - Quick Start"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}📦 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if Node.js is installed
check_node() {
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_success "Node.js is installed: $NODE_VERSION"
        return 0
    else
        print_error "Node.js is not installed. Please install Node.js 16+ from https://nodejs.org/"
        return 1
    fi
}

# Check if npm is installed
check_npm() {
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        print_success "npm is installed: $NPM_VERSION"
        return 0
    else
        print_error "npm is not installed. Please install npm."
        return 1
    fi
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    if npm install; then
        print_success "Dependencies installed successfully"
        return 0
    else
        print_error "Failed to install dependencies"
        return 1
    fi
}

# Build the project
build_project() {
    print_status "Building the project..."
    if npm run build; then
        print_success "Project built successfully"
        return 0
    else
        print_error "Failed to build project"
        return 1
    fi
}

# Setup Capacitor
setup_capacitor() {
    print_status "Setting up Capacitor..."
    if npx cap sync; then
        print_success "Capacitor setup completed"
        return 0
    else
        print_error "Failed to setup Capacitor"
        return 1
    fi
}

# Create assets directories
create_assets() {
    print_status "Creating assets directories..."
    mkdir -p assets/icons
    mkdir -p assets/screenshots
    print_success "Assets directories created"
}

# Generate basic icons
generate_icons() {
    print_status "Generating basic app icons..."
    
    # Create a simple SVG icon
    cat > assets/icons/icon-192x192.svg << 'EOF'
<svg width="192" height="192" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#284b44;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#956c2a;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="192" height="192" rx="24" fill="url(#bg)"/>
  <g transform="translate(96,96)">
    <circle cx="0" cy="0" r="48" fill="rgba(255,255,255,0.1)"/>
    <path d="M-20,-20 L20,-20 L20,20 L-20,20 Z" fill="none" stroke="white" stroke-width="4" stroke-linecap="round"/>
    <path d="M-12,-12 L12,-12 L12,12 L-12,12 Z" fill="none" stroke="white" stroke-width="3" stroke-linecap="round"/>
    <path d="M-6,-6 L6,-6 L6,6 L-6,6 Z" fill="white" opacity="0.8"/>
    <circle cx="0" cy="0" r="3" fill="white"/>
  </g>
  <text x="96" y="170" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-size="16" font-weight="bold">Sakura</text>
</svg>
EOF
    
    print_success "Basic icons generated"
}

# Main setup function
main() {
    echo ""
    print_status "Starting Sakura Portal Mobile App setup..."
    echo ""
    
    # Check prerequisites
    if ! check_node || ! check_npm; then
        print_error "Prerequisites not met. Please install Node.js and npm first."
        exit 1
    fi
    
    # Create assets directories
    create_assets
    
    # Generate basic icons
    generate_icons
    
    # Install dependencies
    if ! install_dependencies; then
        exit 1
    fi
    
    # Build project
    if ! build_project; then
        exit 1
    fi
    
    # Setup Capacitor
    if ! setup_capacitor; then
        print_warning "Capacitor setup failed. You may need to install platform-specific tools."
    fi
    
    echo ""
    print_success "Setup completed successfully!"
    echo ""
    echo "🎯 Next steps:"
    echo "1. Update the data source URL in app.js"
    echo "2. Configure your Google Apps Script"
    echo "3. Run 'npm run build android' for Android"
    echo "4. Run 'npm run build ios' for iOS (macOS only)"
    echo "5. Run 'npm run dev' for development"
    echo ""
    echo "📚 Documentation:"
    echo "- README.md - Main documentation"
    echo "- INSTALLATION.md - Installation guide"
    echo "- DEPLOYMENT.md - Deployment guide"
    echo ""
    print_success "Happy coding! 🚀"
}

# Run main function
main "$@"







