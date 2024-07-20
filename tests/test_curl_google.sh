#!/bin/bash

# Start the socks program on a random port
PORT=$(shuf -i 2000-65000 -n 1)
perl socks.pl -p $PORT &
SOCKS_PID=$!

# Wait for the socks program to start
sleep 2

# Use the random port to curl Google.com through the proxy
curl -x socks5h://localhost:$PORT https://www.google.com

# Stop the socks program after the test
kill $SOCKS_PID
