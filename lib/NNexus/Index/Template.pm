package NNexus::Index::Template;
use warnings;
use strict;
use Mojo::DOM;
use Mojo::UserAgent;
use Data::Dumper;

### EXTERNAL API
sub new {
	my ($class,%options) = @_;
	my $ua = Mojo::UserAgent->new;
	my $visited = $options{visited}||{};
	my $queue = $options{queue}||[];
	bless {ua=>$ua,visited=>$visited,queue=>$queue,start=>$options{start}}, $class;
}
sub ua {$_[0]->{ua};}

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
      $self->current_categories($next_step->{categories});
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
  # What are the candidate categories for follow-up jobs?
  my $categories = $self->candidate_categories;
	# Push all following candidate jobs to queue
  if ($depth <= $self->depth_limit) { # Don't add pointless nodes
    my $candidate_links = $self->candidate_links;
    foreach (@$candidate_links) {
      unshift (@{$self->{queue}}, {
        url=>$_,
        categories=>$categories,
        depth=>$depth+1});
    }
  }
  # TODO : Comment this out when stable.
  print STDERR "Payload:\n",Dumper($payload);
  # Return final list of concepts for this page
  return $payload;
}

### PULL API
# To be overloaded by concrete classes
sub depth_limit {4;}
sub domain_root {q{};} # To be overriden in the concrete classes
# TODO: Rename index_page to candidate_concepts ? Or index_links / index_categories instead?
sub index_page {[];} # To be overriden in the concrete classes
sub candidate_links {
	[];
	# TODO: Generic implementation should simply retrieve ALL <a href>s as candidate links.
}
sub candidate_categories {}

### SHARED METHODS
# To be directly inherited and used by concrete classes

# Getter or Setter for the current URL/DOM/Categories
sub current_url { $_[1] ? $_[0]->{current_url} = $_[1] : $_[0]->{current_url}; }
sub current_dom { $_[1] ? $_[0]->{current_dom} = $_[1] : $_[0]->{current_dom}; }
sub current_categories {$_[1] ? $_[0]->{current_categories} = $_[1] : $_[0]->{current_categories};}

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Template> - Foundation Template for NNexus Domain Indexers

=head1 SYNOPSIS

package NNexus::Index::Mydomain;
use base qw(NNexus::Index::Template);

# Instantiate the PULL API methods
sub domain_root { 'http://mydomain.com' }
sub candidate_links { ... }
sub index_page { ... }
sub depth_limit { 10; }

1;

# Then from outside e.g. from inside a NNexus::Job, invoke:
my $indexer = NNexus::Index::Dispatcher->new('mydomain');
my $first_payload = $indexer->index_step('start'=>'default');
while (my $concept_payload = $indexer->index_step ) {
 # Do something with the indexed concepts...
}

=head1 DESCRIPTION

This class contains the generic NNexus indexing logic, and offers the PULL API for concrete domain indexers.
  There are three categories of methods:
  - External API - public methods, to be used to set up and drive the indexing process
  - Shared methods - defining the generic crawl process and logic, shared by all domain indexers
  - PULL API - per-page data-mining methods, to be overloaded by concrete domain indexers

=head2 EXTERNAL API

=over 4

=item C<< my $indexer = NNexus::Index::Dispatcher->new('mydomain'); >>

The most reliable way to instantiate a domain indexer. The 'mydomain' string is conventionally the shorthand
name a certain site is referred by, e.g. Wikipedia, DLMF or Mathworld. 

=item C<< my $payload = $indexer->index_step('start'=>'default'); >>

While the index_step method is the main externally-facing interface method, it is also the most important shared
  method between all domain indexers, as it automates the crawling and PULL processes.

The index_step method is the core of the indexing logic behind NNexus. It provides:
 - Automatic crawling under the specified 'start' domain root.
 - Fine-tuning of crawl targets. 'start' can be both the 'default' for the domain, as well as any specific URL.
 - Indexing as iteration. Each NNexus indexer object contains an iterator, which can be stepped through.
   The traversal is left-to-right and depth-first.
 - The indexing is bound by depth (if requested) and keeps a cache of visited pages, avoiding loops.
 - An automatic one second sleep is triggered whenever a page is fetched, in good crawling manners.

=back

=head2 SHARED METHODS

=over 4

=item C<< my $url = $self->current_url >>

Getter, provides the current URL of the page being indexed. 
  Dually acts as a setter when an argument is provided,
  mainly set from the index_step method.

=item C<< my $dom = $self->current_dom >>

Getter, provides the current Mojo::DOM of the page being indexed. 
  Dually acts as a setter when an argument is provided,
  mainly set from the index_step method.

=item C<< my $dom = $self->current_categories >>

Getter, provides the current categories of the page being indexed. 
  Dually acts as a setter when an argument is provided,
  mainly set from the index_step method.

The categories are a reference to an array of strings, ideally of MSC classes.

The main use of this method is for sites setup similarly to Wikipedia, where a sub-categorization scheme
  is being traversed and the current categories need to be remembered whenever a new leaf concept page is entered.
  See NNexus::Index::Wikipedia for examples.

=back

=head2 PULL API

All PULL API methods are intended to be overridden in each concrete domain indexer,
  with occasional exceptions, where the default behaviour (if any) suffices.

=over 4

=item C<< sub domain_root { 'http://mydomain.org' } >>

Sets the default start URL for an indexing process of the entire domain.

=item C<< sub candidate_links {...} >>

Using the information provided by the shared methods,
  datamine zero or more candidate links for further indexing.

  The expected return value is a reference to an array of absolute URL strings.
  
=item C<< sub index_page {...} >>

Using the information provided by the shared methods,
  datamine zero or more candidate concepts for NNexus indexing.
  
  The expected return value is a reference to an array of hash-references,
  each hash-reference being a concept hash datastructure, specified as:
  	
  { canonical => 'concept name',
    url => 'origin url',
    synonyms => [ qw(list of synonyms) ],
    categories => [ qw(list of categories) ],
    # ... TODO: More?
  }
  
=item C<< sub candidate_categories {...} >>

Propose candidate categories for the current page, using the shared methods.
  Useful in cases where the category information of a concept is not recorded in the same page, but
  has to be inferred instead, as is the case for Wikipedia's traversal process.
  
  See Index::Template::Wikipedia for an example of overriding candidate_categories.

=item C<< sub depth_limit { 10; } >>

An integer constant specifying a depth-limit for the crawling process, wrt to the start URL provided.
  Useful for heavily interlinked sites, such as Wikipedia, in which as depth increases, the topicality
  of the indexed subcategories decreases.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Research software, produced as part of work done by
the KWARC group at Jacobs University Bremen.
Released under the GNU Public License

=cut
