#!/bin/bash

# Start the socks program on a random port
PORT=$(shuf -i 2000-65000 -n 1)
DEBUG_FILE="debug/test_curl_ip_8_8_8_8_debug.log"
perl socks.pl -p $PORT -d $DEBUG_FILE &
SOCKS_PID=$!

# Wait for the socks program to start
sleep 1

# Use the random port to curl 8.8.8.8 on port 443 through the proxy
curl -x socks5://localhost:$PORT https://8.8.8.8:443
CURL_EXIT_STATUS=$?

# Check the exit status of the curl command
if [ $CURL_EXIT_STATUS -ne 0 ]; then
  echo "Curl command failed with exit status $CURL_EXIT_STATUS"
  kill $SOCKS_PID
  exit $CURL_EXIT_STATUS
fi

# Stop the socks program after the test
kill $SOCKS_PID
