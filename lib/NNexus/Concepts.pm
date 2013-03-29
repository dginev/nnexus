# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Concept Manipulation and Lookup Module                              | #
# |=====================================================================| #
# | Part of the Planetary project: http://trac.mathweb.org/planetary    | #
# |  Research software, produced as part of work done by:               | #
# |  the KWARC group at Jacobs University                               | #
# | Copyright (c) 2012                                                  | #
# | Released under the GNU Public License                               | #
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

use NNexus::Morphology qw(is_possessive is_plural get_nonpossessive depluralize);
use Encode qw( is_utf8 );

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_possible_matches flatten_concept_harvest diff_concept_harvests);

sub flatten_concept_harvest {
  my ($indexed_concepts) = @_;
  my $new_concepts=[];
  foreach my $c(@$indexed_concepts) {
    my $synonyms = delete $c->{synonyms}||[];
    my $categories = delete $c->{categories}||[];
    my @all_names = (@$synonyms, $c->{concept});
    # Extend to normalized names:
    @all_names = @all_names,
      (map {get_nonpossesive($_)} grep {is_possessive($_)} @all_names),
      (map {depluralize($_)} grep {is_plural($_)} @all_names);
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


#get a hasharray of concepts (and synonyms) this object defines from the concepthash
sub getconcepts {
  my ($db,$objid) = @_;

  #get the concepts
  my $sth = $db->prepare("SELECT concept from concepthash where objectid = ?");
  $sth->execute( $objid );

  my @concepts = ();

  #mark the concept as active
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @concepts, $row->{'concept'};
  }

  return \@concepts;
}


#
# get the possible matches based on the first word of a concept
# returns as an array containing a hash with newterm
#
sub get_possible_matches {
  my ($db,$word) = @_;
  my @matches = ();

  my ($start, $finish, $DEBUG);
  $DEBUG = 0;

  if ($DEBUG) {
    $start = time();
  }

  #print "Started with $word\n";
  if (is_possessive($word) ) {
    $word = get_nonpossessive($word);
  }
  if ( is_plural( $word ) ) {
    $word = depluralize($word);
  }

  my $sth = $db->prepare("SELECT firstword, concept, objectid from concepthash where firstword=?");
  $sth->execute($word);
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @matches, $row;
  }

  if ($DEBUG) {
    $finish = time();
    my $total = $finish - $start;
    print "get_possible_matches: $total seconds\n";
  }
  return @matches;
}

# Update the concepts for object based on internal objid.
sub addconcepts {
  my $objid = shift;
  my $concepts = shift;

  foreach my $c (@{$concepts}) {
    addterm( $objid, $c );
  }
}

1;

__END__
