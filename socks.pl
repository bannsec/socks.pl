use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use POSIX qw(:signal_h);

my $port = 1080;
if (@ARGV && $ARGV[0] eq '-p' && $ARGV[1]) {
    $port = $ARGV[1];
}

my $server = IO::Socket::INET->new(
    LocalPort => $port,
    Proto     => 'tcp',
    Listen    => SOMAXCONN,
    Reuse     => 1
) or die "Could not create socket: $!\n";

print "SOCKS5 server is running and listening on port $port\n";

my $select = IO::Select->new($server);

$SIG{INT} = sub {
    print "Shutting down the server...\n";
    close($server);
    exit(0);
};

while (1) {
    my @ready = $select->can_read;
    foreach my $fh (@ready) {
        if ($fh == $server) {
            my $client = $server->accept;
            $select->add($client);
        } else {
            my $data;
            my $bytes_read = $fh->sysread($data, 1024);
            if ($bytes_read) {
                # Handle SOCKS5 protocol here
                handle_socks5($fh, $data);
            } else {
                $select->remove($fh);
                close($fh);
            }
        }
    }
}

sub handle_socks5 {
    my ($client, $data) = @_;

    # Initial SOCKS5 handshake
    my ($version, $nmethods) = unpack('C2', $data);
    if ($version != 5) {
        close($client);
        return;
    }

    my @methods = unpack("C$nmethods", substr($data, 2));
    if (!grep { $_ == 0 } @methods) {
        close($client);
        return;
    }

    $client->syswrite(pack('C2', 5, 0));

    # Read SOCKS5 request
    $client->sysread($data, 4);
    my ($ver, $cmd, $rsv, $atyp) = unpack('C4', $data);
    if ($ver != 5 || $cmd != 1) {
        close($client);
        return;
    }

    my $addr;
    if ($atyp == 1) {
        $client->sysread($data, 6);
        my ($ip, $port) = unpack('Nn', $data);
        $addr = inet_ntoa(pack('N', $ip)) . ":$port";
    } elsif ($atyp == 3) {
        $client->sysread($data, 1);
        my $len = unpack('C', $data);
        $client->sysread($data, $len + 2);
        my ($host, $port) = unpack("A$len n", $data);
        $addr = "$host:$port";
    } else {
        close($client);
        return;
    }

    # Connect to target server
    my $target = IO::Socket::INET->new(PeerAddr => $addr, Proto => 'tcp');
    if (!$target) {
        $client->syswrite(pack('C4', 5, 5, 0, 1) . pack('Nn', 0, 0));
        close($client);
        return;
    }

    $client->syswrite(pack('C4', 5, 0, 0, 1) . pack('Nn', inet_aton($target->peerhost), $target->peerport));

    # Relay data between client and target server
    my $select = IO::Select->new($client, $target);
    while (1) {
        my @ready = $select->can_read;
        foreach my $fh (@ready) {
            my $data;
            my $bytes_read = $fh->sysread($data, 1024);
            if ($bytes_read) {
                if ($fh == $client) {
                    $target->syswrite($data);
                } else {
                    $client->syswrite($data);
                }
            } else {
                close($client);
                close($target);
                return;
            }
        }
    }
}
