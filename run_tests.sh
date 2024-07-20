#!/bin/bash

# Create the debug directory if it doesn't exist
DEBUG_DIR="debug"
mkdir -p $DEBUG_DIR

# Iterate over each test script in the tests folder
for test_script in tests/*.sh; do
  # Print what test is running while it's running
  echo "Running $test_script..."
  
  # Set the debug file for the current test script
  DEBUG_FILE="$DEBUG_DIR/$(basename $test_script .sh)_debug.log"
  
  # Execute each test script and check its exit status
  DEBUG_FILE=$DEBUG_FILE bash "$test_script" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Test $test_script failed."
    exit 1
  fi
done

echo "All tests passed."
