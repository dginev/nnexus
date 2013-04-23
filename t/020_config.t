use strict;
use warnings;

use Test::More tests => 2;

use NNexus::DB;

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