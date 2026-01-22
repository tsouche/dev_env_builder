#!/bin/bash
################################################################################
# Alpine Container Test Script - v0.6.5
# Run from inside dev container to test musl cross-compilation
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ALPINE_CONTAINER="dev-alpine-test"
TEST_DIR="$HOME/.alpine-test"
BINARY_NAME="alpine_test"

echo ""
echo "========================================"
echo "Alpine Container Musl Binary Test"
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
    println!("Test musl-compiled program running on Alpine container: ok");
}
EOF

if [ ! -f "$TEST_DIR/main.rs" ]; then
    echo -e "${RED}[ERROR]${NC} Failed to create test program"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Test program created at $TEST_DIR/main.rs"

################################################################################
# Step 2: Compile for musl Target
################################################################################

echo -e "${YELLOW}[STEP]${NC} Compiling for x86_64-unknown-linux-musl target..."

# Source Cargo environment if needed (for SSH non-interactive shells)
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

cd "$TEST_DIR"
if ! rustc --target x86_64-unknown-linux-musl main.rs -o "$BINARY_NAME" 2>&1; then
    echo -e "${RED}[ERROR]${NC} Compilation failed"
    exit 1
fi

if [ ! -f "$TEST_DIR/$BINARY_NAME" ]; then
    echo -e "${RED}[ERROR]${NC} Binary not found after compilation"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Binary compiled successfully"

################################################################################
# Step 3: Copy Binary to Alpine Container
################################################################################

echo -e "${YELLOW}[STEP]${NC} Copying binary to Alpine container..."

# Check if docker CLI is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Docker CLI not available inside this container"
    echo "This script requires Docker CLI to be installed in the base image"
    exit 1
fi

# Copy binary to Alpine container using docker cp
if ! docker cp "$TEST_DIR/$BINARY_NAME" "$ALPINE_CONTAINER:/tmp/$BINARY_NAME" 2>&1; then
    echo -e "${RED}[ERROR]${NC} Failed to copy binary to Alpine container"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Binary copied to Alpine container at /tmp/$BINARY_NAME"

################################################################################
# Step 4: Execute Binary on Alpine Container
################################################################################

echo -e "${YELLOW}[STEP]${NC} Testing binary on Alpine Linux container..."
echo ""

echo -e "${CYAN}Executing on Alpine container...${NC}"

OUTPUT=$(docker exec "$ALPINE_CONTAINER" "/tmp/$BINARY_NAME" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${CYAN}Output from Alpine container:${NC}"
    echo "  $OUTPUT"
    echo ""
    
    EXPECTED="Test musl-compiled program running on Alpine container: ok"
    if [[ "$OUTPUT" == *"$EXPECTED"* ]]; then
        echo -e "${GREEN}[OK]${NC} Output verification passed!"
        echo ""
        echo "========================================"
        echo -e "${GREEN}Alpine Container Test: SUCCESS${NC}"
        echo "========================================"
        echo ""
        echo "Summary:"
        echo "  - Rust program created and compiled with musl target"
        echo "  - Binary successfully executed on Alpine Linux 3.19"
        echo "  - Docker CLI working correctly inside dev container"
        echo ""
        echo "The musl cross-compilation toolchain is functioning properly!"
    else
        echo -e "${RED}[ERROR]${NC} Output verification failed"
        echo "Expected: $EXPECTED"
        echo "Got: $OUTPUT"
        exit 1
    fi
else
    echo -e "${RED}[ERROR]${NC} Binary execution failed on Alpine"
    echo "$OUTPUT"
    exit 1
fi

echo ""
echo -e "${CYAN}Test files location:${NC}"
echo "  - Source: $TEST_DIR/"
echo "  - Binary: $TEST_DIR/$BINARY_NAME"
echo ""
echo -e "${CYAN}Cleanup:${NC}"
echo "  rm -rf $TEST_DIR"
echo "  docker exec $ALPINE_CONTAINER rm /tmp/$BINARY_NAME"
echo ""
