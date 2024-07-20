# An implementation of socks5 server written in perl

## Example:
```bash
perl socks.pl -p 1080 # This will start socks5 listener on port 1080.
perl socks.pl -h # This will print the help message.
perl socks.pl -d # This will enable debug logging.
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
