# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Concept Manipulation and Lookup Module                              | #
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
package NNexus::Concepts;
use strict;
use warnings;

use NNexus::Morphology qw(is_possessive is_plural normalize_word);
use Encode qw( is_utf8 );
use Exporter;
use List::MoreUtils qw(uniq);

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(flatten_concept_harvest diff_concept_harvests clone_concepts links_from_concept);

sub flatten_concept_harvest {
  my ($indexed_concepts) = @_;
  my $new_concepts=[];
  foreach my $c(@$indexed_concepts) {
    my $synonyms = delete $c->{synonyms}||[];
    my $categories = delete $c->{categories}||[];
    my @all_names = (@$synonyms, $c->{concept});
    # Extend to normalized names:
    @all_names = map {
      join(' ', grep {$_} map { normalize_word($_) } split(/\s+/,$_))
    } @all_names;
    # In case some of the synonyms were misguidedly normalizing, let's get the unique elements:
    @all_names = uniq(@all_names);
    # Flatten names
    my @synset = map {my %syn = %$c; $syn{concept}=$_; \%syn;} @all_names;
    # Flatten categories
    my @catset;
    foreach my $sync (@synset) {
      push @catset, map {my %cat = %$sync; $cat{category}=$_; \%cat;} @$categories;
    }
    push @$new_concepts, @catset;
  }
  return $new_concepts;
}

sub diff_concept_harvests {
  my ($old_concepts,$new_concepts) = @_;
  my $delete_concepts=[];
  my $add_concepts = [@$new_concepts];
  while (@$old_concepts) {
    my $c = shift @$old_concepts;
    my $cname = $c->{concept};
    my $ccat = $c->{category};
    my @filtered_new = grep {($_->{concept} ne $cname) ||
              ($_->{category} ne $ccat)} @$add_concepts;
    if (scalar(@filtered_new) == scalar(@$add_concepts)) {
      # Not found, delete $c
      push @$delete_concepts, $c;
    } else {
      # Found, next
      $add_concepts = \@filtered_new;
    }
  }
  return ($delete_concepts,$add_concepts);
}

sub clone_concepts {
  my ($concepts) = @_;
  # Shallow clone suffices
  [map { {%$_} } @$concepts];
}

sub links_from_concept {
  my ($concept) = @_;
  my @links = ();
  @links = ($concept->{link}) if $concept->{link};
  # Also include multilinks, if any:
  if ($concept->{multilinks}) {
    my @multi = @{$concept->{multilinks}};
    while (@multi) {
      my $next_link = shift @multi;
      next if (grep {$_ eq $next_link} @links);
      push @links, $next_link;
    }
  }
  return @links; }

1;

__END__

=pod 

=head1 NAME

C<NNexus::Concepts> - API for Manipulation of NNexus Concepts and Concept harvests

=head1 SYNOPSIS

  use NNexus::Concepts qw(flatten_concept_harvest diff_concept_harvests clone_concepts links_from_concept);
  $new_concepts = flatten_concept_harvest($indexed_concepts);
  ($delete_concepts,$add_concepts) = diff_concept_harvests($old_concepts,$new_concepts);
  $cloned_concepts = clone_concepts($concepts);
  @links = links_from_concept($concept);

=head1 DESCRIPTION

This package contains a range of convenience utilities for accessing and mainpulating NNexus concepts,
  realized via Perl hash references.

An Indexed concept is a hashref of the form:

  {
    categories => [ list of categories ],
    scheme => 'categorization scheme',
    concept => 'natural language word or phrase',
    synonyms => [ list of synonym words and phrases ],
    url => 'http://example.com'
  }

A Flattened concept is a simplified hashref of the form:

  {
    category => 'a single category',
    scheme => 'categorization scheme',
    concept => 'natural language word or phrase'
    url => 'http://example.com'
  } 

Another finer point is that when a concept is being registered,
  its resource/object of origin is contained in a hash key "url".
  When it is being registered and later retrieved from the NNexus
  knowledge base, that key is renamed to "link" and potentially
  "multilinks", when several URLs exist for the same concept.
  The distinction is useful to discern between the processing stages,
  but could also be refactored away at a later stage.

=head2 METHODS

=over 4

=item C<< $new_concepts = flatten_concept_harvest($indexed_concepts); >>

Given a list of indexed concepts with their synonyms, this routine flattens
  them into a simple array of concepts and performs morphological normalization on
  the natural language phrases, as provided by L<NNexus::Morphology>.

=item C<< ($delete_concepts,$add_concepts) = diff_concept_harvests($old_concepts,$new_concepts); >>

Given two arrays of old and new (flattened) concepts, the routine computes their difference,
  returning a list of concepts to be deleted (i.e. exclusively old) and a list of concepts
  to be added (i.e. exclusively new).

=item C<< $cloned_concepts = clone_concepts($concepts); >>

Clones the concept hash and returns the new hash reference.
  Works on an array reference of concepts, as we tend to clone in bulk.

=item C<< @links = links_from_concept($concept); >>

Smart extraction of links from a concept hashref, supports both
  the single "link" key as well as the bulk "multilinks" field.
  Returns an array of URL strings.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the MIT License (MIT)

=cut
