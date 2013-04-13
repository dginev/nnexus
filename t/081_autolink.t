use strict;
use warnings;

use Test::More tests => 2;
use File::Temp;
File::Temp->safe_level( File::Temp::HIGH );

use NNexus::Job;
use NNexus::Config;

# However, we really want our own test setup:
my $tmphandle = File::Temp->new( TEMPLATE => 'nnexusXXXXX',
                       SUFFIX => '.db');
my $options = {
  "database" => {
    "dbms" => "SQLite",
    "dbname" => $tmphandle->filename,
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost",
  },
  "verbosity" => 0
};

my $config=NNexus::Config->new($options);
# 1. Mock JSON
my $job = NNexus::Job->new('format' => 'text', 'function' => 'linkentry', 'domain' => 'Planetmath', body=>'mock body',config=>$config,annotation=>'json');
$job->execute;
is_deeply($job->response,
	  {status=>'OK',payload=>[],message=>'No obvious problems.'},
	  'Mock JSON auto-link, ok.');
# 2. Mock HTML
$job = NNexus::Job->new('format' => 'text', 'function' => 'linkentry', 'domain' => 'Planetmath', body=>'mock body',config=>$config,annotation=>'links');
$job->execute;
is_deeply($job->response,
	  {status=>'OK',payload=>'mock body',message=>'No obvious problems.'},
	  'Mock text-embed auto-link, ok.');


# TODO: Expand with more meaningful tests
