# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Annotation Module                                                   | #
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

package NNexus::Annotate;
use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(serialize_concepts);

use feature 'switch';
use JSON::XS qw(encode_json);
use Data::Dumper;

sub serialize_concepts {
  my (%options) = @_;
  # Annotation Format:
  # links - return back fully linked html
  # xml - return back the matches hash in XML format.
  # json - returns back the matches in JSON format
  # perl - return back the datastructrure as-is
  my $annotation = $options{annotation};
  my $concepts = $options{concepts}; 
  if ($options{embed}) {
    my $body = $options{body};
    if ((!$annotation) || ($annotation eq 'links')) {
      # embed links
      # Enhance the text between the offset with a link pointing to the URL
      # TODO: Multi-link cases need special treatment
      while (@$concepts) {
        my $concept = pop @$concepts; # Need to traverse right-to-left to keep the offsets accurate.
        my $from = $concept->{offset_begin};
        my $to = $concept->{offset_end};
        my $length = $to-$from;
        my $text = substr($body,$from,$length);
        substr($body,$from,$length) = '<a href="'.$concept->{link}.'">'.$text.'</a>'
      }
      return $body;
    } else {
      return $body; # Fallback, just return what was given
    }
  } else {
    # stand-off case:
    given ($annotation) {
      when ('json') { return encode_json($concepts); }
      when ('perl') { return $concepts; }
      default { return encode_json($concepts); }
    };
  }
}

# TODO: Given a list of internally represented annotations, serialize them to
#    the desired format (links, xml, json)

1;