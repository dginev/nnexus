package NNexus::IndexTemplate::Planetmath;
use warnings;
use strict;
use base qw(NNexus::IndexTemplate);

# Wikipedia.org indexing template
# 1. We want to start from the top-level math category

sub domain_root { "http://planetmath.org/articles"; }
sub page_regexp { qr/^http\:\/\/en\.wikipedia\.org\/wiki\/([^\:]+)$/; }
sub candidate_links {
	# TODO: Retrieve candidate links from a given HTML page. 
	#qr/^http\:\/\/en\.wikipedia\.org\/wiki\/([^\:]+)$/;
}
sub index { print STDERR "TODO: Planetmath indexer\n";}

1;
__END__