use strict;
use warnings;

use Test::More tests => 8;

use NNexus::Morphology qw(get_nonpossessive is_possessive depluralize_word depluralize_phrase is_plural
	admissible_name normalize_concept firstword_split);

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

# Admissible names, normalization and first word splits
my $name_candidates = ['$\alpha$-reduction','-k number','2^k-1 primes','Semi-formal proofs','De Morgan\'s Laws'];
my $admissible_candidates = [ grep {admissible_name($_)} @$name_candidates];
is_deeply($admissible_candidates,['Semi-formal proofs','De Morgan\'s Laws'],'Admissible names filtered as expected.');

my $normalized_candidates = [ map {normalize_concept($_)} @$admissible_candidates ];
is_deeply($normalized_candidates,['semi-formal proof','de morgan law'],'Name normalization works as expected.');
my $first_tail_candidates = [ map {[firstword_split($_)]} @$normalized_candidates ]; 
is_deeply($first_tail_candidates,
	[
		['semi-formal','proof'],
		['de','morgan law']
	],
	'Firstword split works as expected.');
# Done
1;
