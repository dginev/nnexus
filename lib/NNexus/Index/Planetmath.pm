package NNexus::Index::Planetmath;
use warnings;
use strict;
use base qw(NNexus::Index::Template);

sub domain_root { "http://planetmath.org/articles"; }
sub candidate_links {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  [];
}
use Data::Dumper;
sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom->xml(1);
  my $name = $dom->find('div[property="dct:title"]')->[0]->attrs('content');
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
