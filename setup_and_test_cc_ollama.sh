#!/bin/bash

# setup_and_test_cc_ollama.sh
# Automates the setup, configuration, and testing for cc_ollama.nvim plugin.

echo "--- Starting Automated Setup and Test Script ---"
echo "--- Current Directory: $(pwd) ---"

# Define paths (ADJUSTED: Changed CC_OLLAMA_FORK_DIR to match your repository name)
PVIM_CONFIG_DIR="$HOME/.config/pvim"
CC_OLLAMA_MAIN_CONFIG="$PVIM_CONFIG_DIR/lua/plugins/ai/cc_ollama.lua"
CC_OLLAMA_FORK_DIR="$HOME/git/cc_ollama.nvim" # Corrected this line
CC_OLLAMA_ADAPTER_FILE="$CC_OLLAMA_FORK_DIR/lua/codecompanion/adapters/ollama.lua"
CC_OLLAMA_TEST_SPEC="$CC_OLLAMA_FORK_DIR/tests/unit/adapters/ollama_adapter_spec.lua"
CC_OLLAMA_TEST_HELPERS="$CC_OLLAMA_FORK_DIR/tests/unit/helpers.lua"

# --- 1. Ensure required directories exist ---
echo "1. Ensuring necessary directories exist..."
mkdir -p "$(dirname "$CC_OLLAMA_MAIN_CONFIG")"
mkdir -p "$(dirname "$CC_OLLAMA_ADAPTER_FILE")"
mkdir -p "$(dirname "$CC_OLLAMA_TEST_SPEC")"
mkdir -p "$(dirname "$CC_OLLAMA_TEST_HELPERS")" # For tests/unit/helpers.lua
echo "   Directories checked/created."

# --- 2. Create/Update cc_ollama.lua (Main Neovim Plugin Config) ---
echo "2. Please ensure the content of $CC_OLLAMA_MAIN_CONFIG matches 'cc_ollama_main_config_fixed' Canvas."
echo "   This step requires manual paste as the script cannot directly read Canvas content."

# --- 3. Create/Update ollama.lua (Forked Plugin Adapter) ---
echo "3. Please ensure the content of $CC_OLLAMA_ADAPTER_FILE matches 'ollama_adapter_fixed_source' Canvas."
echo "   This step requires manual paste."

# --- 4. Create/Update ollama_adapter_spec.lua (Unit Test Spec) ---
echo "4. Please ensure the content of $CC_OLLAMA_TEST_SPEC matches 'ollama_adapter_test_code' Canvas."
echo "   This step requires manual paste."

# --- 5. Create/Update helpers.lua (Test Helpers) ---
echo "5. Please ensure the content of $CC_OLLAMA_TEST_HELPERS matches 'test_helpers_file' Canvas."
echo "   This step requires manual paste."

echo ""
echo "--- MANUAL STEP REQUIRED: Please open the files listed above and paste the corresponding content from the Canvases. ---"
echo "--- Press Enter to continue after you have manually updated the files. ---"
read -r -p "Press Enter to continue..."

# --- 6. Git Operations in Source Repository ---
echo "6. Performing Git operations in $CC_OLLAMA_FORK_DIR..."
cd "$CC_OLLAMA_FORK_DIR" || { echo "Error: Could not change to $CC_OLLAMA_FORK_DIR. Exiting."; exit 1; }

# ADDED: Add the script itself to Git before committing
git add "$(basename "$0")" # Add the script file itself
git add lua/codecompanion/adapters/ollama.lua tests/unit/adapters/ollama_adapter_spec.lua tests/unit/helpers.lua
if [ $? -ne 0 ]; then echo "Error: git add failed. Check file paths/permissions."; exit 1; fi

CURRENT_COMMIT_MESSAGE="Automated CodeCompanion Ollama Fix & Test Setup $(date +%Y-%m-%d_%H-%M-%S)"
git commit -m "$CURRENT_COMMIT_MESSAGE"
if [ $? -ne 0 ]; then
    echo "Warning: git commit failed (possibly no changes). Attempting to proceed."
    if ! git status --porcelain | grep -q .; then
        echo "   No changes to commit, skipping commit."
    else
        echo "   Git commit failed for other reasons. Please check manually."
        exit 1
    fi
fi

git push origin cleanup
if [ $? -ne 0 ]; then echo "Error: git push failed. Check your Git setup."; exit 1; fi
echo "   Git operations complete."

# --- 7. Clean Lazy.nvim Cache ---
echo "7. Cleaning Lazy.nvim cache (installed plugins)..."
rm -rf "$HOME/.local/share/pvim/lazy/cajone_cc_ollama.nvim" # Adjusted to match expected Lazy.nvim folder name
rm -rf "$HOME/.local/share/pvim/lazy/ravitemer_mcphub.nvim"
rm -rf "$HOME/.local/share/pvim/lazy/MeanderingProgrammer_render-markdown.nvim"
echo "   Lazy.nvim cache cleaned."

# --- 8. Run Neovim Headless Test ---
echo "8. Running Neovim headless test. This will start and exit Neovim automatically."
echo "   Output will be captured below:"
echo "--------------------------------------------------"
nvim --headless -u "$PVIM_CONFIG_DIR/init.lua" -c "PlenaryBustedFile $CC_OLLAMA_TEST_SPEC" -c "qa!"
NVIM_EXIT_CODE=$?
echo "--------------------------------------------------"
echo "Neovim headless test completed with exit code: $NVIM_EXIT_CODE"

echo "--- Script Finished ---"

# --- 9. Provide ls -l output for the test file ---
echo "--- ls -l output for the test spec file ---"
ls -l "$CC_OLLAMA_TEST_SPEC"
echo "--------------------------------------------------"

