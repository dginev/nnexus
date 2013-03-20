use strict;
use warnings;

use Test::More tests => 1;

use NNexus::Job;
use Data::Dumper;
use Mojo::DOM;

sub local_dom {
	my ($path) = @_;
	open my $localfh, "<", $path;
	my $contents = join('',<$localfh>);
	close $localfh;
	Mojo::DOM->new($contents);
}

# Prepare a Mojo::DOM
my $wiki_file = 't/pages/Integral.html';
my $wiki_dom = local_dom($wiki_file);

my $index_job = NNexus::Job->new(function=>'index',
	url=>$wiki_file,dom=>$wiki_dom,domain=>"wikipedia");
$index_job->execute;
my $response = $index_job->response;
is($response->{status},'OK','Error-free indexing');
ok($response->{payload},'Indexing returned a concept hash');