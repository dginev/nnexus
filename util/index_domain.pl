#/usr/bin/perl -w
use strict;
use warnings;

# This script starts with a fresh NNexus SQLite database 
#  and performs an indexing pass over all defined Index Templates
#  currently: PlanetMath, Wikipedia, DLMF and Mathworld

# It then creates a snapshot - both as a DB file and as a SQLite db dump.
# 1. Initialize
use NNexus::Job;
use NNexus::DB;
use Data::Dumper;
use Mojo::DOM;
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my $date = $mday.'-'.($mon+1).'-'.(1900+$year);

my $domain = ucfirst(lc(shift));
#my $dbname = "wiki-$date.db";
my $dbname = "$domain.db";
#unlink $dbname if (-e $dbname);
my $options = {
  "database" => {
    "dbms" => "SQLite",
    "dbname" => $dbname,
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost"
  },
  "verbosity" => 1
};
my $db = NNexus::DB->new(%{$options->{database}});

# 2. Index all sites, showing intermediate progress
my $index_job = NNexus::Job->new(function=>'index',verbosity=>1,
		   url=>'default',domain=>$domain,db=>$db,should_update=>0);
$index_job->execute;
my $response = $index_job->response;
print STDERR Dumper($response);

# 3. Create DB Dump
# TODO
# Done!