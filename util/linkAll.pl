use DBI;

use strict;

my $numObjects = $ARGV[0];

my $dbh = DBI->connect("DBI:mysql:planetmath;host=localhost" ,
				"nnexus",
				"nnexus",
                          { RaiseError => 0, PrintError  => 0, AutoCommit => 1}
                   );


my $sth = $dbh->prepare("select identifier, objectid from object");

$sth->execute();

my @objects = ();

while( my $row = $sth->fetchrow_hashref() ) {
	my $id = $row->{'identifier'};
	my $objectid = $row->{'objectid'};
	print "adding $id\n";
	push @objects, $row;
}

my $start = time();
foreach my $o ( @objects ) {
	my $id = $o->{'identifier'};
	print `perl html2nnexus.pl planetmath/$id/$id.html planetmath/$id/$id-$numObjects.html`;
}
my $end = time();

my $total = $end - $start;
print "$total seconds to complete to link $numObjects\n";
