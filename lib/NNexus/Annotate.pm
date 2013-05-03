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
use Mojo::JSON 'j';
use List::MoreUtils;
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
  my $total_concepts = 0;
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
        my @links = ([$concept->{link},$concept->{domain}]);
        # Also include multilinks, if any:
        if ($concept->{multilinks}) {
          push @links, (map {[$_,$concept->{domain}]} @{$concept->{multilinks}}); }
        while (@$concepts && ($$concepts[-1]->{offset_begin} == $from)) {
          $concept = pop @$concepts;
          next if grep {$concept->{link} eq $_->[0]} @links; # Don't duplicate URLs.
          push @links, [$concept->{link},$concept->{domain}];
        }
        $total_concepts += scalar(@links);
        if (@links == 1) {
          # Single link, normal anchor
          substr($body,$from,$length) = '<a class="nnexus_concept" href="'.$links[0]->[0].'">'.$text.'</a>';
        } else {
          # Multi-link, menu anchor
          substr($body,$from,$length) =
            # Trigger menu on click
            '<a class="nnexus_concept" href="javascript:void(0)" onClick="this.nextSibling.style.display=\'inline\'">'
            . $text
            . '</a>'
            . '<sup style="display: none;">' # Hidden container for the link menu
            . join('',map {'<a class="nnexus_concept" href="'.$_->[0].'">'.domain_tooltip($_->[1]).'</a>'} @links)
            .'</sup>';
        }
      }
      if ($options{verbosity}) {
        print STDERR "Final Annotation contains ",$total_concepts," concepts.\n";
      }
      return $body;
    } else {
      return $body; # Fallback, just return what was given
    }
  } else {
    # stand-off case:
    given ($annotation) {
      when ('json') { return j($concepts); }
      when ('perl') { return $concepts; }
      default { return j($concepts); }
    };
  }
}

our $tooltip_images = {
 Planetmath=>'http://planetmath.org/sites/default/files/fab-favicon.ico',
 Wikipedia=>'http://bits.wikimedia.org/favicon/wikipedia.ico',
 Dlmf=>'http://dlmf.nist.gov/style/DLMF-16.png',
 Mathworld=>'http://mathworld.wolfram.com/favicon_mathworld.png'
};
sub domain_tooltip {
  my ($domain_name) = @_;
  '<img src="'.$tooltip_images->{$domain_name}.'" alt="'.$domain_name.'"></img>';
}

# TODO: Given a list of internally represented annotations, serialize them to
#    the desired format (links, xml, json)

1;
