# /=====================================================================\ #
# | NNexus Autolinker                                                   | #
# | Indexing Plug-in, MathOverflow.net domain                           | #
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
package NNexus::Index::Mathoverflow;
use warnings;
use strict;
use base qw(NNexus::Index::Template);
use List::MoreUtils qw(uniq);
use URI::Escape;
use Data::Dumper;

# Stack exchange exposes its database for public queries. I have made a query that returns all tag names
sub domain_root { "http://data.stackexchange.com/mathoverflow/csv/348428?opt.textResults=true"; }
our $Mathoverflow_base = 'http://mathoverflow.net';

sub candidate_links {
  my ($self)=@_;
  my $url = uri_unescape($self->current_url);
  return []; # We only visit the tag list page here
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  my $dom = $self->current_dom;
  my $tag_payload = $dom->all_text;
    $tag_payload =~ s/^[^"]+"//;
    $tag_payload =~ s/"[^"]*$//;
    my @tags = split(/" "/,$tag_payload);
    my @concepts = map { {
      url => "http://mathoverflow.net/tags/$_/info",
      concept => tag_to_concept($_),
      categories => ['XX-XX'], # No categorization available for now
      } } @tags; 
    return \@concepts; }

sub tag_to_concept {
  s/^[^.]+\.//;
  s/(?<!\d)\-/ /g;
  s/semi /semi-/g;
  return $_;
}

sub request_interval { 1; }

1;

__END__

=pod

=head1 NAME

C<NNexus::Index::Mathoverflow> - Indexing plug-in for the L<MathOverflow|http://mathoverflow.net> domain.

=head1 DESCRIPTION

Indexing plug-in for the MathOverflow domain.

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