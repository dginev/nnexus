# Execute from the root NNexus directory as:
# perl util/merge_snapshots.pl
# .. given you already have the *.db files in the root directory.
# (feel free to improve!)
use warnings;
use strict;
use NNexus::DB;

# ON CHANGE: Update $stamp in Makefile.PL
my $stamp = "1-2014";
my $snapshot_name = "index-snapshot-$stamp.db";
unlink($snapshot_name) if -e $snapshot_name;
my $snapshotdb = NNexus::DB->new("dbms" => "SQLite",
    "dbname" => $snapshot_name,
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost");
my @databases = map {NNexus::DB->new("dbms" => "SQLite",
    "dbname" => "$_.db",
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost");} qw/Planetmath Mathworld Wikipedia Dlmf/;

# Move individual snapshots into a common snapshot database.
$snapshotdb->safe->begin_work;
foreach my $db(@databases) {
	my $sth = $db->prepare("select * from objects");
	$sth->execute();
	while (my $object = $sth->fetchrow_hashref) {
		# Add the object to the Wiki snapshot
		my $new_objectid = $snapshotdb->add_object_by(%$object);
		# Grab the defined concepts:
		my $conch = $db->prepare("select * from concepts where objectid=?");
		$conch->execute($object->{objectid});
		while (my $concept = $conch->fetchrow_hashref() ) {
			# Insert in the wikidb
			$concept->{objectid} = $new_objectid;
			$snapshotdb->add_concept_by(%$concept);
		}
		$conch->finish();
	}
	$sth->finish();
}
$snapshotdb->safe->commit;
$snapshotdb->disconnect;
# Write down a dump:

`sqlite3 $snapshot_name .dump > lib/NNexus/resources/database/snapshot-$stamp.sqlite`;