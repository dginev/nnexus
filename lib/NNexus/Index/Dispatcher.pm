package NNexus::Index::Dispatcher;
use NNexus::Util;
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

  bless {index_template=>$index_template,domain=>$domain,db=>$db,
	verbosity=>$options{verbosity}||0}, $class;
}

sub index_step {
  my ($self,%options) = @_;
  # 1. Relay the indexing request to the template, gather concepts
  my $template = $self->{index_template};
  my $db = $self->{db};
  my $domain = $self->{domain};
  my $verbosity = $self->{verbosity};
  my $indexed_concepts = $template->index_step(%options);
  return unless defined $indexed_concepts; # Last step.

  # Idea: If a page can no longer be accessed, we will never delete it from the object table,
  #       we will only empty its payload (= no concepts defined by it) from the concept table.

  # 2. Check if object has already been indexed:
  my $url = $template->current_url; # Grab the current canonical URL
  my $object = $db->select_object_by(url=>$url);
  my $objectid = $object->{objectid};
  my $old_concepts = [];
  if (! $objectid) {
    # 2.1. If not present, add it:
    $objectid = $db->add_object_by(url=>$url,domain=>$domain);
  } else {
    # 2.2. Otherwise, grab all concepts defined by the object.
    $old_concepts = $db->select_concepts_by(objectid=>$objectid);
  }
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
    $db->delete_concept_by(concept=>$delc->{concept},category=>$delc->{category},scheme=>$delc->{scheme},objectid=>$objectid);
    push @$invalidated_URLs,
      $db->invalidate_by(concept=>$delc->{concept},category=>$delc->{category},scheme=>$delc->{scheme},objectid=>$objectid);
  }
  # 5. Add newly introduced concepts
  foreach my $addc(@$add_concepts) {
    $db->add_concept_by(concept=>$addc->{concept},category=>$addc->{category},objectid=>$objectid,
                       domain=>$domain,link=>($addc->{url}||$url),scheme=>$addc->{scheme});
    push @$invalidated_URLs, 
      $db->invalidate_by(concept=>$addc->{concept},category=>$addc->{category},scheme=>$addc->{scheme},objectid=>$objectid);
  }
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
