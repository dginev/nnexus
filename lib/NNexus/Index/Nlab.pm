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
use URI::Escape;

# nLab has a pretty unfriendly organization of their pages,
#   so we just ask politely for them to give us all of them at once
sub domain_root { "ncatlab.org/nlab/search?query="; }
our $nlab_base = 'http://ncatlab.org';

sub candidate_links {
  my ($self)=@_;
  my $url = $self->current_url;
  if ($url =~ /search\?query=$/) {
    # First page, collect all categories:
    my $dom = $self->current_dom;
    my @anchors = $dom->find('ul')->[0]->find('a')->each;
    my @pages = uniq(map {$nlab_base . uri_unescape($_)} grep {defined} map {$_->{'href'}} @anchors);
    return \@pages; }
  else {return [];} # skip leaves
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  my $url = uri_unescape($self->current_url);
  # Nothing to do in category pages
  return [] if ((! $self->leaf_test($url)) || ($url =~ /search\?query=$/));
  my $dom = $self->current_dom;
  my $h1 = $dom->find('h1')->[0];
  my $concept = $h1 && lc($h1->text);
  my @categories = map {$_->text} $dom->find('a.category_link')->each;
  push @categories, 'XX-XX' unless @categories;

  return [{ url => $url,
	 concept => $concept,
   scheme => 'nlab',
	 categories => \@categories,
   }]; }

sub candidate_categories {}
sub leaf_test { $_[1] =~ /^ncatlab\.org\/nlab\/show\/(?:.+)$/ }

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