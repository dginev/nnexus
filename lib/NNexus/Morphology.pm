# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Text Morphology Module                                              | #
# |=====================================================================| #
# | Part of the Planetary project: http://trac.mathweb.org/planetary    | #
# |  Research software, produced as part of work done by:               | #
# |  the KWARC group at Jacobs University                               | #
# | Copyright (c) 2012                                                  | #
# | Released under the MIT License (MIT)                                | #
# |---------------------------------------------------------------------| #
# | Adapted from the original NNexus code by                            | #
# |                                  James Gardner and Aaron Krowne     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev <d.ginev@jacobs-university.de>                  #_#     | #
# | http://kwarc.info/people/dginev                            (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package NNexus::Morphology;
###########################################################################
#	text morphology 
###########################################################################
use strict;
use warnings;
use feature qw(switch);

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(is_possessive is_plural get_nonpossessive get_possessive
  depluralize_word depluralize_phrase root pluralize undetermine_word
  admissible_name firstword_split normalize_word
  canonicalize_url);
our %EXPORT_TAGS = (all=>qw(is_possessive is_plural get_nonpossessive get_possessive
  depluralize_word depluralize_phrase root pluralize undetermine_word
  admissible_name firstword_split normalize_word
  canonicalize_url));

use utf8;
use Encode qw{is_utf8};
use Text::Unidecode qw/unidecode/;

# TODO: Think about MathML

