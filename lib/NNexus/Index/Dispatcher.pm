# /=====================================================================\ #
# | NNexus Autolinker                                                   | #
# | Indexing Driver,                                                    | #
# |   Dispatcher for Crawl, Store, Invalidation tasks                   | #
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
package NNexus::Index::Dispatcher;
use warnings;
use strict;
use Data::Dumper;
use NNexus::Concepts qw(flatten_concept_harvest diff_concept_harvests);
use NNexus::Morphology qw(admissible_name);

# Dispatch to the right NNexus::Index::Domain class
sub new {
  my ($class,%options) = @_;
  my $domain = $options{domain};
  my $db = $options{db};
  $domain = $domain ? ucfirst(lc($domain)) : '';
  die ("Bad domain name: $domain; Must contain only alphanumeric characters!") if $domain =~ /\W/;
  my $index_template;
  my $should_update = $options{should_update} // 1;
  my $eval_return = eval {require "NNexus/Index/$domain.pm"; 1; };
  if ($eval_return && (!$@)) {
    $index_template = eval {
      "NNexus::Index::$domain"->new(start=>$options{start},dom=>$options{dom},should_update=>$should_update);
    };
  } else {
    print STDERR "NNexus::Index::$domain not available, fallback to generic indexer.\n";
    print STDERR "Reason: $@\n" if $@;
    require NNexus::Index::Template;
    # The generic template will always fail...
    # TODO: Should we fallback to Planetmath instead?
    $index_template = NNexus::Index::Template->new(start=>$options{start},dom=>$options{dom},should_update=>$should_update);
  }

  bless {index_template=>$index_template,domain=>$domain,db=>$db,
	verbosity=>$options{verbosity}||0,should_update=>$should_update}, $class;
}

sub index_step {
  my ($self,%options) = @_;
  my $template = $self->{index_template};
  my $db = $self->{db};
  my $domain = $self->{domain};
  my $verbosity = $options{verbosity} ? $options{verbosity} : $self->{verbosity};
  # 1. Check if object has already been indexed:
  my $next_step = $template->next_step;
  return unless ref $next_step; # Done if nothing left.
  unshift @{$template->{queue}}, $next_step; # Just peaking, keep it in the queue
  my $url = $next_step->{url}; # Grab the next canonical URL
  my $object = $db->select_object_by(url=>$url);
  my $objectid = $object->{objectid};
  my $old_concepts = [];
  if (! $objectid) {
    # 1.1. If not present, add it:
    $objectid = $db->add_object_by(url=>$url,domain=>$domain);
  } else {
    # 1.2. Otherwise, skip if we don't want to update and leaf
    if ((!$self->{should_update}) && $template->leaf_test($url)) {
      # Skip leaves, when we don't want to update!
      print STDERR "Skipping over $url\n";
      my $indexed_concepts = $template->index_step(skip=>1);
      return []; }
    # 1.3. Otherwise, grab all concepts defined by the object.
    $old_concepts = $db->select_concepts_by(objectid=>$objectid);
  }
  # 2. Relay the indexing request to the template, gather concepts
  my $indexed_concepts = $template->index_step(%options);
  return unless defined $indexed_concepts; # Last step.

  # Idea: If a page can no longer be accessed, we will never delete it from the object table,
  #       we will only empty its payload (= no concepts defined by it) from the concept table.

  # 3.0.1 Flatten out incoming synonyms and categories to individual concepts:
  my $new_concepts = flatten_concept_harvest($indexed_concepts);
  # 3.0.2 Make sure they're admissible names;
  @$new_concepts = grep {admissible_name($_->{concept})} @$new_concepts;
  if ($verbosity > 0) {
    print STDERR "FlatConcepts: ".scalar(@$new_concepts)."|URL: $url\n";
    print STDERR Dumper($new_concepts);
  }
  # 3.1 Compute diff between previous and new concepts
  my ($delete_concepts,$add_concepts) = diff_concept_harvests($old_concepts,$new_concepts);
  # 4. Delete no longer present concepts
  my $invalidated_URLs = [];
  foreach my $delc(@$delete_concepts) {
    my $concepts = $db->select_concepts_by(concept=>$delc->{concept},category=>$delc->{category},scheme=>$delc->{scheme},objectid=>$objectid);
    my $delc_id = $concepts->[0]->{conceptid};
    $db->delete_concept_by(concept=>$delc->{concept},category=>$delc->{category},scheme=>$delc->{scheme},objectid=>$objectid);
    push @$invalidated_URLs,
      $db->invalidate_by(conceptid=>$delc_id);
  }
  # 5. Add newly introduced concepts
  foreach my $addc(@$add_concepts) {
    my $addc_id = 
      $db->add_concept_by(concept=>$addc->{concept},category=>$addc->{category},objectid=>$objectid,
                       domain=>$domain,link=>($addc->{url}||$url),scheme=>$addc->{scheme});
    push @$invalidated_URLs, 
      $db->invalidate_by(conceptid=>$addc_id);
  }
  # Add the http:// prefix before returning:
  @$invalidated_URLs = map {'http://'.$_} @$invalidated_URLs;
  # 6. Return URLs to be invalidated as effect:
  return $invalidated_URLs;
}

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Dispatcher> - High-level dispatcher to the correct domain indexer classes.

=head1 SYNOPSIS

use NNexus::Index::Dispatcher;
my $dispatcher = NNexus::Index::Dispatcher->new(db=>$db,domain=>$domain,verbosity=>0|1);
my $invalidated_URLs = $dispatcher->index_step(%options);
while (my $payload = $dispatcher->index_step ) {
   push @$invalidated_URLs, @{$payload};
}

=head1 DESCRIPTION

The NNexus::Dispatcher class provides a comprehensive high-level API for indexing
 web domains.

It requires that each $domain has its own C<NNexus::Index::$domain> indexer plug-in,
 that follows a ucfirst(lc($domain)) naming convention.

Additionally, C<NNexus::Index::Dispatcher> computes the concept diffs when re-indexing,
an already visited page and updates the database as needed. Lastly, the return value
of an indexing step is a list of suggested URLs to be relinked, a process called
"invalidation" in previous NNexus releases.

=head2 METHODS

=over 4

=item C<< my $dispatcher = NNexus::Index::Dispatcher->new(domain=>$domain,db=>$db,$verbosity=>0|1,
start=>$url, dom=>$dom); >>

The object constructor prepares a domain crawler object
 ( NNexus::Index::ucfirst(lc($domain)) )
and requires a NNexus::DB object, $db, for database interactions.

The returned dispatcher object can be used to iteratively index the domain,
via the index_step method.

The method accepts the following options:
 - start - the initial URL, required for first invocation
 - dom - optional, provides a Mojo::DOM object for the current URL
         instead of performing an HTTP GET to retrieve it.
 - verbosity - 0 for quiet, 1 for detailed progress messages

=item C<< my $invalidated_URLs = $dispatcher->index_step(%options); >>

Performs an indexing step by:
 - dispatches a crawl request to the domain indexer
 - computes a diff over the previously and currently indexed
   concepts for the given object/URL
 - updates the Database tables
 - Computes and returns an impact graph of previously linked objects
   (aka "invalidation")

Accepts no options, all customization is to be achieved through the "new" constructor.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Research software, produced as part of work done by
the KWARC group at Jacobs University Bremen.
Released under the The MIT License (MIT)

=cut
