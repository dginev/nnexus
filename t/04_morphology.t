use strict;
use warnings;

use Test::More tests => 4;

use NNexus::Morphology qw(get_nonpossessive is_possessive depluralize is_plural);

my $possessives = ["De Morgan's Law", "Thompson's Theorem", "Ross' Axiom"];
my $plurals = ["De Morgan's Laws", "Axioms of Choice", "Proofs by induction","Euclidean spaces"];

ok(grep{is_possessive($_)} @$possessives, 3, 'Possessive predicate.');
ok(grep{is_plural($_)} @$plurals, 4, 'Plurality predicate.');

is_deeply([map{get_nonpossessive($_)} @$possessives],
          ['De Morgan Law','Thompson Theorem','Ross Axiom'],
          'Generating non-possessive equivalent.');

is_deeply([map{depluralize($_)} @$plurals], 
          ["De Morgan's Law","Axiom of Choice","Proof by induction","Euclidean space"],
          'Generating depluralized equivalent');

# Done
1;
