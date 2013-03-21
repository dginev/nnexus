package NNexus::IndexTemplate::Mathworld;
use warnings;
use strict;
use base qw(NNexus::IndexTemplate);

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
  return [] if $dom->find('#directory')->[0];
  my $msc = $dom->find('meta[scheme="MSC_2000"]')->[0];
  my $category = 'msc:'.$msc->attrs('content') if $msc;
  my $name = $dom->find('h1')->[0]->all_text;
  return [{
    url=>$url,
    canonical=>$name,
    $category ? (category=>$category) : (),
    }];
}

sub depth_limit {10;}

1;
__END__