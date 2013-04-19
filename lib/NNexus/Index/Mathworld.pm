package NNexus::Index::Mathworld;
use warnings;
use strict;
use base qw(NNexus::Index::Template);

sub domain_root { "http://mathworld.wolfram.com/letters/"; }
sub domain_base { "http://mathworld.wolfram.com" }
sub candidate_links {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  # Only a letter or a single-slashed path to a concept
  my $directory = $dom->find('#directory')->[0];
  $directory = $dom->find('#directorysix')->[0] unless $directory; # Top level?
  return [] unless $directory; # Only index the alphabetical indices
  my @next_jobs = $directory->find('a')->each;
  @next_jobs = map { $self->domain_base . $_ } grep {defined } map {$_->{href}} @next_jobs;
  \@next_jobs;
}

sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  print STDERR $dom;
  sleep 1; # Extra slow, let's not get banned
  return [] if $dom->find('#directory')->[0];
  # TODO: Support multiple MSC categories in the same page, not only [0]
  my $msc = $dom->find('meta[scheme="MSC_2000"]')->[0];
  my $category = $msc->attrs('content') if $msc;
  my $name = $dom->find('h1')->[0]->all_text;
  return [{
    url=>$url,
    concept=>$name,
    categories=>[$category ? ($category) : 'XX-XX'],
    }];
}

sub depth_limit {10;}

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Mathworld> - Concrete Indexer for the mathworld.wolfram.com domain.

=head1 DESCRIPTION

Concrete indexer for the mathworld.wolfram.org domain.
See C<NNexus::Index::Template> for detailed indexing documentation.

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Research software, produced as part of work done by
the KWARC group at Jacobs University Bremen.
Released under the GNU Public License

=cut
