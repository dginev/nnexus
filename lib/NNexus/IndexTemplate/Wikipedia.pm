package NNexus::IndexTemplate::Wikipedia;
use warnings;
use strict;
use base qw(NNexus::IndexTemplate);

# Wikipedia.org indexing template
# 1. We want to start from the top-level math category

sub domain_root { "http://en.wikipedia.org/wiki/Category:Mathematics"; }
sub candidate_links {
	# TODO: Retrieve candidate links from a given HTML page. 
	#qr/^http\:\/\/en\.wikipedia\.org\/wiki\/([^\:]+)$/;
}
sub index { print STDERR "TODO: Wiki indexer\n";}

1;
__END__