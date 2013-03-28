package NNexus::Index::Dispatcher;
use NNexus::Util;
use warnings;
use strict;

# Dispatch to the right NNexus::Index::Domain class
sub new {
  my ($class,%options) = @_;
  my $domain = $options{domain};
  my $db = $options{db};
  $domain = $domain ? ucfirst(lc($domain)) : 'Planetmath';
  die ("Bad domain name: $domain; Must contain only alphanumeric characters!") if $domain =~ /\W/;
  my $index_template;
  my $eval_return = eval {require "NNexus/Index/$domain.pm"; 1; };
  if ($eval_return && (!$@)) {
    $index_template = eval " NNexus::Index::$domain->new(); "
  } else {
    print STDERR "NNexus::Index::$domain not available, fallback to generic indexer.\n";
    print STDERR "Reason: $@\n" if $@;
    require NNexus::Index::Template;
    # The generic template will always fail...
    # TODO: Should we fallback to Planetmath instead?
    $index_template = NNexus::Index::Template->new;
  }

  bless {index_template=>$index_template,domain=>$domain,db=>$db}, $class;
}

sub index_step {
  my ($self,%options) = @_;
  # 1. Relay the indexing request to the template, gather concepts
  my $template = $self->{index_template};
  my $db = $self->{db};
  my $concepts = $template->index_step(%options);
  return unless defined $concepts; # Last step.
  # NOTE: Indexing is the **ONLY** stage in NNexus processing where there are write operations to the backend
  # 2. Check if object has already been indexed:
  my $url = $template->current_url; # Grab the current canonical URL
  
  # 2.1. If yes, grab all concepts defined by it.
  # 2.2. Delete the object from the DB
  # 3. Compute diff between previous and new concepts
  # 3.1. Flatten out synonyms as individual concepts
  # 4. Delete no longer present concepts
  # 5. Add newly introduced concepts
  
  # 6. Return URLs to be invalidated as effect:
  my $invalidated_URLs = [];
  return $invalidated_URLs;
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
