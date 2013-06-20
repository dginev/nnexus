# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Template for Indexing Plug-ins, PULL API                            | #
# |=====================================================================| #
# | Part of the Planetary project: http://trac.mathweb.org/planetary    | #
# |  Research software, produced as part of work done by:               | #
# |  the KWARC group at Jacobs University                               | #
# | Copyright (c) 2012                                                  | #
# | Released under the MIT License (MIT)                                | #
# |---------------------------------------------------------------------| #
# | Adapted from the original NNexus code by                            | #
# |                                  James Gardner and Aaron Krowne     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev <d.ginev@jacobs-university.de>                  #_#     | #
# | http://kwarc.info/people/dginev                            (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package NNexus::Index::Template;
use warnings;
use strict;

use Mojo::DOM;
use Mojo::UserAgent;
use Time::HiRes qw(sleep);
use NNexus::Morphology qw(canonicalize_url);

### EXTERNAL API
sub new {
  my ($class,%options) = @_;
  my $ua = Mojo::UserAgent->new;
  my $visited = $options{visited}||{};
  my $queue = $options{queue}||[];

  my $self = bless {ua=>$ua,visited=>$visited,queue=>$queue}, $class;

  # Set current if we're starting up.
  my $first_url;
  if (defined $options{start}) {
    if ($options{start} eq 'default') {
      $first_url = $self->domain_root;
    } else {
      $first_url = $options{start};
    }}
  else {
    $first_url = $self->domain_root; }

  push (@{$self->{queue}}, {
      url=>canonicalize_url($first_url),
      ($options{dom} ? (dom=>$options{dom}) : ()),
      depth=>0});
  return $self;
}
sub ua {$_[0]->{ua};}

# index: Traverse a page, obtain candidate concepts and candidate further links
sub index_step {
  my ($self,%options) = @_;
  my $visited = $self->{visited};
  my $depth;

  # Grab the next job from the queue
  my $next_step = $self->next_step;
  if (ref $next_step) {
    $self->current_url($next_step->{url});
    $self->current_categories($next_step->{categories});
    $depth = $next_step->{depth} || 0;
  } else {
    # We're out of urls, last step.
    delete $self->{current_url};
  }
  # If we've visited, or we're out of urls, terminate.
  my $current_url = $self->current_url;
  return unless $current_url; # Empty return for last job
  $visited->{$current_url} = 1; # Mark visited
  # Also skip if we're over the depth limit.
  return $self->index_step if $depth > $self->depth_limit;
  return [] if $options{skip}; # We are skipping over this URL, return
  # 2.1. Prepare (or just accept) a Mojo::DOM to be analyzed
  if ($next_step->{dom}) {
    $self->current_dom($next_step->{dom});
    delete $next_step->{dom};
  } else {
    $self->current_dom($self->ua->get($current_url)->res->dom);
    sleep($self->request_interval()); # Don't overload the server
  }
  # Obtain the indexer payload
  my $payload = $self->index_page;
  # What are the candidate categories for follow-up jobs?
  my $categories = $self->candidate_categories;
  # Push all following candidate jobs to queue
  if ($depth <= $self->depth_limit) { # Don't add pointless nodes
    my $candidate_links = $self->candidate_links;
    foreach (@$candidate_links) {
      # push and shift give us breadth-first search.
      push (@{$self->{queue}}, {
        url=>canonicalize_url($_),
        categories=>$categories,
        depth=>$depth+1});
    }
  }
  # Return final list of concepts for this page
  return $payload;
}

