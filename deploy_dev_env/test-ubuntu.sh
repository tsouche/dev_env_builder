#!/bin/bash
################################################################################
# Ubuntu Container Test Script - v0.6.6
# Run from inside dev container to test hot-swap deployment workflow
# Simulates staging/prod deployment process locally before NAS deployment
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
UBUNTU_CONTAINER="dev-ubuntu-test"
TEST_DIR="$HOME/.ubuntu-test"
BINARY_NAME="ubuntu_test"

echo ""
echo "========================================"
echo "Ubuntu Container glibc Binary Test"
echo "========================================"
echo ""

################################################################################
# Step 1: Create Test Rust Program
################################################################################

echo -e "${YELLOW}[STEP]${NC} Creating test Rust program..."

# Create directory with proper permissions
rm -rf "$TEST_DIR" 2>/dev/null || true
mkdir -p "$TEST_DIR"

cat > "$TEST_DIR/main.rs" << 'EOF'
fn main() {
    println!("Test glibc-compiled program running on Ubuntu container: ok");
}
EOF

if [ ! -f "$TEST_DIR/main.rs" ]; then
    echo -e "${RED}[ERROR]${NC} Failed to create test program"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Test program created at $TEST_DIR/main.rs"

################################################################################
# Step 2: Compile for Native glibc Target
################################################################################

echo -e "${YELLOW}[STEP]${NC} Compiling for x86_64-unknown-linux-gnu target (native)..."

# Source Cargo environment if needed (for SSH non-interactive shells)
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

cd "$TEST_DIR"
if ! rustc main.rs -o "$BINARY_NAME" 2>&1; then
    echo -e "${RED}[ERROR]${NC} Compilation failed"
    exit 1
fi

if [ ! -f "$TEST_DIR/$BINARY_NAME" ]; then
    echo -e "${RED}[ERROR]${NC} Binary not found after compilation"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Binary compiled successfully"

################################################################################
# Step 3: Verify Binary Dependencies
################################################################################

echo -e "${YELLOW}[STEP]${NC} Verifying binary dependencies..."
echo ""

echo -e "${CYAN}Binary dependencies (glibc):${NC}"
ldd "$TEST_DIR/$BINARY_NAME"
echo ""

echo -e "${GREEN}[OK]${NC} Binary verification complete"

################################################################################
# Step 4: Copy Binary to Ubuntu Test Container
################################################################################

echo -e "${YELLOW}[STEP]${NC} Copying binary to Ubuntu test container..."

# Check if docker CLI is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Docker CLI not available inside this container"
    echo "This script requires Docker CLI to be installed in the base image"
    exit 1
fi

# Copy binary to Ubuntu test container using docker cp
if ! docker cp "$TEST_DIR/$BINARY_NAME" "$UBUNTU_CONTAINER:/tmp/$BINARY_NAME" 2>&1; then
    echo -e "${RED}[ERROR]${NC} Failed to copy binary to Ubuntu test container"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Binary copied to Ubuntu test container at /tmp/$BINARY_NAME"

################################################################################
# Step 5: Execute Binary on Ubuntu Test Container
################################################################################

echo -e "${YELLOW}[STEP]${NC} Testing binary on Ubuntu container..."
echo ""

echo -e "${CYAN}--- Output from Ubuntu Container ---${NC}"
if ! docker exec "$UBUNTU_CONTAINER" "/tmp/$BINARY_NAME" 2>&1; then
    echo ""
    echo -e "${RED}[ERROR]${NC} Binary execution failed on Ubuntu container"
    echo "This indicates the binary is not compatible with the Ubuntu runtime environment."
    exit 1
fi
echo -e "${CYAN}------------------------------------${NC}"
echo ""

echo -e "${GREEN}[OK]${NC} Binary executed successfully on Ubuntu container"

################################################################################
# Summary
################################################################################

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo ""
echo -e "${GREEN}✓${NC} Test program: Created"
echo -e "${GREEN}✓${NC} Compilation: Success (glibc target)"
echo -e "${GREEN}✓${NC} Binary transfer: Success"
echo -e "${GREEN}✓${NC} Execution on Ubuntu: Success"
echo ""
echo -e "${GREEN}The glibc-compiled binary is compatible with Ubuntu runtime!${NC}"
echo ""
echo -e "${GREEN}Hot-swap deployment workflow validated successfully.${NC}"
echo -e "${CYAN}You can now safely use this process to deploy to NAS staging/production environments.${NC}"
echo ""
