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

srand(time());

my $deleteNum = @objects - $numObjects;
my $odel = $dbh->prepare("delete from object where objectid = ?");
my $cdel = $dbh->prepare("delete from concepthash where objectid = ?");

while( $deleteNum != 0 ) {
	my $obj = splice( @objects, rand(@objects), 1 );
	my $objectid = $obj->{'objectid'};
	my $id = $obj->{'identifier'};
	$odel->execute($objectid);
	$cdel->execute($objectid);
	$deleteNum--;
}
