#!/bin/bash

# Start the socks program with the '-auth user:pass' option on a random port
PORT=$(shuf -i 2000-65000 -n 1)
perl socks.pl -p $PORT -auth testuser:testpass &
SOCKS_PID=$!

# Wait for the socks program to start
sleep 1

# Use the random port to curl Google.com through the proxy without authentication
curl -x socks5://localhost:$PORT https://www.google.com
CURL_EXIT_STATUS=$?

# Check the exit status of the curl command and ensure it fails
if [ $CURL_EXIT_STATUS -eq 0 ]; then
  echo "Curl command unexpectedly succeeded without authentication"
  kill $SOCKS_PID
  exit 1
fi

# Use the random port to curl Google.com through the proxy with authentication
curl -x socks5://testuser:testpass@localhost:$PORT https://www.google.com
CURL_EXIT_STATUS=$?

# Check the exit status of the curl command and ensure it succeeds
if [ $CURL_EXIT_STATUS -ne 0 ]; then
  echo "Curl command failed with exit status $CURL_EXIT_STATUS"
  kill $SOCKS_PID
  exit $CURL_EXIT_STATUS
fi

# Stop the socks program after the test
kill $SOCKS_PID
