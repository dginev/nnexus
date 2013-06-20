# /=====================================================================\ #
# | NNexus Autolinker                                                   | #
# | Indexing Plug-in, DLMF.nist.gov domain                              | #
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
package NNexus::Index::Dlmf;
use warnings;
use strict;
use base qw(NNexus::Index::Template);

sub domain_root { "http://dlmf.nist.gov" }
sub domain_base { "http://dlmf.nist.gov/" }
sub depth_limit { 100 }

sub candidate_links {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  # We only care about /idx and /not pages (index and notations)
  my @next_jobs = $dom->find('a')->each;
  @next_jobs = map {s/^(\.\.\/)?\.\///; $self->domain_base . $_; } grep {/\.\/(idx|not)(\/\w?)?$/} map { $_->{href}} @next_jobs;
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
    my $def_spans = $dom->find('div > ul > li > span > span[class="ltx_text ltx_font_bold"]');
    @def_links = map {s/^(\.\.\/)?\.\///; $self->domain_base . $_; } map {$_->{href}} $def_spans->pluck('a')->each;
    @def_names = map {
        my $t = $_->children->first->content_xml;
       $t =~ s/\(.+\)//g;
       $t =~ s/\:(.*)$//;
       $t;}
        $def_spans->pluck('parent')->pluck('parent')->each;
  } elsif ($url =~ /\/not/) {
    my $def_anchors = $dom->find('a[class="ltx_ref"]');
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

C<NNexus::Index::Dlmf> - Indexing plug-in for the L<DLMF.nist.gov|http://dlmf.nist.gov> domain.

=head1 DESCRIPTION

Indexing plug-in for the DLMF.nist.gov domain.

See L<NNexus::Index::Template> for detailed indexing documentation.

=head1 SEE ALSO

L<NNexus::Index::Template>

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

  Research software, produced as part of work done by
  the KWARC group at Jacobs University Bremen.
  Released under the MIT license (MIT)

=cut
