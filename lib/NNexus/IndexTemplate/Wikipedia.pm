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
our $english_concept_test = qr/^\/wiki\/[^\/\:]+$/;
our $wiki_base = 'http://en.wikipedia.org';
# 2. Candidate links to subcategories and concept pages
sub candidate_links {
  my ($self)=@_;
  my $dom = $self->current_dom;
  my $url = $self->current_url;
  # Add links from subcategory pages
  return [] unless $url =~ $category_test;
  my $subcategories = $dom->find('#mw-subcategories')->[0];
  return [] unless defined $subcategories;
  my @category_links = $subcategories->find('a')->each;
  @category_links = grep {defined && /$english_category_test/} map {$_->{href}} @category_links;

  # Also add terminal links:
  my $concepts = $dom->find('#mw-pages')->[0];
  my @concept_links = $concepts->find('a')->each;
  @concept_links = grep {defined && /$english_concept_test/} map {$_->{href}} @concept_links;

  my $candidates = [ map {$wiki_base . $_ } (@category_links, @concept_links) ];
  return $candidates;
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  return [] if $url =~ $category_test;

  my ($concept) = map {/([^\(]+)/; lc(rtrim($1));} $dom->find('span[dir="auto"]')->pluck('all_text')->each;
  my @synonyms = grep {$_ ne $concept} map {lc $_} $dom->find('p')->[0]->find('b')->pluck('all_text')->each;
  
  return [{ url => $url,
	 canonical => $concept,
	 category => $self->current_category,
	 @synonyms ? (synonyms => \@synonyms) : ()
   }];
}

sub candidate_category {
	my ($self) = @_;
	if ($self->current_url =~ /\/wiki\/Category:(.+)$/ ) {
		return $1;
	} else {
		return $self->current_category;
	}
}

# The subcategories trail into unrelated topics after the 4th level...
sub depth_limit {4;}
# Right trim function to remove trailing whitespace
sub rtrim($)
{
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}

1;
__END__