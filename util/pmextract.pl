#!/usr/bin/perl
use strict;

use Data::Dumper;
use DBI;

my $databasename = $ARGV[0];

my $dbh = DBI->connect( "DBI:mysql:$databasename;localhost", "nnexus", "nnexus", 
			{RaiseError=>1}) || die "coundn't connect" ;

my $sth = $dbh->prepare( "select * from object");
$sth->execute();

while( my $row = $sth->fetchrow_hashref() ) {
	print Dumper($row);
}

sub uniquify {
        my @a = @_;
	my %seen = ();
	my @uniqu = grep { ! $seen{$_} ++ } @a;
        return @uniqu;
}
