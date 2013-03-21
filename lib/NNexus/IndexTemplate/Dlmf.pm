package NNexus::IndexTemplate::Dlmf;
use warnings;
use strict;
use base qw(NNexus::IndexTemplate);

sub domain_root { "http://dlmf.nist.gov/"; }
sub domain_base { "http://dlmf.nist.gov" }

sub candidate_links {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  # We only care about /idx and /not pages (index and notations)
  my @next_jobs = $dom->find('a')->grep(/\.gov\/(idx|not)/)->each;
  @next_jobs = grep {defined} map { $_->{href}} @next_jobs;
  \@next_jobs;
}

sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  if ($url =~ /\.gov\/idx/) {
    # DLMF Index page
    
  } elsif ($url =~ /\.gov\/not/) {
    # DLMF Notation page
  } else {
    # Default is empty!
    [];
  }
  return [{
    url=>$url,
    canonical=>$name,
    $category ? (category=>$category) : (),
    }];
}

sub depth_limit {10;}

1;
__END__
