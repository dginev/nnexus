#!/usr/bin/perl
use strict;

use Data::Dumper;
use DBI;

my $databasename = $ARGV[0];

my $dbh = DBI->connect( "DBI:mysql:$databasename;localhost", "nnexus", "nnexus", 
			{RaiseError=>1}) || die "coundn't connect" ;

my $sth = $dbh->prepare( "select * from object");
$sth->execute();

my @files = ();

while( my $row = $sth->fetchrow_hashref() ) {
	my $body = $row->{'body'};
	my $title = $row->{'title'};
	my $author = $row->{'author'};

	my $identifier = $row->{'identifier'};
	my $domain = "planetmath";
	
	my $filename = $identifier . ".tex";

	my $header = '\documentclass{article}' . "\n" . '\begin{document}\n';
	$header .= '\title{' . $title . '}' . "\n";
	$header .= '\author{' . $author . '}' . "\n";
	$header .= '\maketitle' . "\n";
	$body = $header . $body;
	
	$body .= '\end{document}';

	my $f = "$domain/$filename";
	open( OUT , ">$f" );
	print OUT $body;
	close( OUT );
	
	push (@files, "$f");
}

print "done extracting... now rendering\n";

foreach my $fname ( @files ) {
	print "rendering $fname\n";
	`latex2html $fname`;
}

sub uniquify {
        my @a = @_;
	my %seen = ();
	my @uniqu = grep { ! $seen{$_} ++ } @a;
        return @uniqu;
}
