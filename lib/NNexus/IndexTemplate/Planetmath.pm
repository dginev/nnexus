package NNexus::IndexTemplate::Planetmath;
use warnings;
use strict;
use base qw(NNexus::IndexTemplate);

sub domain_root { "http://planetmath.org/articles"; }
sub candidate_links {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;

}
sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  
}

sub candidate_category {

}

sub depth_limit {500;}

1;
__END__