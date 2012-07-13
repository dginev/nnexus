#!/usr/bin/perl
# ----------------------------------------------------------------
# This is the main entry point of the nnexus server
# written by James Gardner for Google's Summer of Code 2006
# ----------------------------------------------------------------
use lib '/var/www/nnexus/';
package NNexus;
use strict;
use IO::Socket;
use Sys::Hostname;
use NNexus::Response;
use Data::Dumper;
use NNexus::DB;
use NNexus::Config;
use Encode;
use vars qw($config $dbh $new_sock);
use POSIX qw(:sys_wait_h);
sub REAP {
    1 until (-1 == waitpid(-1, WNOHANG));
    $SIG{CHLD} = \&REAP;
}
$SIG{CHLD} = \&REAP;

#
# set up the config hash and open the db and intialize the db with new info from the
# config file
#
init();

my $sock = new IO::Socket::INET(
			LocalHost => 'localhost',
			LocalPort => $config->{'server'}->{'port'},
			Proto => 'tcp',
			Listen => SOMAXCONN,
			ReuseAddr => 1
			);
die "Could not create socket\n" unless $sock;
STDOUT->autoflush(1);
my($new_sock, $buf, $kid, $c_addr);
print "NNexus now accepting connections\n";
while (1){ #run me forever

while (($new_sock, $c_addr) = $sock->accept()) {
	# execute a fork, if this is
   	# go straight to continue
    	next if $kid = fork;
    	die "fork: $!" unless defined $kid;
	# child now...
    	# close the main server socket for the child
	close $sock;
    	my ($client_port, $c_ip) =  sockaddr_in($c_addr);
    	my $client_ipnum = inet_ntoa($c_ip);
    	my $client_host = gethostbyaddr($c_ip, AF_INET);
    	#print "got a connection from: $client_host", " [$client_ipnum]\n";

	#open a mysql connection for the child;
	dbConnect();
	socket_handler( $new_sock );

	#print "connection to $client_host [$client_ipnum] closed\n";
	exit;
} continue {
	# parent closes the client socket 
	close $new_sock;
}

}
