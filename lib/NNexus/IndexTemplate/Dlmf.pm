package NNexus::IndexTemplate::Dlmf;
use warnings;
use strict;
use base qw(NNexus::IndexTemplate);
sub domain_root { "http://dlmf.nist.gov" }
sub domain_base { "http://dlmf.nist.gov/" }
sub depth_limit { 10 }

sub candidate_links {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  # We only care about /idx and /not pages (index and notations)
  my @next_jobs = $dom->find('a')->each;
  @next_jobs = map {s/^(.+)\.\///; $self->domain_base . $_; } grep {/\.\/(idx|not)/} map { $_->{href}} @next_jobs;
  \@next_jobs;
}

sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  my $name;
  my $category = 'msc:33-XX'; # Special functions? always?
  my (@def_links,@def_names);
  if ($url =~ /\/idx/) {
    # DLMF Index page
    my $def_spans = $dom->find('span[class="text bold"]');
    @def_links = map {s/^(.+)\.\///; $self->domain_base . $_; } map {$_->{href}} $def_spans->pluck('a')->each;
    @def_names = map {$_->content_xml} $def_spans->pluck('parent')->pluck('previous')->each;
    print "Names: ",scalar(@def_names)," Links: ",scalar(@def_links),"\n";
  } elsif ($url =~ /\/not/) {
    my $def_anchors = $dom->find('a[class="ref"]');
    @def_links = map {s/^(.+)\.\///; $self->domain_base . $_; } map {$_->{href}} $def_anchors->each;
    @def_names = $def_anchors->pluck('parent')->pluck('content_xml')->each;
    @def_names = map {my ($name) = split(';',$_); $name;} @def_names;
    # DLMF Notation page
  } else {
    # Default is empty!
    return [];
  }

  my $results=[];
  while (@def_links && @def_names) {
    my ($name,$link)=(shift @def_names, shift @def_links);
    push @$results, {url=>$link,canonical=>$name,category=>$category};
  }
  return $results;
}

1;
__END__
