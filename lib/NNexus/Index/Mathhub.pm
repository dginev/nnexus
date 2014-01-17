# /=====================================================================\ #
# | NNexus Autolinker                                                   | #
# | Indexing Plug-in, nCatLab.org domain                                | #
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
package NNexus::Index::Mathhub;
use warnings;
use strict;
use base qw(NNexus::Index::Template);
use List::MoreUtils qw(uniq);
use URI::Escape;

# 1. We want to start from the All Pages entry point, containing the list of all categories
sub domain_root { "http://mathhub.info/smglom/smglom/source"; }
our $mathhub_base = 'http://mathhub.info';

sub candidate_links {
  my ($self)=@_;
  my $url = $self->current_url;
  if ($url =~ /smglom\/source$/) {
    # Top page, collect all leaf pages:
    my $dom = $self->current_dom;
    my @anchors = $dom->find('h2 > a')->each;
    my @category_pages = map {$mathhub_base . uri_unescape($_)} uniq(sort(grep {defined} map {$_->{'href'}} @anchors));
    return \@category_pages; }
  else {return [];} # skip leaves
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  my $url = uri_unescape($self->current_url);
  # Nothing to do in top page
  return [] if $url =~ /smglom\/source$/;
  my $dom = $self->current_dom;
  my @spans = grep {$_->{'jobad:href'}} $dom->find('p[class="ltx_p"] u > i > span')->each;
  my @concepts = map {
    {
      url => $url,
      concept => $_,
      scheme => 'MSC',
      categories => ['XX-XX'], # No categorization available for now
    }} uniq(grep {length($_)} map {$_->text} @spans);

  return \@concepts; }

1;

sub request_interval { 0.2; }

__END__

=pod

=head1 NAME

C<NNexus::Index::Mathhub> - Indexing plug-in for the L<MathHub|http://mathhub.info> domain.

=head1 DESCRIPTION

Indexing plug-in for the MathHub domain.

See L<NNexus::Index::Template> for detailed indexing documentation.

=head1 SEE ALSO

L<NNexus::Index::Template>

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by
 the KWARC group at Jacobs University Bremen.
 Released under the MIT License (MIT)

=cut