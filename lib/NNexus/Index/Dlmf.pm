package NNexus::Index::Dlmf;
use warnings;
use strict;
use base qw(NNexus::Index::Template);
sub domain_root { "http://dlmf.nist.gov" }
sub domain_base { "http://dlmf.nist.gov/" }
sub depth_limit { 10 }

sub candidate_links {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  # We only care about /idx and /not pages (index and notations)
  my @next_jobs = $dom->find('a')->each;
  @next_jobs = map {s/^(.+)\.\///; $self->domain_base . $_; } grep {/\.\/(idx|not)(\/\w?)?$/} map { $_->{href}} @next_jobs;
  \@next_jobs;
}

sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  my $name;
  my $category = '33-XX'; # Special functions? always?
  my (@def_links,@def_names);
  if ($url =~ /\/idx/) {
    # DLMF Index page
    my $def_spans = $dom->find('span[class="text bold"]');
    @def_links = map {s/^(.+)\.\///; $self->domain_base . $_; } map {$_->{href}} $def_spans->pluck('a')->each;
    @def_names = map {$_->content_xml} grep {defined} $def_spans->pluck('parent')->pluck('previous')->each;
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
    push @$results, {url=>$link,concept=>$name,categories=>[$category]};
  }
  return $results;
}

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Dlmf> - Concrete Indexer for the DLMF.nist.gov domain.

=head1 DESCRIPTION

Concrete indexer for the DLMF.nist.gov domain.
See C<NNexus::Index::Template> for detailed indexing documentation.

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Research software, produced as part of work done by
the KWARC group at Jacobs University Bremen.
Released under the GNU Public License

=cut
