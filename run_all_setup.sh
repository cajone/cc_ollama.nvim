#!/bin/bash

# run_all_setup.sh
# This script orchestrates the execution of the refactored setup and test process
# for the cc_ollama.nvim plugin. It calls each part of the setup in order.

echo "--- Starting run_all_setup.sh (The Master Script) ---"
echo "--- Current Directory: $(pwd) ---"

# Define the automation report file path
CC_OLLAMA_FORK_DIR="$HOME/git/cc_ollama.nvim"
AUTOMATION_REPORT="$CC_OLLAMA_FORK_DIR/automation_report.txt"

# Clear the overall automation report at the beginning of the run
> "$AUTOMATION_REPORT"

# Execute Part 1: Directory Setup & Minimal Init.lua
echo "" | tee -a "$AUTOMATION_REPORT"
echo "Running setup_part1.sh..." | tee -a "$AUTOMATION_REPORT"
./setup_part1.sh | tee -a "$AUTOMATION_REPORT"
if [ $? -ne 0 ]; then
    echo "ERROR: setup_part1.sh failed. Aborting." | tee -a "$AUTOMATION_REPORT"
    exit 1
fi

# Execute Part 2: Write & Verify Lua Plugin Files
echo "" | tee -a "$AUTOMATION_REPORT"
echo "Running setup_part2.sh..." | tee -a "$AUTOMATION_REPORT"
./setup_part2.sh | tee -a "$AUTOMATION_REPORT"
if [ $? -ne 0 ]; then
    echo "ERROR: setup_part2.sh failed. Aborting." | tee -a "$AUTOMATION_REPORT"
    exit 1
fi

# Execute Part 3: Process Checks, Git, & Headless Test
echo "" | tee -a "$AUTOMATION_REPORT"
echo "Running setup_part3.sh..." | tee -a "$AUTOMATION_REPORT"
./setup_part3.sh | tee -a "$AUTOMATION_REPORT"
if [ $? -ne 0 ]; then
    echo "ERROR: setup_part3.sh failed. Please review the errors in the report." | tee -a "$AUTOMATION_REPORT"
    exit 1
fi

echo "" | tee -a "$AUTOMATION_REPORT"
echo "--- Automated Setup and Test Script Finished Successfully! ---" | tee -a "$AUTOMATION_REPORT"
echo "Full automation report can be found at: $AUTOMATION_REPORT"
echo ""

exit 0
