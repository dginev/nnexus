use strict;
use warnings;

use Test::More tests => 6;

use NNexus::Job;
use NNexus::DB;
use Data::Dumper;
use Mojo::DOM;
use File::Temp;

sub local_dom {
	my ($path) = @_;
	open my $localfh, "<", $path;
	my $contents = join('',<$localfh>);
	close $localfh;
	Mojo::DOM->new($contents);
}

# Test DB setup:
# However, we really want our own test setup:
my $tmphandle = File::Temp->new( TEMPLATE => 'nnexusXXXXX',
                       SUFFIX => '.db');
my $opts = {
  "database" => {
    "dbms" => "SQLite",
    "dbname" => $tmphandle->filename,
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost"
  },
  "verbosity" => 1
};

my $db = NNexus::DB->new(%{$opts->{database}},dbinitialize=>1);
use Data::Dumper;
sub index_test {
  my (%options)=@_;
  # Prepare a Mojo::DOM
  my $url = $options{url}; 
  my $dom = local_dom($url) if ($url && ($url ne 'default'));
  my $index_job = NNexus::Job->new(function=>'index',
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