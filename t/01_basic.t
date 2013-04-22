use strict;
use warnings;

use Test::More tests => 2;

my $eval_return = eval {
  use NNexus::Config;
  use NNexus::Job;
  use NNexus::Index::Dispatcher;
  use NNexus::Index::Template;
  use NNexus::Concepts;
  use NNexus::DB;
  use NNexus::Discover;
  use NNexus::Annotate;
  use NNexus::Morphology;
  use NNexus::Classification;
  use NNexus;
  1;
};

ok($eval_return && !$@, 'NNexus Modules Loaded successfully.');

my $job = NNexus::Job->new('format' => 'html', 'function' => 'linkentry', 'domain' => 'planetmath');
ok($job, 'Can initialize a generic linking NNexus::Job');
