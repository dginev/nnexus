use strict;
use warnings;

use Test::More tests => 3;

use NNexus::Config;
use NNexus::Job;

my $opts = read_json_file('setup/config.json');
ok($opts, 'Default configuration setup/config.json loads fine.');

my $db = NNexus::DB->new(%{$opts->{database}});
ok($db, 'NNexus::DB object successfully created.');


SKIP: {
	my $eval_return = eval { $db->do->ping };
	if ((!$eval_return) || $@ ) {
		skip "Config couldn't initialize with the default setup at setup/config.json."
	 	." Do you have MySQL properly setup? Skipping...", 1;
	} else {
		ok ($db, 'Can initialize a new NNexus::DB object');

		my $config=NNexus::Config->new($opts);
		ok ($config, 'Can initialize a new NNexus::Config object');
	}
}



