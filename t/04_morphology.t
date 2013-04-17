use strict;
use warnings;

use Test::More tests => 5;

use NNexus::Morphology qw(get_nonpossessive is_possessive depluralize_word depluralize_phrase is_plural);

my $possessives = ["De Morgan's Laws", "Thompson's Theorem", "Ross' Axiom"];
my $plurals = ["De Morgan's Laws", "Axioms of Choice", "Proofs by induction","Euclidean spaces"];

ok(grep{is_possessive($_)} @$possessives, 3, 'Possessive predicate.');
ok(grep{is_plural($_)} @$plurals, 4, 'Plurality predicate.');

is_deeply([map{get_nonpossessive($_)} @$possessives],
          ['De Morgan Laws','Thompson Theorem','Ross Axiom'],
          'Generating non-possessive equivalent.');

is_deeply([map{depluralize_phrase($_)} @$plurals], 
          ["De Morgan's Law","Axiom of Choice","Proof by induction","Euclidean space"],
          'Generating depluralized equivalent');

is_deeply([map {
    join(' ',map { depluralize_word(get_nonpossessive($_)) } split(/\s+/,$_))}
	   (@$possessives,@$plurals)],
	  ['De Morgan Law','Thompson Theorem','Ross Axiom',
	   'De Morgan Law','Axiom of Choice','Proof by induction',
	   'Euclidean space'],
	  'Generating normalized equivalent.');

# Done
1;
