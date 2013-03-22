package NNexus::IndexDispatcher;
use warnings;
use strict;

# 1. Set all default values, 
sub new {
	my ($class,$domain) = @_;
	$domain = $domain ? ucfirst(lc($domain)) : 'Planetmath';
	die ("Bad domain name: $domain; Must contain only alphanumeric characters!") if $domain =~ /\W/;
	my $eval_return = eval {require "NNexus/Index/$domain.pm"; 1; };
	if ($eval_return && (!$@)) {
		eval " NNexus::Index::$domain->new(); "
	} else {
		print STDERR "NNexus::Index::$domain not available, fallback to generic indexer.\n";
		print STDERR "Reason: $@\n" if $@;
		require NNexus::Index::Template;
		# The generic template will always fail...
		# TODO: Should we fallback to Planetmath instead?
		NNexus::Index::Template->new();
	}
}

1;
__END__