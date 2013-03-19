use strict;
use warnings;

use Test::More tests => 3;

use NNexus::Config;
use NNexus::Job;
use XML::Simple;

my $opts = XMLin('setup/baseconf.xml');
ok($opts, 'Base configuration loads fine.');

my $dbh = NNexus::DB->new(config=>$opts);
ok ($dbh, 'Can initialize a new NNexus::DB instance');

SKIP: {
	my $config;
	my $eval_return = eval { $dbh->dbConnect;  1; };
	if ((!$eval_return) || $@ ) {
		skip "Config couldn't initialize with the default setup at setup/baseconf.xml\n."
	 	." Do you have MySQL properly setup? Skipping...", 1;
	} else {
		$config = NNexus::Config->new($opts);
		ok ($config, 'Can initialize a new NNexus::Config instance');	
	}
}