# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Annotation Module                                                   | #
# |=====================================================================| #
# | Part of the Planetary project: http://trac.mathweb.org/planetary    | #
# |  Research software, produced as part of work done by:               | #
# |  the KWARC group at Jacobs University                               | #
# | Copyright (c) 2012                                                  | #
# | Released under the GNU Public License                               | #
# |---------------------------------------------------------------------| #
# | Adapted from the original NNexus code by                            | #
# |                                  James Gardner and Aaron Krowne     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev <d.ginev@jacobs-university.de>                  #_#     | #
# | http://kwarc.info/people/dginev                            (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package NNexus::Annotate;
use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(serialize_candidates);

sub serialize_candidates {
  my (%options) = @_;
  # Annotation Format:
  # links - return back fully linked html
  # xml - return back the matches hash in XML format.
  # json - returns back the matches in JSON format
  if ($options{annotation} eq 'links') {
    # DEFAULT: embed HTML links via anchor elements (already precomputed)
    return $options{serialized} if defined $options{serialized};
    return "Error: serialized should be passed in, but wasn't!";
  } else {
    print STDERR "TODO: ".($options{annotation}||'unknown')."\n";
    return [];
  }
}

# TODO: Given a list of internally represented annotations, serialize them to
#    the desired format (links, xml, json)
