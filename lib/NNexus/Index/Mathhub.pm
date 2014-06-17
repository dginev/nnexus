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
sub domain_root { "http://mathhub.info/mh/archives"; }
our $mathhub_base = 'http://mathhub.info';

sub candidate_links {
  my ($self)=@_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  if ($url =~ /\/source$/) {
    # List page, collect all leaf pages:
    my @anchors = grep {$_->{'jobad:href'}} $dom->find('li.dref > span')->each;
    my @category_pages = map {s/\/([^\/]+)$/\/source\/$1/; $_;} map {uri_unescape($_)} uniq(sort(grep {defined} map {$_->{'jobad:href'}} @anchors));
    @category_pages = grep {/\.en\.omdoc$/} @category_pages; # Only English pages
    return \@category_pages; }
  elsif ($url =~ /archives$/) { # top page
    my @anchors = $dom->find('div.field-item.even > ul > li > a')->each;
    print STDERR "\nAnchors found: ",scalar(@anchors),"\n";
    my @content_pages = map {$mathhub_base . $_ . '/source'} map {uri_unescape($_)} uniq(sort(grep {defined} map {$_->{'href'}} @anchors));
    return \@content_pages; }
  else {return [];} # skip leaves
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  my $url = uri_unescape($self->current_url);
  # Nothing to do in top page, or non-English pages
  return [] if (($url =~ /smglom\/source$/) || ($url !~ /\.en\.omdoc$/));
  my $dom = $self->current_dom;
  my @spans = grep {$_->{'jobad:href'}} $dom->find('span.definiendum')->each;
  my %mmt_url = map {$_->text => $_->{'jobad:href'}} @spans;
  my @concepts = map {
    {
      url => $mmt_url{$_},
      concept => $_,
      scheme => 'MSC',
      categories => ['XX-XX'], # No categorization available for now
    }} uniq(grep {length($_)} map {$_->text} @spans);

  return \@concepts; }

1;

sub request_interval { 1; }

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