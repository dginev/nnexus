#!/usr/bin/perl
#latex2nnexus <input.tex> <output.tex>

#this script converts a tex file into NNexus format, links it, and saves the output into output.tex
use strict;

use Time::HiRes qw ( time alarm sleep );

use Data::Dumper;
use XML::Writer;
use IO::Socket;
use XML::Simple;

#get the file
if ( $#ARGV != 1) {
 print "usage: latex2nnexus <input.tex> <output.tex>\n";
 exit;
}
my $filename = $ARGV[0];
my $outfilename = $ARGV[1];

my $title = $filename;

open( FILE, "< $filename" ) or die "Can't open $filename : $!";


my $input = "";
while( <FILE> ) {
	$input .= $_;
}
close FILE;

my $addhead = 1;
if ($input =~ /begin\{document\}/){
	$addhead = 0;
}

$input =~ m/%\s*MSC:\s*(.*)/;
my $class = $1;
my @classes = split(/\s*,\s*/, $class);




#we need to extract out all the header info because it gives
#problems for linking. We only want the body
my $body = "";
my $head = "";
my $foot = "";

if ($input =~ /((.|\n)*\\begin{document})((.|\n)*)(\\end{document}(.|\n)*)/ ){
	$head = $1;
	$body = $3;	
	$foot = $5;
}

my $output = "";
my $writer = new XML::Writer(OUTPUT => \$output);

	$writer->startTag('linkentry');
	$writer->startTag('domain');
	$writer->characters("pitman");
	$writer->endTag('domain');
	$writer->startTag('title');
	$writer->characters($title);
	$writer->endTag('title');
	$writer->startTag('body');
	$writer->characters($body);
	$writer->endTag('body');
	foreach my $c (@classes){
		$writer->startTag('class');
		$writer->characters($c);
		$writer->endTag('class');
	}
	$writer->endTag('linkentry');
$writer->end();

#print "sending this to nnexus:\n$output\n";

my $server = XMLin("config.xml");

#print Dumper($configu);

print $server->{'host'}. ":".  $server->{'port'};


my $sock = new IO::Socket::INET (
                                  PeerAddr => "$server->{host}",
                                 PeerPort => "$server->{port}",
                                  Proto => 'tcp'
                                );
die "Could not create socket: $!\n" unless $sock;

print "Sending to nnexus \n" . "<request>\n$output\n</request>\n";
print $sock "<request>\n$output\n</request>\n";

my $response = "";
while (my $bl = <$sock>){
	$response .= $bl;
}

print "response from nnexus = \n" . $response;
my $config = XMLin($response);

#make sure the header has usepackage{html}
$head =~ s/\\begin{document}/\\usepackage{html}\n\\begin{document}/;


print "outputting text to $outfilename\n";

open( OUTFILE, ">$outfilename" ) or die "Can't open $filename : $!";
print OUTFILE $head;
print OUTFILE $config->{'linked'}->{'body'};
print OUTFILE $foot;
close($sock);

