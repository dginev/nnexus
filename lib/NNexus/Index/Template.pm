package NNexus::Index::Template;
use warnings;
use strict;
use Mojo::DOM;
use Mojo::UserAgent;
use Data::Dumper;

### GENERIC METHODS
# To be directly inherited and used by concrete classes

sub new {
	my ($class,%options) = @_;
	my $ua = Mojo::UserAgent->new;
	my $visited = $options{visited}||{};
	my $queue = $options{queue}||[];
	bless {ua=>$ua,visited=>$visited,queue=>$queue,start=>$options{start}}, $class;
}
sub ua {$_[0]->{ua};}

# Getter or Setter for the current URL to be indexed
sub current_url { $_[1] ? $_[0]->{current_url} = $_[1] : $_[0]->{current_url}; }
sub current_dom { $_[1] ? $_[0]->{current_dom} = $_[1] : $_[0]->{current_dom}; }
sub current_category {$_[1] ? $_[0]->{current_category} = $_[1] : $_[0]->{current_category};}

# index: Traverse a page, obtain candidate concepts and candidate further links
sub index_step {
	my ($self,%options) = @_;
  my $depth;
	 # Set current if we're starting up.
	if (defined $options{start}) {
		if ($options{start} eq 'default') {
      $self->current_url($self->domain_root);
		} else {
			$self->current_url($options{start});
		}
    $depth=0;
		delete $options{start};
	} else {
   # Otherwise, grab the next job from the queue
		my $next_step = shift @{$self->{queue}};
    if (ref $next_step) {
		  $self->current_url($next_step->{url});
      $self->current_category($next_step->{category});
      $depth = $next_step->{depth};
    } else {
      # We're out of urls, last step.
      delete $self->{current_url};
    }
	}
  # If we've visited, or we're out of urls, terminate.
  my $current_url = $self->current_url;
  return unless $current_url; # Empty return for last job
  if (!($self->{visited}->{$current_url})) {
    $self->{visited}->{$current_url} = 1;
  } else {
    # Empty array-ref for visited URL.
    return [];
  }
  # Also done if we're over the depth limit.
  return [] if $depth > $self->depth_limit;
  print STDERR "Indexing $current_url\n";
	# 2.1. Prepare (or just accept) a Mojo::DOM to be analyzed
	if ($options{dom}) {
		$self->current_dom($options{dom});
		delete $options{dom};
	} else {
		$self->current_dom($self->ua->get($current_url)->res->dom);
		sleep 1; # Don't overload the server
	}
  # Obtain the indexer payload
  my $payload = $self->index_page;
  # What is the candidate category for follow-up jobs?
  my $category = $self->candidate_category;
	# Push all following candidate jobs to queue
  if ($depth <= $self->depth_limit) { # Don't add pointless nodes
    my $candidate_links = $self->candidate_links;
    foreach (@$candidate_links) {
      unshift (@{$self->{queue}}, {
        url=>$_,
        category=>[$category],
        depth=>$depth+1});
    }
  }
  # TODO : Comment this out when stable.
  print STDERR "Payload:\n",Dumper($payload);
  # Return final list of concepts for this page
  return $payload;
  # We want to return a list of hashes:
  # [
  #   { URL => $url,
  #	  canonical => $canonical,
  #     NLconcept => $concepts,
  #     category => $category 
  #   }, ...
  # ]
}

### CONCRETE METHODS
# To be overloaded by concrete classes

sub depth_limit {4;}
sub domain_root {q{};} # To be overriden in the concrete classes
sub index_page {[];} # To be overriden in the concrete classes
sub candidate_links {
	[];
	# TODO: Generic implementation should simply retrieve ALL <a href>s as candidate links.
}
sub candidate_category {}

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Template> - Foundation Template for NNexus Domain Indexers

=head1 SYNOPSIS

package NNexus::Index::Mydomain;
use base qw(NNexus::Index::Template);

sub domain_root { 'http://mydomain.com' }
sub candidate_links { ... }
sub index_page { ... }
sub depth_limit { 10; }

1;

# Then from e.g. a NNexus::Job invoke:
my $indexer = NNexus::Index::Dispatcher->new('mydomain');
my $first_payload = $indexer->index_step('start'=>'default');
while (my $concept_payload = $indexer->index_step ) {
 # Do something with the indexed concepts...
}

=head1 DESCRIPTION

This class contains the generic NNexus indexing logic, and offers the PULL API for concrete domain indexers.
  There are three categories of methods:
  - Core methods - defining the generic crawl process and logic
  - PULL API - methods to be overloaded by concrete domain indexers
  - External API - public methods, to be used to set up and drive the indexing process.

=head2 CORE METHODS

=over 4

=item C<Write more>

=back

=head2 PULL API

=over 4

=item C<Write more>

=back

=head2 EXTERNAL API

=over 4

=item C<Write more>

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Research software, produced as part of work done by
the KWARC group at Jacobs University Bremen.
Released under the GNU Public License

=cut
