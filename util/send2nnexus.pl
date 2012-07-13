#!/usr/bin/perl

#this is a program for sending NNexus formated xml directly to the NNexus
# server on the localhost at port 7070.

use strict;

use Time::HiRes qw ( time alarm sleep );

use Data::Dumper;
use XML::Writer;
use IO::Socket;
use XML::Simple; #we use this to read server responses.

my $start = time();


my $sock = new IO::Socket::INET (
                                  PeerAddr => 'localhost',
                                 PeerPort => '7071',
                                  Proto => 'tcp'
                                );
die "Could not create socket: $!\n" unless $sock;



print "sending $ARGV[0]\n";
open (INPUT, $ARGV[0]);

print $sock "<request>\n";
while ( <INPUT> ) {
	print $sock "$_";
}
print $sock "\n</request>\n";


while (my $bl = <$sock>){
	print $bl;
#	$response .= $bl;

}
close($sock);
my $end = time();

#print $response;
my $total = $end - $start;
print "\noperation took $total seconds\n";
#print $response;