sub next_step {
  my ($self) = @_;
  my $visited = $self->{visited};
  # Otherwise, grab the next job from the queue
  my $next_step = shift @{$self->{queue}};
  while ((ref $next_step) && ($visited->{$next_step->{url}})) {
    $next_step = shift @{$self->{queue}};
  }
  return $next_step;
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
sub request_interval { 2; }
# Tests if the page is a leaf, in which case we want to skip it when should_update is 0
sub leaf_test {0;}
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

  # You can now invoke an indexing run from your own code:
  $indexer = NNexus::Index::Mydomain;
  $first_payload = $indexer->index_step('start'=>'default');
  while (my $concept_payload = $indexer->index_step ) {
    # Do something with the indexed concepts...
  }

=head1 DESCRIPTION

This class contains the generic NNexus indexing logic, and offers the PULL API for concrete domain indexers.
  There are three categories of methods:

=over 2

=item *

External API - public methods, to be used to set up and drive the indexing process

=item *

Shared methods - defining the generic crawl process and logic, shared by all domain indexers

=item *

PULL API - per-page data-mining methods, to be overloaded by concrete domain indexers

=back 

=head2 EXTERNAL API

=over 4

=item C<< $indexer = NNexus::Index::Mydomain->new(start=>'default',dom=>$dom); >>

The most reliable way to instantiate a domain indexer. The 'Mydomain' string is conventionally
  the shorthand name a certain site is referred by, e.g. Planetmath, Wikipedia, Dlmf or Mathworld. 

As a handy convention, all plug-in indexer names C<$domain> should be compliant with
  C<$domain eq ucfirst(lc($domain))>

=item C<< $payload = $indexer->index_step; >>

While the index_step method is the main externally-facing interface method,
  it is also the most important shared method between all domain indexers,
  as it automates the crawling and PULL processes.

The index_step method is the core of the indexing logic behind NNexus. It provides:

=over 2

=item *

Automatic crawling under the specified C<start> domain root.

=item *

Fine-tuning of crawl targets. C<start> can be both the C<default> for the domain, as well as any specific URL.

=item *

Indexing as iteration. Each NNexus indexer object contains an iterator, which can be stepped through.
   The traversal is left-to-right and depth-first.

=item *

The indexing is bound by depth (if requested) and keeps a cache of visited pages, avoiding loops.

=item *

An automatic one second sleep is triggered whenever a page is fetched, in good crawling manners.

=back

The only option accepted by the method is a boolean switch C<skip>, which when turned on skips the next job in
  the queue.

=back

=head2 SHARED METHODS

=over 4

=item C<< $url = $self->current_url >>

Getter, provides the current URL of the page being indexed. 
  Dually acts as a setter when an argument is provided,
  mainly set from the F<index_step> method.

=item C<< $dom = $self->current_dom >>

Getter, provides the current L<Mojo::DOM> of the page being indexed. 
  Dually acts as a setter when an argument is provided,
  mainly set from the F<index_step> method.

=item C<< $dom = $self->current_categories >>

Getter, provides the current categories of the page being indexed. 
  Dually acts as a setter when an argument is provided,
  mainly set from the F<index_step> method.

The categories are a reference to an array of strings, ideally of MSC classes.

The main use of this method is for sites setup similarly to Wikipedia, where a sub-categorization scheme
  is being traversed and the current categories need to be remembered whenever a new leaf concept page is entered.
  See L<NNexus::Index::Wikipedia> for examples.

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
    
  { concept => 'concept name',
    url => 'origin url',
    synonyms => [ qw(list of synonyms) ],
    categories => [ qw(list of categories) ],
    # ... TODO: More?
  }
  
=item C<< sub candidate_categories {...} >>

Propose candidate categories for the current page, using the shared methods.
  Useful in cases where the category information of a concept is not recorded in the same page, but
  has to be inferred instead, as is the case for Wikipedia's traversal process.
  See L<Index::Template::Wikipedia> for an example of overriding F<candidate_categories>.

=item C<< sub depth_limit { $depth; } >>

An integer constant specifying a depth-limit for the crawling process, wrt to the start URL provided.
  Useful for heavily interlinked sites, such as Wikipedia, in which as depth increases, the topicality
  of the indexed subcategories decreases.

=item C<< sub request_interval { $seconds; } >>

Any L<Time::Hires> admissible constant amount of C<$seconds>.
  To be used for putting the current process to sleep, in order to
  avoid overloading the indexed server, as well as to avoid getting banned.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by
 the KWARC group at Jacobs University Bremen.
 Released under the MIT license (MIT)

=cut
