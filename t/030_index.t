use strict;
use warnings;

use Test::More tests => 6;

use NNexus::Job;
use NNexus::DB;
use Data::Dumper;
use Mojo::DOM;

sub local_dom {
	my ($path) = @_;
	open my $localfh, "<", $path;
	my $contents = join('',<$localfh>);
	close $localfh;
	Mojo::DOM->new($contents);
}

# Test DB setup:
my $opts = {
  "database" => {
    "dbms" => "SQLite",
    "dbname" => "setup/database/sqlite/nnexus.db",
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost"
  },
  "verbosity" => 1
};

my $db = NNexus::DB->new(%{$opts->{database}});

sub index_test{
	my (%options)=@_;
	# Prepare a Mojo::DOM
	my $url = $options{url}; 
	my $dom = local_dom($url) if ($url && ($url ne 'default'));

	my $index_job = NNexus::Job->new(function=>'index',
	url=>$url,dom=>$dom,domain=>$options{domain},db=>$db);

  $index_job->execute;

  my $response = $index_job->response;
  is($response->{status},'OK','Error-free indexing in '.$options{domain});
  my @concepts = ref $response->{payload} ? @{$response->{payload}} : ();
  ok(@concepts,$options{domain}.' Indexing returned a concept hash');	
}

# Test the Wikipedia indexing
index_test(
  url=>'t/pages/Integral.html',
  domain=>'wikipedia');

# Test the PlanetMath indexing
index_test(
  url=>'t/pages/HeytingAlgebra.html',
  domain=>'planetmath');

# Test the MathWorld indexing
index_test(
  url=>'t/pages/QuadraticInvariant.html',
  domain=>'mathworld');

# TODO: Add a DLMF test
# Note: Uncomment to index all of Wikipedia's math concepts
 # index_test(
 #    url=>'default',
 #    domain=>'DLMF');

# TODO: 
# Check that all indexed concepts have made it to the database
