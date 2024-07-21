#!/bin/bash

# Test default port (1080) when no environment variable or command line flag is set
DEBUG_FILE="debug/test_socks_port_env_default_debug.log"
perl socks.pl -d $DEBUG_FILE &
SOCKS_PID=$!
sleep 1
curl -x socks5://localhost:1080 https://www.google.com
CURL_EXIT_STATUS=$?
if [ $CURL_EXIT_STATUS -ne 0 ]; then
  echo "Curl command failed with exit status $CURL_EXIT_STATUS"
  kill $SOCKS_PID
  exit $CURL_EXIT_STATUS
fi
kill $SOCKS_PID

# Test port from environment variable
export SOCKS_PORT=2020
DEBUG_FILE="debug/test_socks_port_env_envvar_debug.log"
perl socks.pl -d $DEBUG_FILE &
SOCKS_PID=$!
sleep 1
curl -x socks5://localhost:2020 https://www.google.com
CURL_EXIT_STATUS=$?
if [ $CURL_EXIT_STATUS -ne 0 ]; then
  echo "Curl command failed with exit status $CURL_EXIT_STATUS"
  kill $SOCKS_PID
  exit $CURL_EXIT_STATUS
fi
kill $SOCKS_PID
unset SOCKS_PORT

# Test port from command line flag (overrides environment variable)
export SOCKS_PORT=2020
DEBUG_FILE="debug/test_socks_port_env_cmdline_debug.log"
perl socks.pl -p 3030 -d $DEBUG_FILE &
SOCKS_PID=$!
sleep 1
curl -x socks5://localhost:3030 https://www.google.com
CURL_EXIT_STATUS=$?
if [ $CURL_EXIT_STATUS -ne 0 ]; then
  echo "Curl command failed with exit status $CURL_EXIT_STATUS"
  kill $SOCKS_PID
  exit $CURL_EXIT_STATUS
fi
kill $SOCKS_PID
unset SOCKS_PORT
