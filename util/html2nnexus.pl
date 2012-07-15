#!/usr/bin/perl

#this script converts all the objects in the pm databases to the form that nnexus requires for linking
use strict;

use Time::HiRes qw ( time alarm sleep );

use Data::Dumper;
use XML::Writer;
use IO::Socket;
use XML::Simple;

#get the file
if ( @ARGV < 2 ) { die 'need <input> and <output> SHIAT!'; }
my $filename = $ARGV[0];
my $outfilename = $ARGV[1];

my @path = split( /\//, $filename );
my $title = $path[$#path];
$title =~ s/\.html$//;

open( FILE, "< $filename" ) or die "Can't open $filename : $!";

my @classstrings = ();

my $input = "";
while( <FILE> ) {
	my $line = $_;
	$input .= $line;
	if ( $line =~ /<meta\s+name="classification"\s+content="(.*)"\s*\/>/ ) {
		push @classstrings, $1;
	}
}
close FILE;

my @classes = ();

foreach my $c ( @classstrings ) {
	push @classes, split( /,/ , $c );
}

#get the classification from the HTML meta tags.
#<meta name="classification" content="msc:60G07,msc:..." />

my $output = "";
my $writer = new XML::Writer(OUTPUT => \$output);

	$writer->startTag('linkentry');
	$writer->startTag('domain');
	$writer->characters("planetmath.org");
	$writer->endTag('domain');
	$writer->startTag('objid');
	$writer->characters($title);
	$writer->endTag('objid');
	$writer->startTag('title');
	$writer->characters($title);
	$writer->endTag('title');
	$writer->startTag('format');
	$writer->characters("html");	
	$writer->endTag('format');
	$writer->startTag('body');
	$writer->characters($input);
	$writer->endTag('body');
	foreach my $c (@classes){
		$writer->startTag('class');
		$writer->characters($c);
		$writer->endTag('class');
	}
	$writer->startTag('mode');
	$writer->characters("0");
	$writer->endTag('mode');
	$writer->endTag('linkentry');
$writer->end();

# was breaking at one point
my $server = XMLin("config.xml");

#print Dumper($configu);

print $server->{'host'}. ":".  $server->{'port'},"\n";

my $sock = new IO::Socket::INET (
                                  PeerAddr => "$server->{host}",
                                 PeerPort => "$server->{port}",
                                  Proto => 'tcp'
                                );
die "Could not create socket: $!\n" unless $sock;
print $sock "<request>\n$output\n</request>\n";
print "PORT = " . $server->{'port'},"\n";

my $response = "";
while (my $bl = <$sock>){
	$response .= $bl;
}

print "RESPONSE =\n$response\n";

#find the body in the response and return that
$response =~ /<linked.*?>(.*)<\/linked.*?>/s;
my $linked = $1;

print "LINKED = $linked\n";

my $config = XMLin($response);
my $htmltext = $config->{'linked'}->{'body'};
#print $output;

print $htmltext;

print "writing linked html to $outfilename\n";
#print Dumper( $config);

#print Dumper( $config->{'linked'}->{'body'} );
#print Dumper( $config );
open (OUTFILE, ">$outfilename");
print OUTFILE $linked;
close($sock);

close(OUTFILE);
