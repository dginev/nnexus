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
package NNexus::Index::Nlab;
use warnings;
use strict;
use base qw(NNexus::Index::Template);
use List::MoreUtils qw(uniq);

# 1. We want to start from the All Pages entry point, containing the list of all categories
sub domain_root { "http://ncatlab.org/nlab/show/All+Pages"; }
our $nlab_base = 'http://ncatlab.org';
# 2. Candidate links to subcategories and concept pages
our $category_test = qr'^ncatlab\.org/nlab/list/(.+)$';

sub candidate_links {
  my ($self)=@_;
  my $url = $self->current_url;
  # Add links from subcategory pages
  if ($url =~ /$category_test/ ) {
    my $dom = $self->current_dom;
    my @anchors = map {$_->find('a')->each} $dom->find('li[class="page"]')->each;
    my @concept_pages = uniq(map {$nlab_base . $_} grep {defined} map {$_->{'href'}} @anchors);
    return \@concept_pages; }
  elsif ($url =~ /All\+Pages$/) {
    # First page, collect all categories:
    my $dom = $self->current_dom;
    my @anchors = $dom->find('ul')->[0]->find('a')->each;
    my @category_pages = uniq(map {$nlab_base . $_} grep {defined} map {$_->{'href'}} @anchors);
    return \@category_pages; }
  else {return [];} # skip leaves
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  my $url = $self->current_url;
  # Nothing to do in category pages
  return [] if ((! $self->leaf_test($url)) || ($url =~ /All\+Pages$/));
  my $dom = $self->current_dom;
  my $h1 = $dom->find('h1')->[0];
  my $concept = $h1 && lc($h1->text);
  my $categories = $self->current_categories || ['XX-XX'];

  return [{ url => $url,
	 concept => $concept,
   scheme => 'nlab',
	 categories => $categories,
   }]; }

sub candidate_categories {
	my ($self) = @_;
	if ($self->current_url =~ /$category_test/ ) {
    my $category_name = $1;
    $category_name =~ s/\+/ /g;
		return [$category_name]; }
  else {
		return $self->current_categories; }}

sub leaf_test { $_[1] !~ /$category_test/ }

1;

__END__

=pod

=head1 NAME

C<NNexus::Index::Nlab> - Indexing plug-in for the L<nLab|http://ncatlab.org> domain.

=head1 DESCRIPTION

Indexing plug-in for the nLab domain.

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