use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use POSIX qw(:signal_h);
use Socket qw(inet_aton);

my $debug = 0;
my $debug_file = 'socks_debug.log';
my $auth_user;
my $auth_pass;

# Add this debug function at the beginning of your script
sub debug_log {
    my ($message) = @_;
    if ($debug) {
        open my $log, '>>', $debug_file or die "Could not open log file: $!";
        print $log "$message\n";
        close $log;
    }
}

my $port = $ENV{'SOCKS_PORT'} // 1080;

# Iterate through @ARGV and process each flag
for (my $i = 0; $i < @ARGV; $i++) {
    if ($ARGV[$i] eq '-p' && $ARGV[$i + 1]) {
        $port = $ARGV[$i + 1];
        $i++;
    } elsif ($ARGV[$i] eq '-h') {
        print_help();
        exit(0);
    } elsif ($ARGV[$i] eq '-d') {
        $debug = 1;
        $debug_file = $ARGV[$i + 1] if defined $ARGV[$i + 1];
        $i++;
    } elsif ($ARGV[$i] eq '-auth' && $ARGV[$i + 1]) {
        ($auth_user, $auth_pass) = split(':', $ARGV[$i + 1]);
        $i++;
    }
}

my $port_source = $ENV{'SOCKS_PORT'} ? 'environment variable' : 'default';
$port_source = 'command line flag' if grep { $_ eq '-p' } @ARGV;

my $server = IO::Socket::INET->new(
    LocalPort => $port,
    Proto     => 'tcp',
    Listen    => SOMAXCONN,
    Reuse     => 1
) or die "Could not create socket: $!\n";

debug_log("SOCKS5 server is running and listening on port $port (source: $port_source)");

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
        $select->remove($client);
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
        $select->remove($client);
        close($client);
        return;
    }

    my @methods = unpack("C$nmethods", substr($data, 2));
    debug_log("Authentication methods: " . join(", ", @methods));

    if ($auth_user && $auth_pass) {
        if (!grep { $_ == 2 } @methods) {
            debug_log("No acceptable authentication method");
            $client->syswrite(pack('C2', 5, 0xFF)); # Send error message
            debug_log("Sent error message to client before closing connection");
            $select->remove($client);
            close($client);
            return;
        }
        $client->syswrite(pack('C2', 5, 2));
        debug_log("Sent authentication response");

        # Read username and password
        my $bytes_read = $client->sysread($data, 2);
        my ($ulen) = unpack('C', substr($data, 1, 1));
        $bytes_read = $client->sysread($data, $ulen + 1);
        my $username = unpack("A$ulen", substr($data, 0, $ulen));
        my ($plen) = unpack('C', substr($data, $ulen, 1));
        $bytes_read = $client->sysread($data, $plen);
        my $password = unpack("A$plen", $data);

        if ($username ne $auth_user || $password ne $auth_pass) {
            debug_log("Invalid username or password");
            $client->syswrite(pack('C2', 1, 1));
            $select->remove($client);
            close($client);
            return;
        }
        $client->syswrite(pack('C2', 1, 0));
    } else {
        if (!grep { $_ == 0 } @methods) {
            debug_log("No acceptable authentication method");
            $client->syswrite(pack('C2', 5, 0xFF)); # Send error message
            debug_log("Sent error message to client before closing connection");
            $select->remove($client);
            close($client);
            return;
        }
        $client->syswrite(pack('C2', 5, 0));
        debug_log("Sent authentication response");
    }

    # Read SOCKS5 request
    my $bytes_read = $client->sysread($data, 4);
    debug_log("Read $bytes_read bytes for SOCKS5 request");
    debug_log("SOCKS5 request data: " . unpack("H*", $data));

    my ($ver, $cmd, $rsv, $atyp) = unpack('C4', $data);
    debug_log("SOCKS5 request - Version: $ver, Command: $cmd, Reserved: $rsv, Address type: $atyp");

    if ($ver != 5 || $cmd != 1) {
        debug_log("Invalid SOCKS5 request");
        $select->remove($client);
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
        $select->remove($client);
        close($client);
        return;
    }

    debug_log("Target address: $addr");

    # Connect to target server
    my $target = IO::Socket::INET->new(PeerAddr => $addr, Proto => 'tcp');
    if (!$target) {
        debug_log("Failed to connect to target server");
        $client->syswrite(pack('C4', 5, 5, 0, 1) . pack('Nn', 0, 0));
        $select->remove($client);
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
        $select->remove($client);
        close($client);
        $select->remove($target);
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

    debug_log("Handling SOCKS4 request");

    my ($version, $cmd, $port, $ip_packed, $user_id) = unpack('C2 n a4 Z*', $data);
    debug_log("SOCKS4 request - Version: $version, Command: $cmd, Port: $port, IP: " . join('.', unpack('C4', $ip_packed)) . ", User ID: $user_id");

    if ($version != 4 || $cmd != 1) {
        debug_log("Invalid SOCKS4 request");
        $select->remove($client);
        close($client);
        return;
    }

    my $ip = join('.', unpack('C4', $ip_packed));
    my $addr = "$ip:$port";
    debug_log("Target address: $addr");

    # Connect to target server
    my $target = IO::Socket::INET->new(PeerAddr => $addr, Proto => 'tcp');
    if (!$target) {
        debug_log("Failed to connect to target server");
        $client->syswrite(pack('C8', 0, 91, 0, 0, 0, 0, 0, 0));
        $select->remove($client);
        close($client);
        return;
    }

    debug_log("Connected to target server");

    my $response = pack('C8', 0, 90, 0, 0, 0, 0, 0, 0);
    debug_log("Response to client: " . unpack("H*", $response));
    $client->syswrite($response);

    # Add target to select
    $select->add($target);

    # Relay data between client and target server
    relay_data($client, $target, $select);
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
    -d [file]   Enable debug logging (optional: specify log file, default: socks_debug.log)
    -auth <user:pass> Specify the username and password for authentication
    Multiple flags can be used together, e.g., -p 1080 -d -auth user:pass
END_HELP
}
