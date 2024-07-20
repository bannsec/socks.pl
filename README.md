# SOCKS Proxy Server Implementation in Perl

This is a Perl implementation of a SOCKS proxy server supporting SOCKS4, SOCKS5, and SOCKS5h protocols.

## Features

- Supports SOCKS4, SOCKS5, and SOCKS5h protocols
- Optional user/password authentication
- Configurable port
- Debug logging (to console or file)

## Usage

Basic usage:

```bash
perl socks.pl [options]
```

### Options

| Option | Description |
|--------|-------------|
| `-p <port>` | Specify the port to listen on (default: 1080) |
| `-auth <user:pass>` | Enable authentication with specified credentials |
| `-d [file]` | Enable debug logging (optionally to a file) |
| `-h` | Display help message |

### Examples

1. Start a SOCKS listener on default port (1080):
   ```bash
   perl socks.pl
   ```

2. Start a SOCKS listener on port 2020:
   ```bash
   perl socks.pl -p 2020
   ```

3. Enable debug logging to console:
   ```bash
   perl socks.pl -d
   ```

4. Enable debug logging to a file:
   ```bash
   perl socks.pl -d debug.log
   ```

5. Start with authentication:
   ```bash
   perl socks.pl -auth user:pass
   ```

6. Combine multiple options:
   ```bash
   perl socks.pl -p 1080 -auth user:pass -d
   ```

## Authentication

If the `-auth` option is not specified, the server operates as an open SOCKS server without authentication.

## Stopping the Server

To stop the server, use `Ctrl+C` in the terminal where it's running.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
