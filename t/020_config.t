use strict;
use warnings;

use Test::More tests => 3;

use NNexus::Config;
use NNexus::Job;

my $options = {
  "database" => {
    "dbms" => "SQLite",
    "dbname" => ':memory:',
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost",
  },
  "verbosity" => 0
};

my $db = NNexus::DB->new(%{$options->{database}});
ok($db, 'NNexus::DB object successfully created.');
ok ($db->ping, 'SQLite database is operational');

my $config=NNexus::Config->new($options);
ok ($config, 'Can initialize a new NNexus::Config object');
