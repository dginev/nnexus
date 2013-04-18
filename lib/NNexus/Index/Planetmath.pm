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
  my $title = $dom->find('div[property="dct:title"]')->[0];
  # Only concepts have titles, so consider next links IF undefined:
  return [] if $title;
  # Encyclopedia entries are root links "/entry"
  my $content = $dom->find('div[class="view-content"]')->[0];
  my @encyclopedia_links = $content ? $content->find('a')->each : ();
  @encyclopedia_links = grep {defined && /^\/(\w+)$/} map {$_->{href}} @encyclopedia_links;
  # Further links can be found in: "/articles?section=All&amp;page=NUMBER"
  my $navigation = $dom->find('div[class="item-list"]')->[1];
  my @nav_links = $navigation ? $navigation->find('a')->each : ();
  @nav_links = grep {defined && /^\/articles\?section=All\&amp;page=\d+$/} map {$_->{href}} @nav_links;
  my $candidates = [ map { $pm_base . $_ } (@nav_links, @encyclopedia_links ) ];
  return $candidates
}
use Data::Dumper;
sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom->xml(1);
  my $title = $dom->find('div[property="dct:title"]')->[0];
  # Only concepts have titles, so return an empty harvest if undefined:
  return [] unless defined $title;
  my $name = $title->attrs('content');
  #->[0]->attrs('content')->pluck('all_text');
  my @categories = map {$_->attrs('resource')} $dom->find('div[class="ltx_rdf"][property="dct:subject"]')->each;
  return [{
    url=>$url,
    concept=>$name,
    categories=>\@categories,
    }];
}

sub depth_limit {10;}

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Planetmath> - Concrete Indexer for the PlanetMath.org domain.

=head1 DESCRIPTION

Concrete indexer for the PlanetMath.org domain.
See C<NNexus::Index::Template> for detailed indexing documentation.

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Research software, produced as part of work done by
the KWARC group at Jacobs University Bremen.
Released under the GNU Public License

=cut
