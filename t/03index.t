use strict;
use warnings;

use Test::More tests => 1;

use NNexus::Job;
use Data::Dumper;

my $index_job = NNexus::Job->new(function=>'index',
	body=>'http://en.wikipedia.org/wiki/Integral',domain=>"wikipedia");
$index_job->execute;
my $response = $index_job->response;
is($response->{status},'OK');

