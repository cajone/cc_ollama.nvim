#!/bin/bash

# setup_part2.sh
# Part 2 of the Automated Setup and Test Script for cc_ollama.nvim plugin.
# Handles process checks, Git operations, Lazy.nvim cache cleaning, and Neovim headless test.

echo "--- Starting setup_part2.sh ---"
echo "--- Current Directory: $(pwd) ---"

# Define paths
PVIM_CONFIG_DIR="$HOME/.config/pvim"
CC_OLLAMA_FORK_DIR="$HOME/git/cc_ollama.nvim"
CC_OLLAMA_TEST_SPEC="$CC_OLLAMA_FORK_DIR/tests/unit/adapters/ollama_adapter_spec.lua"
AUTOMATION_REPORT="$CC_OLLAMA_FORK_DIR/automation_report.txt" # Append to the existing report

# --- 3. Check for running processes (Ollama and mcp-hub) ---
echo "3. Checking for required background processes..." | tee -a "$AUTOMATION_REPORT"

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


# --- 4. Performing Git operations in Source Repository ---
echo "4. Performing Git operations in $CC_OLLAMA_FORK_DIR..." | tee -a "$AUTOMATION_REPORT"
cd "$CC_OLLAMA_FORK_DIR" || { echo "Error: Could not change to $CC_OLLAMA_FORK_DIR. Exiting."; exit 1; }

git add -A # This stages all changes, including the script itself and any other modified/new files
if [ $? -ne 0 ]; then echo "Error: git add failed. Check file paths/permissions." | tee -a "$AUTOMATION_REPORT"; exit 1; fi

CURRENT_COMMIT_MESSAGE="Automated CodeCompanion Ollama Fix & Test Setup $(date +%Y-%m-%d_%H-%M-%S)"
git commit -m "$CURRENT_COMMIT_MESSAGE"
if [ $? -ne 0 ]; then
    echo "Warning: git commit failed (possibly no changes). Attempting to proceed." | tee -a "$AUTOMATION_REPORT"
    if ! git diff-index --quiet HEAD --; then
        echo "   Git commit failed for reasons other than no changes. Please check manually." | tee -a "$AUTOMATION_REPORT"
        exit 1
    fi
fi

git push origin cleanup
if [ $? -ne 0 ]; then echo "Error: git push failed. Check your Git setup." | tee -a "$AUTOMATION_REPORT"; exit 1; fi
echo "   Git operations complete." | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"


# --- 5. Cleaning Lazy.nvim Cache ---
echo "5. Cleaning Lazy.nvim cache (installed plugins)..." | tee -a "$AUTOMATION_REPORT"
rm -rf "$HOME/.local/share/pvim/lazy/cajone_cc_ollama.nvim"
rm -rf "$HOME/.local/share/pvim/lazy/ravitemer_mcphub.nvim"
rm -rf "$HOME/.local/share/pvim/lazy/MeanderingProgrammer_render-markdown.nvim"
rm -rf "$HOME/.local/share/pvim/lazy/nvim-telescope_telescope.nvim" # Added this to clear Telescope cache
echo "   Lazy.nvim cache cleaned." | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

# --- 6. Running Neovim Headless Test ---
echo "6. Running Neovim headless test. This will start and exit Neovim automatically." | tee -a "$AUTOMATION_REPORT"
echo "   Output will be captured below:" | tee -a "$AUTOMATION_REPORT"
echo "--------------------------------------------------" | tee -a "$AUTOMATION_REPORT"
nvim --headless -u "$PVIM_CONFIG_DIR/init.lua" -c "PlenaryBustedFile $CC_OLLAMA_TEST_SPEC" -c "qa!" 2>&1 | tee -a "$AUTOMATION_REPORT"
NVIM_EXIT_CODE=$?
echo "--------------------------------------------------" | tee -a "$AUTOMATION_REPORT"
echo "Neovim headless test completed with exit code: $NVIM_EXIT_CODE" | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

echo "--- Script Finished ---" | tee -a "$AUTOMATION_REPORT"

# --- 7. Provide ls -l output for the test file ---
echo "--- ls -l output for the test spec file ---" | tee -a "$AUTOMATION_REPORT"
ls -l "$CC_OLLAMA_TEST_SPEC" | tee -a "$AUTOMATION_REPORT"
echo "--------------------------------------------------" | tee -a "$AUTOMATION_REPORT"

echo ""
echo "Automated setup and test script has completed."
echo "Please provide the content of the automation report file: $AUTOMATION_REPORT"
echo "You can view its content using: cat $AUTOMATION_REPORT"
echo ""

echo "--- setup_part2.sh Finished ---"

