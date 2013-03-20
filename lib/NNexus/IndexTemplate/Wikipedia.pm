package NNexus::IndexTemplate::Wikipedia;
use warnings;
use strict;
use base qw(NNexus::IndexTemplate);
use feature 'say';

# Wikipedia.org indexing template
# 1. We want to start from the top-level math category

sub domain_root { "http://en.wikipedia.org/wiki/Category:Mathematics"; }
sub candidate_links {
  my ($self)=@_;
  my $dom = $self->current_dom;
  $dom->find('a')->each(sub {say shift->{href}});
	# TODO: Retrieve candidate links from a given HTML page. 
	#qr/^http\:\/\/en\.wikipedia\.org\/wiki\/([^\:]+)$/;
}
sub index_page { 
  my ($self) = @_;
  my $dom = $self->current_dom;
}

1;
__END__