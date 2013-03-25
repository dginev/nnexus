package NNexus::Index::Dispatcher;
use warnings;
use strict;

# Dispatch to the right NNexus::Index::Domain class
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
		NNexus::Index::Template->new;
	}
}

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Dispatcher> - High-level dispatcher to the correct domain indexer classes.

=head1 SYNOPSIS

use NNexus::Index::Dispatcher;
my $indexer = NNexus::Index::Dispatcher->new($domain);

=head1 DESCRIPTION

Simple interface to obtaining the correct indexer class for a given domain.

TODO: The intention is to also extend the capabilities of the dispatcher to auto-detect and report on
  the available domain indexers and their properties (Meta-object Programming (MOP)).

=head2 METHODS

=over 4

=item C<< my $indexer = NNexus::Index::Dispatcher->new($domain); >>

Returns an object of NNexus::Index::ucfirst(lc($domain)) if available, or the generic Template object otherwise.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Research software, produced as part of work done by
the KWARC group at Jacobs University Bremen.
Released under the GNU Public License

=cut
