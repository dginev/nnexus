use NNexus::DB;
use warnings;
use strict;

my $wikidb = NNexus::DB->new(    "dbms" => "SQLite",
    "dbname" => 'index-snapshot-20-4-2013.db',
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost");
my $restdb = NNexus::DB->new(    "dbms" => "SQLite",
    "dbname" => 'index-snapshot-19-4-2013.db',
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost");

# Move Planetmath , Dlmf and Mathworld domains into the $wikidb database.
use Data::Dumper;
foreach my $domain(qw/Planetmath Dlmf Mathworld/) {
	my $sth = $restdb->prepare("select * from objects where domain=?");
	$sth->execute($domain);
	while (my $object = $sth->fetchrow_hashref) {
		# Add the object to the Wiki snapshot
		my $new_objectid = $wikidb->add_object_by(%$object);
		# Grab the defined concepts:
		my $conch = $restdb->prepare("select * from concepts where objectid=? AND domain=?");
		$conch->execute($object->{objectid},$domain);
		while (my $concept = $conch->fetchrow_hashref() ) {
			# Insert in the wikidb
			$concept->{objectid} = $new_objectid;
			$wikidb->add_concept_by(%$concept);
		}
		$conch->finish();
	}
	$sth->finish();
}