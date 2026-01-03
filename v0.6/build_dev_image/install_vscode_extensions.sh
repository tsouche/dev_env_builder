#!/bin/bash
################################################################################
# VS Code Extension Installation Script - v0.5
# Run this script after connecting to the dev container via Remote-SSH
################################################################################

echo "========================================="
echo "Installing VS Code Extensions"
echo "========================================="
echo ""

# List of extensions from devcontainer.json
EXTENSIONS=(
    "rust-lang.rust-analyzer"
    "panicbit.cargo"
    "fill-labs.dependi"
    "tamasfe.even-better-toml"
    "github.copilot"
    "github.copilot-chat"
    "davidanson.vscode-markdownlint"
)

# Check if code command is available
if ! command -v code &> /dev/null; then
    echo "ERROR: 'code' command not found"
    echo ""
    echo "Make sure you're running this script from a VS Code terminal"
    echo "connected to the remote container via Remote-SSH."
    echo ""
    exit 1
fi

# Install each extension
for extension in "${EXTENSIONS[@]}"; do
    echo "Installing: $extension"
    code --install-extension "$extension" --force
done

echo ""
echo "========================================="
echo "Extension Installation Complete"
echo "========================================="
echo ""
echo "Installed extensions:"
for extension in "${EXTENSIONS[@]}"; do
    echo "  ✓ $extension"
done
echo ""
echo "NOTE: You may need to reload VS Code for all extensions to activate."
echo "Press Ctrl+Shift+P and type 'Reload Window'"
echo ""