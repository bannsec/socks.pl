use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use POSIX qw(:signal_h);
use Socket qw(inet_aton);

my $debug = 0;

# Add this debug function at the beginning of your script
sub debug_log {
    my ($message) = @_;
    if ($debug) {
        open my $log, '>>', 'socks_debug.log' or die "Could not open log file: $!";
        print $log "$message\n";
        close $log;
    }
}

my $port = 1080;
if (@ARGV && $ARGV[0] eq '-p' && $ARGV[1]) {
    $port = $ARGV[1];
} elsif (@ARGV && $ARGV[0] eq '-h') {
    print_help();
    exit(0);
} elsif (@ARGV && $ARGV[0] eq '-d') {
    $debug = 1;
}

my $server = IO::Socket::INET->new(
    LocalPort => $port,
    Proto     => 'tcp',
    Listen    => SOMAXCONN,
    Reuse     => 1
) or die "Could not create socket: $!\n";

debug_log("SOCKS5 server is running and listening on port $port");

my $select = IO::Select->new($server);

$SIG{INT} = sub {
    debug_log("Shutting down the server...");
    close($server);
    exit(0);
};

while (1) {
    my @ready = $select->can_read;
    foreach my $fh (@ready) {
        if ($fh == $server) {
            my $client = $server->accept;
            $select->add($client);
            debug_log("New client connected");
        } else {
            my $data;
            my $bytes_read = $fh->sysread($data, 1024);
            if ($bytes_read) {
                handle_socks_version($fh, $data, $select);
            } else {
                $select->remove($fh);
                close($fh);
                debug_log("Client disconnected");
            }
        }
    }
}

sub handle_socks_version {
    my ($client, $data, $select) = @_;

    my ($version) = unpack('C', $data);
    debug_log("SOCKS version: $version");

    if ($version == 5) {
        handle_socks5($client, $data, $select);
    } elsif ($version == 4) {
        handle_socks4($client, $data, $select);
    } else {
        debug_log("Unsupported SOCKS version: $version");
        close($client);
    }
}

sub handle_socks5 {
    my ($client, $data, $select) = @_;

    debug_log("Handling SOCKS5 request");
    debug_log("Initial data: " . unpack("H*", $data));

    # Initial SOCKS5 handshake
    my ($version, $nmethods) = unpack('C2', $data);
    debug_log("SOCKS version: $version, Number of methods: $nmethods");

    if ($version != 5) {
        debug_log("Invalid SOCKS version: $version");
        close($client);
        return;
    }

    my @methods = unpack("C$nmethods", substr($data, 2));
    debug_log("Authentication methods: " . join(", ", @methods));

    if (!grep { $_ == 0 } @methods) {
        debug_log("No acceptable authentication method");
        close($client);
        return;
    }

    $client->syswrite(pack('C2', 5, 0));
    debug_log("Sent authentication response");

    # Read SOCKS5 request
    my $bytes_read = $client->sysread($data, 4);
    debug_log("Read $bytes_read bytes for SOCKS5 request");
    debug_log("SOCKS5 request data: " . unpack("H*", $data));

    my ($ver, $cmd, $rsv, $atyp) = unpack('C4', $data);
    debug_log("SOCKS5 request - Version: $ver, Command: $cmd, Reserved: $rsv, Address type: $atyp");

    if ($ver != 5 || $cmd != 1) {
        debug_log("Invalid SOCKS5 request");
        close($client);
        return;
    }

    my $addr;
    eval {
        if ($atyp == 1) {
            debug_log("IPv4 address");
            $bytes_read = $client->sysread($data, 4);
            debug_log("Read $bytes_read bytes for IPv4 address");
            debug_log("IPv4 address data: " . unpack("H*", $data));
            my $ip_packed = $data;
            my $ip = join('.', unpack("C4", $ip_packed));
            debug_log("Unpacked IP: $ip");
            $bytes_read = $client->sysread($data, 2);
            debug_log("Read $bytes_read bytes for port");
            debug_log("Port data: " . unpack("H*", $data));
            my $port = unpack('n', $data);
            debug_log("Unpacked port: $port");
            $addr = "$ip:$port";
        } elsif ($atyp == 3) {
            debug_log("Domain name");
            $bytes_read = $client->sysread($data, 1);
            debug_log("Read $bytes_read byte for domain name length");
            my $len = unpack('C', $data);
            debug_log("Domain name length: $len");
            $bytes_read = $client->sysread($data, $len);
            debug_log("Read $bytes_read bytes for domain name");
            debug_log("Domain name data: " . unpack("H*", $data));
            my $host = unpack("A$len", $data);
            debug_log("Unpacked host: $host");
            $bytes_read = $client->sysread($data, 2);
            debug_log("Read $bytes_read bytes for port");
            debug_log("Port data: " . unpack("H*", $data));
            my $port = unpack('n', $data);
            debug_log("Unpacked port: $port");
            $addr = "$host:$port";
        } else {
            die "Unsupported address type: $atyp";
        }
    };
    if ($@) {
        debug_log("Error processing address: $@");
        close($client);
        return;
    }

    debug_log("Target address: $addr");

    # Connect to target server
    my $target = IO::Socket::INET->new(PeerAddr => $addr, Proto => 'tcp');
    if (!$target) {
        debug_log("Failed to connect to target server");
        $client->syswrite(pack('C4', 5, 5, 0, 1) . pack('Nn', 0, 0));
        close($client);
        return;
    }

    debug_log("Connected to target server");
    
    my $response;
    eval {
        my $ip_addr = inet_aton($target->peerhost);
        my $port = $target->peerport;
        debug_log("Response IP: " . unpack("H*", $ip_addr) . ", Port: $port");
        $response = pack('C4', 5, 0, 0, 1) . $ip_addr . pack('n', $port);
    };
    if ($@) {
        debug_log("Error creating response: $@");
        close($client);
        close($target);
        return;
    }
    
    debug_log("Response to client: " . unpack("H*", $response));
    $client->syswrite($response);

    # Add target to select
    $select->add($target);

    # Relay data between client and target server
    relay_data($client, $target, $select);
}

sub handle_socks4 {
    my ($client, $data, $select) = @_;
    debug_log("Handling SOCKS4 request - Placeholder function");
}

sub relay_data {
    my ($client, $target, $select) = @_;
    debug_log("Starting data relay");
    while (1) {
        my @ready = $select->can_read;
        foreach my $fh (@ready) {
            my $data;
            my $bytes_read = $fh->sysread($data, 1024);
            if ($bytes_read) {
                if ($fh == $client) {
                    $target->syswrite($data);
                    debug_log("Relayed data from client to target");
                } else {
                    $client->syswrite($data);
                    debug_log("Relayed data from target to client");
                }
            } else {
                debug_log("Connection closed");
                $select->remove($client);
                $select->remove($target);
                close($client);
                close($target);
                return;
            }
        }
    }
}

sub print_help {
    print <<'END_HELP';
Usage: perl socks.pl [OPTIONS]
Options:
    -p <port>   Specify the port to listen on (default: 1080)
    -h          Print this help message
    -d          Enable debug logging
END_HELP
}
