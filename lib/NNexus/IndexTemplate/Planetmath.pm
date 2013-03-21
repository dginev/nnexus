package NNexus::IndexTemplate::Planetmath;
use warnings;
use strict;
use base qw(NNexus::IndexTemplate);

# Wikipedia.org indexing template
# 1. We want to start from the top-level math category

sub domain_root { "http://planetmath.org/articles"; }
sub candidate_links {
  # TODO: Retrieve candidate links from a given HTML page. 
  #qr/^http\:\/\/en\.wikipedia\.org\/wiki\/([^\:]+)$/;
}
sub index_page {
  my ($self) = @_;
  
}

sub depth_limit {500;}

1;
__END__