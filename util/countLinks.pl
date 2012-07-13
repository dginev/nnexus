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
	push @objects, $row;
}

my $count = 0;
foreach my $o ( @objects ) {
	my $id = $o->{'identifier'};
	my $filename = "planetmath/$id/$id-$numObjects.html";
	open ( IN, $filename );
	while ( my $line = <IN> ) {
		if ( $line =~ /var\smenu/ ) {
			$count++;
		}
	}
	close( IN );
}
print "$count\n";
