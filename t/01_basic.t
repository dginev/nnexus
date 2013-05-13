use strict;
use warnings;

use Test::More tests => 3;

my $eval_return = eval {
  use Mojolicious;
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

is($Mojolicious::VERSION >= 3.9, 1, "New enough Mojolicious installed, at least 3.9.");


my $job = NNexus::Job->new('format' => 'html', 'function' => 'linkentry', 'domain' => 'planetmath');
ok($job, 'Can initialize a generic linking NNexus::Job');
