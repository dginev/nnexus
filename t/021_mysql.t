use strict;
use warnings;

use Test::More tests => 2;

use NNexus::Config;
use NNexus::Job;

# Let's try the MySQL setup:
my $opts = read_json_file('setup/config.json');
$opts->{database}->{dbms} = 'mysql'; # Making sure we're testing the right DBMS

my $db = NNexus::DB->new(%{$opts->{database}});
ok($db, 'NNexus::DB object successfully created.');

SKIP: {
	my $eval_return = eval { $db->ping };
	if ((!$eval_return) || $@ ) {
		skip "Config couldn't initialize with the default setup at setup/config.json."
	 	." Do you have MySQL properly setup? Skipping...", 1;
	} else {
		ok ($db->ping, 'Can initialize a new NNexus::DB object');
	}
}
