use strict;
use warnings;

use Test::More tests => 4;
use File::Temp;
File::Temp->safe_level( File::Temp::HIGH );

use NNexus::Config;
use NNexus::Job;

my $opts = read_json_file('setup/config.json');
ok($opts, 'Default configuration setup/config.json loads fine.');

# However, we really want our own test setup:
my $tmphandle = File::Temp->new( TEMPLATE => 'nnexusXXXXX',
                       SUFFIX => '.db');
$opts = {
  "database" => {
    "dbms" => "SQLite",
    "dbname" => $tmphandle->filename,
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost",
  },
  "verbosity" => 0
};

my $db = NNexus::DB->new(%{$opts->{database}},"dbinitialize" => 1);
ok($db, 'NNexus::DB object successfully created.');
ok ($db->ping, 'SQLite database is operational');

my $config=NNexus::Config->new($opts);
ok ($config, 'Can initialize a new NNexus::Config object');

sleep 10;