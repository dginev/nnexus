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
    canonical=>$name,
    category=>[@categories],
    }];
}

sub depth_limit {10;}

1;
__END__