#!/bin/bash

# Iterate over each test script in the tests folder
for test_script in tests/*.sh; do
  # Print what test is running while it's running
  echo "Running $test_script..."
  
  # Execute each test script and check its exit status
  bash "$test_script" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Test $test_script failed."
    exit 1
  fi
done

echo "All tests passed."
