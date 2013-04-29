# /=====================================================================\ #
# | NNexus Autolinker                                                   | #
# | Indexing Plug-in, PlanetMath.org domain                             | #
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
package NNexus::Index::Planetmath;
use warnings;
use strict;
use base qw(NNexus::Index::Template);

sub domain_root { "http://planetmath.org/articles"; }
our $pm_base="http://planetmath.org";
sub candidate_links {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  return [] if $self->leaf_test();
  # Encyclopedia entries are root links "/entry"
  my $content = $dom->find('div[class="view-content"]')->[0];
  my @encyclopedia_links = $content ? $content->find('a')->each : ();
  @encyclopedia_links = grep {defined && /^\/(\w+)$/} map {$_->{href}} @encyclopedia_links;
  # Further links can be found in: "/articles?section=All&amp;page=NUMBER"
  my $navigation = $dom->find('div[class="item-list"]')->[1];
  my @nav_links = $navigation ? $navigation->find('a')->each : ();
  @nav_links = grep {defined && /^\/articles\?section=All/} map {$_->{href}} @nav_links;
  my $candidates = [ map { $pm_base . $_ } (@nav_links, @encyclopedia_links ) ];
  return $candidates
}

sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom->xml(1);
  my $title = $self->leaf_test();
  # Only concepts have titles, so return an empty harvest if undefined:
  return [] unless $title;
  # Also record defined concepts
  my @defined_concepts = $dom->find('div[property="pm:defines"]')->each;
  $title = $title->attrs('content');
  my @categories = grep {length($_)>0} map {s/^msc\://; $_;}
    map {$_->attrs('resource')} $dom->find('div[class="ltx_rdf"][property="dct:subject"]')->each;
  my @synonyms = map {$_->attrs('content')} $dom->find('div[class="ltx_rdf"][property="pm:synonym"]')->each;

  my @harvest;
  @categories = ('XX-XX') unless @categories;
  foreach my $defined(@defined_concepts) {
    my $name = $defined->attrs('content');
    $name =~ s/^pmconcept\://;
    # TODO: No special chars
    # Wild chars in synonyms - people use TeX math syntax, e.g. ^, $, + ... should we LaTeXML-convert?
    # Right now we just skip over...
    push @harvest, {
		    url=>$url,
		    concept=>$name,
		    categories=>\@categories,
		   }; }
  # Title with synonyms:
  push @harvest, {
		  url=>$url,
		  concept=>$title,
		  categories=>\@categories,
		  synonyms=>\@synonyms
		 };
  return \@harvest;
}

sub depth_limit {10000;} #We're just traversing down the list of pages, nothing dangerous here
sub request_interval {0.5;}
# Only concepts have titles, so consider next links IF undefined:
sub leaf_test { $_[0]->current_dom->find('div[property="dct:title"]')->[0]; }

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Planetmath> - Indexing plug-in for the PlanetMath.org domain.

=head1 DESCRIPTION

Indexing plug-in for the PlanetMath.org domain.
See C<NNexus::Index::Template> for detailed indexing documentation.

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Research software, produced as part of work done by
the KWARC group at Jacobs University Bremen.
Released under the MIT License (MIT)

=cut