# /=====================================================================\ #
# | NNexus Autolinker                                                   | #
# | Indexing Plug-in, MathWorld.wolfram.com domain                      | #
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
package NNexus::Index::Mathworld;
use warnings;
use strict;
use base qw(NNexus::Index::Template);

sub domain_root { "http://mathworld.wolfram.com/letters/"; }
sub domain_base { "http://mathworld.wolfram.com" }
sub candidate_links {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  # Only a letter or a single-slashed path to a concept
  my $directory = $dom->find('#directory')->[0];
  $directory = $dom->find('#directorysix')->[0] unless $directory; # Top level?
  return [] unless $directory; # Only index the alphabetical indices
  my @next_jobs = $directory->find('a')->each;
  @next_jobs = map { $self->domain_base . $_ } grep {defined } map {$_->{href}} @next_jobs;
  \@next_jobs;
}

sub index_page {
  my ($self) = @_;
  my $url = $self->current_url;
  my $dom = $self->current_dom;
  return [] if $dom->find('#directory')->[0];
  # TODO: Support multiple MSC categories in the same page, not only [0]
  my $msc = $dom->find('meta[scheme="MSC_2000"]')->[0];
  my $category = $msc->attrs('content') if $msc;
  my $h1 = $dom->find('h1')->[0];
  my $name = $h1->all_text if $h1;
  $name ?
    return [{
      url=>$url,
      concept=>$name,
      categories=>[$category ? ($category) : 'XX-XX'],
      }] :
    return []; }

sub depth_limit {10;}
sub request_interval { 15; }
sub leaf_test { $_[1] !~ /letters/ }
1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Mathworld> - Indexing plug-in for the MathWorld.wolfram.com domain.

=head1 DESCRIPTION

Indexing plug-in for the mathworld.wolfram.org domain.
See C<NNexus::Index::Template> for detailed indexing documentation.

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

Research software, produced as part of work done by
the KWARC group at Jacobs University Bremen.
Released under the MIT license (MIT)

=cut
