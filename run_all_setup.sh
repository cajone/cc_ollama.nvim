#!/bin/bash

# run_all_setup.sh
# Wrapper script to run the two parts of the CodeCompanion Ollama setup and test script.

echo "--- Starting Wrapper Script ---"

# Ensure both parts are executable
chmod +x ./setup_part1.sh
chmod +x ./setup_part2.sh

# Run Part 1
echo "Running setup_part1.sh..."
./setup_part1.sh
PART1_EXIT_CODE=$?

if [ $PART1_EXIT_CODE -ne 0 ]; then
    echo "ERROR: setup_part1.sh failed with exit code $PART1_EXIT_CODE. Aborting."
    exit $PART1_EXIT_CODE
fi
echo "setup_part1.sh completed successfully."

# Run Part 2
echo "Running setup_part2.sh..."
./setup_part2.sh
PART2_EXIT_CODE=$?

if [ $PART2_EXIT_CODE -ne 0 ]; then
    echo "ERROR: setup_part2.sh failed with exit code $PART2_EXIT_CODE."
    exit $PART2_EXIT_CODE
fi
echo "setup_part2.sh completed successfully."

echo "--- All setup and tests completed. ---"

