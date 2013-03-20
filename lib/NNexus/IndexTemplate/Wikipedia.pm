package NNexus::IndexTemplate::Wikipedia;
use warnings;
use strict;
use base qw(NNexus::IndexTemplate);
use feature 'say';
use List::MoreUtils qw(uniq);

# EN.Wikipedia.org indexing template
# 1. We want to start from the top-level math category
sub domain_root { "http://en.wikipedia.org/wiki/Category:Mathematical_concepts"; }
our $category_test = qr/\/wiki\/Category:/;
our $english_category_test = qr/^\/wiki\/Category:/;
our $wiki_base = 'http://en.wikipedia.org';
# 2. Candidate links to subcategories and concept pages
sub candidate_links {
  my ($self)=@_;
  my $dom = $self->current_dom;
  my $url = $self->current_url;
  # Only trace links from Category: pages
  return [] unless $url =~ $category_test;
  my $subcategories = $dom->find('#mw-subcategories')->[0];
  return [] unless defined $subcategories;
  my @links = $subcategories->find('a')->each;
  @links = map {$wiki_base . $_ } grep {defined && /$english_category_test/} map {$_->{href}} @links;
  \@links;
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  return [] if ($self->current_url) =~ $category_test;
  my $dom = $self->current_dom;
  my @synonyms = map {lc $_} $dom->find('p')->[0]->find('b')->pluck('text')->each;
  my ($concept) = map {lc $_} $dom->find('span[dir="auto"]')->pluck('text')->each;
  
  return [{ url => $self->current_url,
	 canonical => $concept,
	 category => $self->current_category,
	 @synonyms ? (synonyms => \@synonyms) : ()
   }];
}

# The subcategories trail into unrelated topics after the 4th level...
sub depth_limit {4;}


1;
__END__