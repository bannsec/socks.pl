# SOCKS Proxy Server Implementation in Perl

## Supported Protocols
This implementation supports the following protocols:
- SOCKS4
- SOCKS5
- SOCKS5h

## Example:
```bash
perl socks.pl -p 1080 # This will start a SOCKS listener on port 1080.
perl socks.pl -h # This will print the help message.
perl socks.pl -d # This will enable debug logging.
perl socks.pl -d debug.log # This will enable debug logging to the specified file.
perl socks.pl -p 1080 -auth user:pass -d # This will start a SOCKS listener on port 1080 with debug logging and authentication.
```

Ctrl-c should be used to kill it.

## Help
To print the help message, use the `-h` flag:
```bash
perl socks.pl -h
```

To enable debug logging, use the `-d` flag:
```bash
perl socks.pl -d
```

To enable debug logging to a specific file, use the `-d` flag followed by the file name:
```bash
perl socks.pl -d debug.log
```

## Authentication
To enable user and password authentication, use the `-auth` flag followed by the `user:pass` credentials:
```bash
perl socks.pl -auth user:pass
```
If the `-auth` option is not specified, the server defaults to an open SOCKS server.

## Multiple Flags Support
You can use multiple flags together. For example, to start the server on port 1080 with debug logging and authentication, use:
```bash
perl socks.pl -p 1080 -d -auth user:pass
```
