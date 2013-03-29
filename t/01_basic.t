use strict;
use warnings;

use Test::More tests => 2;

my $eval_return = eval {
  use NNexus::Config;
  use NNexus::Job;
  use NNexus::Index::Dispatcher;
  use NNexus::Concepts;
  use NNexus::DB;
  use NNexus::Util;
  1;
};

ok($eval_return && !$@, 'NNexus Modules Loaded successfully.');

my $job = NNexus::Job->new('format' => 'html', 'function' => 'linkentry', 'domain' => 'planetmath');
ok($job, 'Can initialize a generic linking NNexus::Job');
