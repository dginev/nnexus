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
  return [] if $self->leaf_test($url);
  my $dom = $self->current_dom;
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
use Data::Dumper;
sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  return [] unless $self->leaf_test($url);
  my $dom = $self->current_dom->xml(1);
  my $title = $dom->find('div[property="dct:title"]')->[0];
  return [] unless $title;
  $title = $title->attrs('content');
  # Only concepts have titles, so return an empty harvest if undefined:
  # Also record defined concepts
  my $content_div = $dom->find('section[class="ltx_document"]')->[0];
  return [] unless $content_div;
  my @defined_concepts = $content_div->find('div[property="pm:defines"]')->each;
  my @categories = grep {length($_)>0} map {s/^msc\://; $_;}
    map {$_->attrs('resource')} $content_div->find('div[class="ltx_rdf"][property="dct:subject"]')->each;
  my @synonyms = map {$_->attrs('content')} $content_div->find('div[class="ltx_rdf"][property="pm:synonym"]')->each;

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
sub leaf_test { $_[1] !~ /\/articles/; }

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Planetmath> - Indexing plug-in for the L<PlanetMath.org|http://planetmath.org> domain.

=head1 DESCRIPTION

Indexing plug-in for the PlanetMath.org domain.

See L<NNexus::Index::Template> for detailed indexing documentation.

=head1 SEE ALSO

L<NNexus::Index::Template>

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

  Research software, produced as part of work done by
  the KWARC group at Jacobs University Bremen.
  Released under the MIT License (MIT)

=cut