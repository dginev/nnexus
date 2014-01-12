# /=====================================================================\ #
# | NNexus Autolinker                                                   | #
# | Indexing Plug-in, encyclopediaofmath.org domain                     | #
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
package NNexus::Index::Encyclopediaofmath;
use warnings;
use strict;
use base qw(NNexus::Index::Template);
use List::MoreUtils qw(uniq);
use URI::Escape;

# 1. We want to start from the All Pages entry point, containing the list of all categories
sub domain_root { "http://www.encyclopediaofmath.org/index.php/Special:AllPages"; }
our $eom_base = 'http://www.encyclopediaofmath.org';
# 2. Candidate links to subcategories and concept pages
our $category_test = qr'&from=';

sub candidate_links {
  my ($self)=@_;
  my $url = $self->current_url;
  # Add links from subcategory pages
  if ($url =~ /$category_test/ ) {
    # For now, we wont traverse into the specific concept pages, as there is nothing to be gained by doing so
    # If they had e.g. metadata of some kind, traversing inwards would be useful.
    # Right now the full information we need is the href and title attributes of the anchors
    
    my $dom = $self->current_dom;
    #my @anchors = $dom->find('table[class="mw-allpages-table-chunk"]')->[0]->find('a')->each;
    #my @concept_pages = uniq(map {$nlab_base . $_} grep {defined} map {$_->{'href'}} @anchors);

    # HOWEVER, some of the category pages actually have subcategories instead of leaf nodes!
    my $category_table = $dom->find('table[class="allpageslist"]')->[0];
    my @category_pages=();
    if ($category_table) {
      my @anchors = $category_table->find('a')->each;
      @category_pages = uniq(map {$eom_base . uri_unescape($_)} grep {defined} map {$_->{'href'}} @anchors); }
    return \@category_pages; }
  elsif ($url =~ /Special\:AllPages$/) {
    # First page, collect all categories:
    my $dom = $self->current_dom;
    my @anchors = $dom->find('table[class="allpageslist"]')->[0]->find('a')->each;
    my @category_pages = uniq(map {$eom_base . uri_unescape($_)} grep {defined} map {$_->{'href'}} @anchors);
    return \@category_pages; }
  else {return [];} # skip leaves
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  my $url = $self->current_url;
  # Nothing to do in the main page
  return [] if ($url =~ /Special\:AllPages$/);
  # Otherwise, all the data is inside the href and title attributes of the anchors
  my $dom = $self->current_dom;
  my $concept_table = $dom->find('table[class="mw-allpages-table-chunk"]')->[0];
  my @concepts = ();
  if ($concept_table) {
    my @anchors = $concept_table->find('a')->each;
    @concepts = map {
      { 
        url => $eom_base . uri_unescape($_->{'href'}),
        concept => $_->{'title'},
        categories => ['XX-XX']
      }}
     grep {defined $_->{'href'}} @anchors;
  }
  return \@concepts; }

1;

__END__

=pod

=head1 NAME

C<NNexus::Index::Encyclopediaofmath> - Indexing plug-in for the L<Encyclopedia of Math|http://encyclopediaofmath.org> domain.

=head1 DESCRIPTION

Indexing plug-in for the Encyclopedia of Math domain.

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