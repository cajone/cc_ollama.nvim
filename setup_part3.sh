#!/bin/bash

# setup_part3_test.sh
# Part 3 of the Automated Setup and Test Script for cc_ollama.nvim plugin.
# This script focuses on checking background processes, performing Git operations,
# cleaning Lazy.nvim cache, and running the isolated Neovim headless test.

echo "--- Starting setup_part3_test.sh (Part 3: Process Checks, Git, & Headless Test) ---"
echo "--- Current Directory: $(pwd) ---"

# Define paths
CC_OLLAMA_FORK_DIR="$HOME/git/cc_ollama.nvim"
AUTOMATION_REPORT="$CC_OLLAMA_FORK_DIR/automation_report.txt"

# Retrieve the temporary Neovim root path from the file created by setup_part1.sh
TEMP_NVIM_ROOT=$(cat "$CC_OLLAMA_FORK_DIR/.temp_nvim_root_path")
TEMP_NVIM_CONFIG_DIR="$TEMP_NVIM_ROOT/nvim"
TEMP_NVIM_DATA_DIR="$TEMP_NVIM_ROOT/nvim_data" # Ensure data dir is used for Lazy.nvim cleanup

# Paths to files within the cc_ollama.nvim fork (needed for test execution)
CC_OLLAMA_TEST_SPEC="$CC_OLLAMA_FORK_DIR/tests/unit/adapters/ollama_adapter_spec.lua"

# --- 1. Check for required background processes (Ollama and mcp-hub) ---
echo "1. Checking for required background processes..." | tee -a "$AUTOMATION_REPORT"

check_process_port() {
    local port_num="$1"
    local process_name="$2"
    echo "   Checking if $process_name is running on port $port_num..." | tee -a "$AUTOMATION_REPORT"
    if lsof -i :"$port_num" -sTCP:LISTEN -n -P > /dev/null; then
        echo "   $process_name is RUNNING." | tee -a "$AUTOMATION_REPORT"
        return 0 # Success
    else
        echo "   $process_name is NOT RUNNING on port $port_num." | tee -a "$AUTOMATION_REPORT"
        return 1 # Failure
    fi
}

wait_for_process() {
    local port_num="$1"
    local process_name="$2"
    while ! check_process_port "$port_num" "$process_name"; do
        read -r -p "   Please start '$process_name' (e.g., '$process_name serve' or 'mcp-hub ...'). Press Enter when ready to re-check... " | tee -a "$AUTOMATION_REPORT"
    done
}

wait_for_process 11434 "ollama"
wait_for_process 4000 "mcp-hub"

echo "   All required processes are running." | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"


# --- 2. Performing Git operations in Source Repository ---
echo "2. Performing Git operations in $CC_OLLAMA_FORK_DIR..." | tee -a "$AUTOMATION_REPORT"
cd "$CC_OLLAMA_FORK_DIR" || { echo "Error: Could not change to $CC_OLLAMA_FORK_DIR. Exiting."; exit 1; }

# Stage all changes (new files, modified files)
git add -A
if [ $? -ne 0 ]; then echo "Error: git add failed. Check file paths/permissions." | tee -a "$AUTOMATION_REPORT"; exit 1; fi

CURRENT_COMMIT_MESSAGE="Automated CodeCompanion Ollama Test Setup & Fix $(date +%Y-%m-%d_%H-%M-%S)"
git commit -m "$CURRENT_COMMIT_MESSAGE"
if [ $? -ne 0 ]; then
    # If commit failed, check if it was due to no changes
    echo "Warning: git commit failed (possibly no changes). Attempting to proceed." | tee -a "$AUTOMATION_REPORT"
    if ! git diff-index --quiet HEAD --; then
        echo "   Git commit failed for reasons other than no changes. Please check manually." | tee -a "$AUTOMATION_REPORT"
        exit 1
    fi
fi

# Push changes to the 'cleanup' branch
git push origin cleanup
if [ $? -ne 0 ]; then echo "Error: git push failed. Check your Git setup." | tee -a "$AUTOMATION_REPORT"; exit 1; fi
echo "   Git operations complete." | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"


# --- 3. Clean Lazy.nvim Cache ---
echo "3. Cleaning Lazy.nvim cache (installed plugins) for isolated test environment..." | tee -a "$AUTOMATION_REPORT"
# The `root` directory for Lazy.nvim in `TEMP_INIT_LUA` is configured to be
# "$TEMP_NVIM_DATA_DIR/lazy". We need to clear this directory to ensure a fresh install.
rm -rf "$TEMP_NVIM_DATA_DIR/lazy"
echo "   Lazy.nvim isolated cache cleaned at $TEMP_NVIM_DATA_DIR/lazy." | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

# --- 4. Run Neovim Headless Test ---
echo "4. Running Neovim headless test. This will start and exit Neovim automatically." | tee -a "$AUTOMATION_REPORT"
echo "   Output will be captured below:" | tee -a "$AUTOMATION_REPORT"
echo "--------------------------------------------------" | tee -a "$AUTOMATION_REPORT"

# Crucially, tell nvim to use the *temporary* init.lua and *temporary* data dir
# The -u flag specifies the init.lua, and the --cmd "set rtp..." ensures the correct runtimepath
# for the isolated environment, including the temporary data directory.
# The `NVIM_APPNAME` environment variable isolates the data directory completely.
NVIM_APPNAME="isolated_nvim_test_$(date +%s)_run" nvim --headless -u "$TEMP_NVIM_CONFIG_DIR/init.lua" \
    --cmd "set rtp+=$TEMP_NVIM_DATA_DIR/lazy/lazy.nvim" \
    --cmd "set runtimepath+=$TEMP_NVIM_ROOT" \
    -c "PlenaryBustedFile $CC_OLLAMA_TEST_SPEC" -c "qa!" 2>&1 | tee -a "$AUTOMATION_REPORT"
NVIM_EXIT_CODE=$?
echo "--------------------------------------------------" | tee -a "$AUTOMATION_REPORT"
echo "Neovim headless test completed with exit code: $NVIM_EXIT_CODE" | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

echo "--- Script Finished ---" | tee -a "$AUTOMATION_REPORT"

# --- 5. Provide ls -l output for the test file ---
echo "--- ls -l output for the test spec file ---" | tee -a "$AUTOMATION_REPORT"
ls -l "$CC_OLLAMA_TEST_SPEC" | tee -a "$AUTOMATION_REPORT"
echo "--------------------------------------------------" | tee -a "$AUTOMATION_REPORT"

echo ""
echo "Automated setup and test script has completed. Please review the output."
echo "You can view the full report using: cat $AUTOMATION_REPORT"
echo "Don't forget to delete the temporary directory: rm -rf $TEMP_NVIM_ROOT"
echo ""

exit $NVIM_EXIT_CODE
