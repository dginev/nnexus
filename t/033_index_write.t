use strict;
use warnings;

use Test::More tests => 6;

use NNexus::Job;
use NNexus::DB;
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
    "dbname" => ':memory:',
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost"
  },
  "verbosity" => 1
};

my $db = NNexus::DB->new(%{$opts->{database}});

sub index_test {
  my (%options)=@_;
  # Prepare a Mojo::DOM
  my $url = $options{url}; 
  my $dom = local_dom($url) if ($url && ($url ne 'default'));
  my $index_job = NNexus::Job->new(function=>'indexentry',
                                   url=>$url,dom=>$dom,domain=>$options{domain},db=>$db);
  $index_job->execute;
  
  my $response = $index_job->response;
  is($response->{status},'OK','Error-free indexing in '.$options{domain});
  is_deeply($response->{payload},[],$options{domain}.' Indexing returned a concept hash');
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

# Count the concepts in the DB are what we expect

# Reindex, check count changes and differences are enforced