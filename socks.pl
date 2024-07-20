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
                # For simplicity, just echo the data back to the client
                $fh->syswrite($data);
            } else {
                $select->remove($fh);
                close($fh);
            }
        }
    }
}
