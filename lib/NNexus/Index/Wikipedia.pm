# /=====================================================================\ #
# | NNexus Autolinker                                                   | #
# | Indexing Plug-in, Wikipedia.org domain                              | #
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
package NNexus::Index::Wikipedia;
use warnings;
use strict;
use base qw(NNexus::Index::Template);
# Special Blacklist for Wikipedia categories:
use NNexus::Index::Wikipedia::Lists;

use feature 'say';
use List::MoreUtils qw(uniq);


# EN.Wikipedia.org indexing template
# 1. We want to start from the top-level math category
sub domain_root { "http://en.wikipedia.org/wiki/Category:Mathematics"; }
our $category_test = qr/\/wiki\/Category:(.+)$/;
our $english_category_test = qr/^\/wiki\/Category:/;
our $english_concept_test = qr/^\/wiki\/[^\/\:]+$/;
our $wiki_base = 'http://en.wikipedia.org';
# 2. Candidate links to subcategories and concept pages
sub candidate_links {
  my ($self)=@_;
  my $url = $self->current_url;
  # Add links from subcategory pages
  if ($url =~ /$category_test/ ) {
    my $category_name = $1;
    return [] if $wiki_category_blacklist->{$category_name};
    my $dom = $self->current_dom;
    my $subcategories = $dom->find('#mw-subcategories')->[0];
    my @category_links = ();
    if( defined $subcategories ) {
      @category_links = $subcategories->find('a')->each;
      @category_links = grep {defined && /$english_category_test/} map {$_->{href}} @category_links; }
    # Also add terminal links:
    my $concepts = $dom->find('#mw-pages')->[0];
    my @concept_links = $concepts->find('a')->each if defined $concepts;
    @concept_links = grep {defined && /$english_concept_test/} map {$_->{href}} @concept_links;

    my $candidates = [ map {$wiki_base . $_ } (@category_links, @concept_links) ];
    return $candidates;
  } else {return [];} # skip leaves
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  my $url = $self->current_url;
  # Nothing to do in category pages
  return [] unless $self->leaf_test($url);
  my $dom = $self->current_dom;
  # We might want to index a leaf page when descending from different categories, so keep them marked as "not visited"
  delete $self->{visited}->{$url};
  my ($concept) = map {/([^\(]+)/; lc(rtrim($1));} $dom->find('span[dir="auto"]')->pluck('all_text')->each;
  my @synonyms;
  # Bold entries in the first paragraph are typically synonyms.
  my $first_p = $dom->find('p')->[0];  
  @synonyms = (grep {(length($_)>4) && ($_ ne $concept)} map {lc $_} $first_p->children('b')->pluck('all_text')->each) if $first_p;
  my $categories = $self->current_categories || ['XX-XX'];

  return [{ url => $url,
	 concept => $concept,
   scheme => 'wiki',
	 categories => $categories,
	 @synonyms ? (synonyms => \@synonyms) : ()
   }];
}

sub candidate_categories {
	my ($self) = @_;
	if ($self->current_url =~ /$category_test/ ) {
		return [$1];
	} else {
		return $self->current_categories;
	}
}

# The subcategories trail into unrelated topics after the 4th level...
sub depth_limit {20;} # But let's bite the bullet and manually strip away the ones that are pointless
sub leaf_test { $_[1] !~ /$category_test/ }
# Utility:
# Right trim function to remove trailing whitespace
sub rtrim {
	my $string = shift;
	$string =~ s/\s+$//;
	return $string; }

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Wikipedia> - Indexing plug-in for the (English) L<Wikipedia.org|http://wikipedia.org> domain.

=head1 DESCRIPTION

Indexing plug-in for the (English) Wikipedia.org domain.

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