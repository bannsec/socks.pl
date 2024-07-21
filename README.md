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

### Environment Variables

| Variable | Description |
|--------|-------------|
| `SOCKS_PORT` | Specify the port to listen on (default: 1080) |

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

### Using the SOCKS_PORT environment variable

You can also specify the port using the `SOCKS_PORT` environment variable. The precedence rules are as follows:

1. If no command line flag or environment variable is set, the default port (1080) is used.
2. If both the environment variable and the command line flag are set, the command line flag takes precedence.
3. If either the environment variable or the command line flag is set, the specified value is used.

### Examples with SOCKS_PORT environment variable

1. Start a SOCKS listener on port 2020 using the environment variable:
   ```bash
   export SOCKS_PORT=2020
   perl socks.pl
   ```

2. Start a SOCKS listener on port 3030 using the command line flag (overrides the environment variable):
   ```bash
   export SOCKS_PORT=2020
   perl socks.pl -p 3030
   ```

## Authentication

If the `-auth` option is not specified, the server operates as an open SOCKS server without authentication.

## Stopping the Server

To stop the server, use `Ctrl+C` in the terminal where it's running.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
