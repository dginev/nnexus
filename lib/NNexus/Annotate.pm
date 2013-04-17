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
our @EXPORT_OK = qw(serialize_concepts);

sub serialize_concepts {
  my (%options) = @_;
  # Annotation Format:
  # links - return back fully linked html
  # xml - return back the matches hash in XML format.
  # json - returns back the matches in JSON format
  print STDERR "TODO: ".($options{annotation}||'unknown')."\n";
  if ($options{embed}) {
    return $options{body}; # Mock-up, just return what was given
  } else {
    ''; # TODO: Serialize stand-off annotation to desired representation
  }
}

# TODO: Given a list of internally represented annotations, serialize them to
#    the desired format (links, xml, json)
