#!/bin/bash
################################################################################
# Alpine Container Test Script - v0.6.3
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
TEST_DIR="/tmp/alpine-test"
SHARED_VOL="/alpine-test"
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
# Step 3: Copy Binary to Shared Volume
################################################################################

echo -e "${YELLOW}[STEP]${NC} Copying binary to shared volume ($SHARED_VOL)..."

cp "$TEST_DIR/$BINARY_NAME" "$SHARED_VOL/$BINARY_NAME"
chmod +x "$SHARED_VOL/$BINARY_NAME"

if [ ! -f "$SHARED_VOL/$BINARY_NAME" ]; then
    echo -e "${RED}[ERROR]${NC} Failed to copy binary to shared volume"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Binary copied to $SHARED_VOL/$BINARY_NAME"

################################################################################
# Step 4: Test on Alpine Container
################################################################################

echo -e "${YELLOW}[STEP]${NC} Testing binary on Alpine Linux container..."
echo ""

# Check if docker CLI is available in the container
if command -v docker &> /dev/null; then
    # Docker CLI available - run the test directly
    echo -e "${CYAN}Executing on Alpine container...${NC}"
    
    OUTPUT=$(docker exec "$ALPINE_CONTAINER" "/test/$BINARY_NAME" 2>&1)
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
            echo "  - Shared volume architecture working correctly"
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
else
    # Docker CLI not available - provide instructions
    echo -e "${CYAN}Binary ready for testing!${NC}"
    echo ""
    echo "The binary has been compiled and copied to the shared volume."
    echo ""
    echo -e "${YELLOW}To test it on the Alpine container:${NC}"
    echo ""
    echo "  From Windows PowerShell:"
    echo "    docker exec $ALPINE_CONTAINER /test/$BINARY_NAME"
    echo ""
    echo "  Or from another terminal with docker access:"
    echo "    docker exec $ALPINE_CONTAINER /test/$BINARY_NAME"
    echo ""
    echo "Expected output:"
    echo "  Test musl-compiled program running on Alpine container: ok"
fi

echo ""
echo -e "${CYAN}Cleanup:${NC}"
echo "  Test files remain in:"
echo "    - $TEST_DIR/"
echo "    - $SHARED_VOL/$BINARY_NAME"
echo ""
echo "  To clean up:"
echo "    rm -rf $TEST_DIR"
echo "    rm $SHARED_VOL/$BINARY_NAME"
echo ""
