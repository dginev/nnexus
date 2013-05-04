use NNexus::DB;
use NNexus::Job;
use Data::Dumper;

my $url = $ARGV[0];
my $domain = $ARGV[1];
my $db = NNexus::DB->new("dbms" => "SQLite",
    "dbname" => "/home/dreamweaver/git/nnexus/blib/lib/NNexus/resources/database/snapshot.db",
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost");

# 2. Index all sites, showing intermediate progress
my $index_job = NNexus::Job->new(function=>'index',verbosity=>1,
		   url=>$url,domain=>$domain,db=>$db,should_update=>1);
$index_job->execute;
my $response = $index_job->response;
print STDERR Dumper($response);