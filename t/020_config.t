use strict;
use warnings;

use Test::More tests => 4;

use NNexus::Config;
use NNexus::Job;

my $opts = read_json_file('setup/config.json');
ok($opts, 'Default configuration setup/config.json loads fine.');

$opts = {
  "database" => {
    "dbms" => "SQLite",
    "dbname" => ':memory:',
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost",
  },
  "verbosity" => 0
};

my $db = NNexus::DB->new(%{$opts->{database}});
ok($db, 'NNexus::DB object successfully created.');
ok ($db->ping, 'SQLite database is operational');

my $config=NNexus::Config->new($opts);
ok ($config, 'Can initialize a new NNexus::Config object');