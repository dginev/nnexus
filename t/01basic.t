use strict;
use warnings;

use Test::More tests => 2;

use NNexus::Config;
use NNexus::Job;
use XML::Simple;

ok(1, 'Loaded fine');

my $job = NNexus::Job->new('format' => 'html', 'function' => 'linkentry', 'domain' => 'planetmath');
ok($job, 'Can initialize a linking NNexus::Job');