# 0. Define what we consider admissible and grammatical words and phrases, for the NNexus use case 
our $concept_word_rex = qr/\w(?:\w|[\-\+\'])*/;
our $concept_phrase_rex = qr/$concept_word_rex(?:\s+$concept_word_rex)*/;


# I. Possessives
# return true if any word is possessive (ends in 's or s')
sub is_possessive { $_[0]  =~ /\w('s|s')(\s|$)/; }

# return phrase without possessive suffix ("Euler's" becomes "Euler")
sub get_nonpossessive {
  my ($word) = @_;
  $word =~ s/'s(\s|$)/$1/ || $word =~ s/s'(\s|$)/s$1/;
  $word; }

# return first word with possessive suffix ("Euler" becomes "Euler's")
sub get_possessive {
  my ($word) = @_;
  $word =~ s/^($concept_word_rex)/$1'/;
  $word =~ s/^($concept_word_rex[^s])'/$1's/;
  $word; }

# II. Plurality

# predicate for plural or not
sub is_plural { $_[0] ne depluralize_phrase($_[0]); }

sub pluralize {
  given ($_[0]) {
    # "root of unity" pluralizes as "roots of unity" for example
    when (/($concept_word_rex)(\s+(of|by)\s+.+)/)	{ return pluralize($1).$2; }
    # normal pluralization
    when (/(.+ri)x$/) {	return "$1ces"; }
    when (/(.+t)ex$/) { return "$1ices"; }
    when(/(.+[aeiuo])x$/) { return "$1xes";	}
    when(/(.+[^aeiou])y$/) { return "$1ies"; }
    when(/(.+)ee$/) { return "$1ees"; }
    when(/(.+)us$/) { return "$1i"; }
    when(/(.+)ch$/) { return "$1ches"; }
    when(/(.+)ss$/) { return "$1sses"; }
    default { return $_[0].'s'; } } }

# singularize a phrase... remove root and replace
sub depluralize_phrase {
  given ($_[0]) {
    # "spaces of functions" depluralizes as "space of functions" for example.
    # also "proofs by induction"
    when (/(^\w[\w\s]+\w)(\s+(of|by)\s+.+)$/) {
      my ($l,$r) = ($1,$2);
      return depluralize_phrase($l).$r;
    }
    when(/(.+ri)ces$/) { return "$1x"; }
    when(/(.+t)ices$/) { return "$1ex";	}
    when(/(.+[aeiuo]x)es$/) { return $1; }
    when(/(.+)ies$/) { return "$1y"; }
    when(/(.+)ees$/) { return "$1ee"; }
    when(/(.+)ches$/) {	return "$1ch"; }
    when(/(.+o)ci$/) { return "$1cus"; }
    when(/(.+)sses$/) {	return "$1ss"; }
    when(/(.+ie)s$/) { return $1;	}
    when(/(.+[^eiuos])s$/) { return $1; }
    when(/(.+[^aeio])es$/) { return "$1e"; }
    default { return $_[0]; } } }

sub depluralize_word {
  given ($_[0]) {
    when(! /oci|s$/) { return $_[0]; }
    when(/(.+ri)ces$/) { return "$1x"; }
    when(/(.+t)ices$/) { return "$1ex";	}
    when(/(.+[aeiuo]x)es$/) { return $1; }
    when(/(.+)ies$/) { return "$1y"; }
    when(/(.+)ees$/) { return "$1ee"; }
    when(/(.+)ches$/) {	return "$1ch"; }
    when(/(.+)sses$/) {	return "$1ss"; }
    when(/(.+ie)s$/) { return $1;	}
    when(/(.+[^eiuos])s$/) { return $1; }
    when(/(.+[^aeio])es$/) { return "$1e"; }
    when(/(.+o)ci$/) { return "$1cus"; }
    default { return $_[0]; } }}

# III. Stemming

# get the non-plural root for a word
sub root {
  given ($_[0]) {
    when(/(.+ri)ces$/) { return $1; }
    when(/(.+[aeiuo]x)es$/) { return $1; }
    when(/(.+)ies$/) { return $1;	}
    when(/(.+)ches$/) {	return "$1ch"; }
    when(/(.+o)ci$/) { return "$1c"; }
    when(/(.+)sses$/) {	return "$1ss"; }
    when(/(.+[^eiuos])s$/) { return $1;	}
    when(/(.+[^aeio])es$/) { return "$1e"; }
    default { return $_[0]; }
  } }

# Remove determiners from a word:
sub undetermine_word {
  my ($concept) = @_;
  $concept =~ s/^(?:an?|the)(?:\s+|$)//;
  return $concept;
}

# IV. Admissible concept words and high-level api
sub admissible_name {$_[0]=~/^$concept_phrase_rex$/; }
our %normalized_words = ();
sub normalize_word {
  my ($concept)=@_;
  my $normalized_concept = $normalized_words{$concept};
  return $normalized_concept if $normalized_concept;
  $normalized_concept=
    depluralize_word(
      get_nonpossessive(
        undetermine_word(
          lc(
            unidecode(
              $concept)))));
  $normalized_words{$concept} = $normalized_concept;
  return $normalized_concept; }

sub firstword_split {
  my ($concept)=@_;
  if ($concept=~/^($concept_word_rex)\s?(.*)$/) { # Grab first word if not provided
    return ($1,($2||''));
  }
  return; }

# Not the ideal place for it but... closest that comes to mind!
# Internal utilities:
# Canonicalize absolute URLs, borrowed from LaTeXML::Util::Pathname
our $PROTOCOL_RE = '(?:https?)(?=:)';
sub canonicalize_url {
  my ($pathname) = @_;
  my $urlprefix= undef;
  if($pathname =~ s|^($PROTOCOL_RE)://||){
    $urlprefix = $1; }
  $pathname =~ s|/\./|/|g;
  # Collapse any foo/.. patterns, but not ../..
  while($pathname =~ s|/(?!\.\./)[^/]+/\.\.(/\|$)|$1|){}
  $pathname =~ s|^\./||;
  $pathname =~ s|^www.||;
  # Deprecated: We don't want the prefix, keeps the index smaller
  #(defined $urlprefix ? $urlprefix . $pathname : $pathname); }
  $pathname; }

1;
__END__

=pod 

=head1 NAME

C<NNexus::Morphology> - Basic morphological and canonicalization routines

=head1 SYNOPSIS

  use NNexus::Morphology qw(:all);

  # Possessives
  $boolean = is_possessive($phrase);
  $nonpossesive_phrase = get_nonpossessive($phrase);
  $possessive_phrase = get_possessive($word);

  # Plurals
  $boolean = is_plural($word);
  $plural_phrase = pluralize($phrase);
  $singular_phrase = depluralize_phrase($phrase);
  $singular_word = depluralize_word($word);
  
  # Determiners
  $noun = undetermine_word($noun_phrase);

  # Roots
  $root = root($word);

  # Phrase manipulation
  ($firstword,$tailphrase) = firstword_split($phrase);
  
  # Web and NNexus Resources
  $canonical_url = canonicalize_url($raw_url);
  $boolean = admissible_name($word);
  $normalized_word = normalize_word($word);

=head1 DESCRIPTION

The C<NNexus::Morphology> module provides basic support for morphological operations on English words and phrases.
  While it does not at all claim good linguistic accuracy and recall, it serves the intended purpose of normalizing
  candidate concepts in NNexus to a standard infinitive-like form, free of basic inflections.

In addition the module contains normalization routines for web resources, as well as admissibility checks for words it considers grammatical.

=head2 METHODS

=over 4

=item C<< $boolean = is_possessive($phrase); >>

Returns true if the given phrase is possessive, false otherwise.

=item C<< $nonpossesive_phrase = get_nonpossessive($phrase); >>

Removes possessives from a phrase, if any. Only inspects the leading word.

=item C<< $possessive_phrase = get_possessive($phrase); >>

Adds a possessive suffix to the leading word of a given phrase, or single word.

=item C<<$boolean = is_plural($word); >>

True if word on input is plural, false otherwise.

=item C<< $plural_phrase = pluralize($phrase); >>

Returns the plural of a (noun) phrase, e.g.
  "law of identity" would become "laws of identity"

=item C<< $singular_phrase = depluralize_phrase($phrase); >>

Returns the singular of a (noun) phrase, e.g.
  "laws of identity" would become "law of identity"

=item C<< $singular_word = depluralize_word($word); >>

Returns the singular of a word

=item C<< $undetermined_noun_phrase = undetermine_word($noun_phrase); >>

Removes determiners from a noun phrase.

=item C<< $root = root($word); >>

Heuristic stemming algorithm, returns the root of a given word.

=item C<< ($firstword,$tailphrase) = firstword_split($phrase); >>

Given a phrase, splits out the first word and returns it
  together with the remaining tail of the phrase.

=item C<< $canonical_url = canonicalize_url($raw_url); >>

Transforms a URL to a minimized canonical representation, 
  suitable for storage into the NNexus Database.

=item C<< $boolean = admissible_name($word); >>

Returns true if the word is admissible and false otherwise.
  Currently checks for leftover bad markup, such as LaTeX
  math mode and macros.

=item C<< $normalized_word = normalize_word($word); >>

High-level API to normalize a word down to a canonical representation,
  which could be then matched against the NNexus database.

Performs: unicode-to-ascii dumbing down, lower casing, removal of determiners,
  possessives and plurals.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the MIT License (MIT)

=cut
