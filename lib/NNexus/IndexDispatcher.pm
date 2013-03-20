package NNexus::IndexDispatcher;
use warnings;
use strict;

# 1. Set all default values, 
sub new {
	my ($class,$domain) = @_;
	$domain = $domain ? ucfirst(lc($domain)) : 'Planetmath';
	my $eval_return = eval {require "NNexus/IndexTemplate/$domain.pm"; 1; };
	if ($eval_return && (!$@)) {
		bless {}, "NNexus::IndexTemplate::$domain";
	} else {
		print STDERR "NNexus::IndexTemplate::$domain not available, fallback to generic indexer...\n";
		require NNexus::IndexTemplate;
		# The generic template will always fail...
		# TODO: Should we fallback to Planetmath instead?
		bless {}, "NNexus::IndexTemplate";
	}
}

1;
__END__