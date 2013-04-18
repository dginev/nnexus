# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Concept Discovery Module                                            | #
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

package NNexus::Discover;
use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(mine_candidates mine_concepts);
use Encode qw/is_utf8/;
use utf8;
use Data::Dumper;
use Time::HiRes qw ( time alarm sleep );

use NNexus::Morphology qw(get_nonpossessive get_possessive depluralize_word is_possessive is_plural);
use NNexus::Linkpolicy qw (post_resolve_linkpolicy);
use NNexus::Util qw(inset uniquify);
use NNexus::Domain qw(get_domain_blacklist get_domain_priorities get_domain_hash get_domain_id);

use HTML::TreeBuilder;
use HTML::Entities;
use URI::Escape;

sub mine_candidates {
  my (%options) = @_;
  # State: We need a config object with a properly set database
  # Input: We need a string representing the (HTML) body of the chunk we're
  #        mining on, as well as its URL.
  # Optional: Deprecated details such as 'domain' or 'format'.
  #           Interesting: allow 'nolink' again?
  my ($config,$format,$body,$nolink,$url,$domain) = 
    map {$options{$_}} qw(config format body nolink url domain);
  die "The config key is a mandatory parameter for mine_candidates!\n" unless ref $config; # TODO: Maybe raise a better error?
  my $db = $config->get_DB;
  $format = 'html' unless defined $format;
  # Prepare data, if we have a URL:
  my $objectid; # undefined if we don't have a URL, we only do MoC for named resources
  if ($url) {
    my $object = $db->select_object_by(url=>$url) || {};
    $objectid = $object->{objectid} || -1;
    $domain = $object->{domain} unless defined $domain;
    # If objectid is -1 , we will also need to add_object on the url
    if ($objectid == -1) {
      $objectid = $db->add_object_by(url=>$options{'url'},domain=>$domain);
    } else {
      # If already known, flush the links_cache for this object
      $db->clear_linkscache_by(objectid=>$objectid);
    }
  }
  # TODO: Assemble a blacklist and push it to 'nolink'
  #pull this blacklist into a config file
  # my @blacklist = ( 'g', 'and','or','i','e', 'a','means','set','sets',
  #     'choose', 'it',  'o', 'r', 'in', 'the', 'my', 'on', 'of');
  # Always return an embedded annotation with links, as well as a stand-off mined_canidates hash, containing the individual concepts with pointers.
  my $mined_candidates=[];
  if ($format eq 'html') {
    $mined_candidates = mine_candidates_html(\%options);
  } elsif ($format eq 'text') {
    $mined_candidates = mine_candidates_text(\%options);
  } else {
    print STDERR "Error: Unrecognized input format for auto-linking.\n";
  }
  # Only mark-up first found candidate, unless requested otherwise
  my @uniq_candidates;
  while (@$mined_candidates) {
    my $candidate = shift @$mined_candidates;
    my $concept = $candidate->{concept};
    @$mined_candidates = grep {$_->{concept} ne $concept} @$mined_candidates;
    push @uniq_candidates, $candidate;
  }
  @$mined_candidates = @uniq_candidates;

  #TODO: When do we deal with the nolink settings? 
  #  next if (inset($concept,@$nolink));
  #TODO: Disambiguate, adapt from:
  # my $finals = disambiguate($config, $candidates, $matchterms, $class, $targetid);

  # Update linkscache:
  if ($objectid) {
    $db->add_linkscache_by(objectid=>$objectid,conceptid=>$_->{conceptid})
      foreach (@$mined_candidates);
  }
  return $mined_candidates;
}

sub mine_candidates_html {
  my ($options) = @_;
  my ($config,$domain,$body,$syns,$targetid,$class) = map {$options->{$_}} qw(config domain body nolink targetid class);
  my $db = $config->get_DB;
  # Current HTML Parsing strategy - fire events for all HTML tags and explicitly skip over tags that 
  # won't be of interest. We need to autolink in all textual elements.
  # TODO: Handle MathML better
  my $parser = 
    HTML::Parser->new(
      'api_version' => 3,
      'start_h' => [sub {
          if ($_[1]=~/^head|style|title|script|xmp|iframe|math|svg|a|(h\d+)/) {
            $_[0]->{fresh_skip}=1;
            $_[0]->{noparse}++;
          } else {
            $_[0]->{fresh_skip}=0;
          }
      } , 'self, tagname, text'],
      'end_h' => [sub {
        $_[0]->{noparse}--
          if (($_[1]=~/^\<\/head|style|title|script|xmp|iframe|math|svg|a|(h\d+)\>$/) ||
            ((length($_[1])==0) && ($_[0]->{fresh_skip})));
        }, 'self,text'],
      'text_h'      => [\&_text_event_handler, 'self,text,offset']
    );
  $parser->{mined_candidates} = [];
  $parser->{linked}={};
  $parser->{state_information}=$options; # Not pretty, but TODO: improve
  $parser->unbroken_text;
  $parser->xml_mode;
  $parser->empty_element_tags(1);
  $parser->parse($body);
  $parser->eof();

  return $parser->{mined_candidates};
}

sub _text_event_handler {
  my ($self,$text,$offset) = @_;
  my $state = $self->{state_information};
  # Skip if in a silly element:
  if (($self->{noparse} && ($self->{noparse}>0)) || ($text !~ /\w/)) {
    return;
  }
  # Otherwise - discover concepts and annotate!
  my $mined_candidates = 
    mine_candidates_text({config=>$state->{config},
         nolink=>$state->{nolink},
         body=>$text,
         class=>$state->{class}});
  foreach my $candidate(@$mined_candidates) {
    $candidate->{offset_begin}+=$offset;
    $candidate->{offset_end}+=$offset;
  }
  push @{$self->{mined_candidates}}, @$mined_candidates;
}

# Core Data Mining routine - inspects plain-text strings
# returns back the matches and position of disambiguated links of the supplied text.
sub mine_candidates_text {
  my ($options) = @_;
  my ($config,$domain,$body,$syns,$targetid,$nolink,$class) =
    map {$options->{$_}} qw(config domain body nolink targetid nolink class);
  my $matches = find_matches($config->get_DB, $body );
  return $matches;
}

sub find_matches {
  my ($db,$text) = @_;
  # TODO: We have to make a distinction between "defined concepts" and "candidate concepts" here.
  # Probably just based on whether we find a URL or not?

  my @matches;
  my %termlist = ();
  my $offset=0;
  # Skip to 3+ letter words
  while ($text=~s/^(.*?)(\w(\w|\-|\'){2,})//) {
    $offset += length($1);
    my $offset_begin = $offset;
    $offset += length($2);
    my $offset_end = $offset;
    my $word = $2;
    next unless $word =~ /\D/; # Skip pure numbers
    # Normalize word
    my $norm_word = lc($word);
    $norm_word = depluralize_word(get_nonpossessive($norm_word));
    # get all possible candidates for both posessive and plural forms of $word 
    my @candidates = $db->select_firstword_matches($norm_word);
    next unless @candidates; # if there are no candidates skip the word
    # Split tailwords into an array
    foreach my $c(@candidates) {
      $c->{concept} = $c->{firstword}." ".$c->{tailwords};
      $c->{tailwords} = [split(/\s+/,$c->{tailwords}||'')];
    }

    my $inter_offset = 0;
    my $match_offset = 0; # Record the offset of the current longest match, add to end_position when finalized    
    my $inter_text = $text; # A copy of the text to munge around while searching.
    my @inter_matches = grep {@{$_->{tailwords}} == 0} @candidates; # Record the current longest matches here
    # Longest-match: 
    # as long as:
    #  - there is leftover tail in some candidate(s)
    @candidates = grep {@{$_->{tailwords}} > 0} @candidates;
    while (@candidates) {
      #  - AND there are leftover words in current phrase
      if ($inter_text =~ /^(\s*)(\w(\w|\-|\')+)/) {
        # then: pull and compare next word, reduce text and tailwords
        # 1. Pull next.
        my $step_offset = length($1) + length($2);
        $inter_offset += $step_offset;
        my $next_word = depluralize_word(get_nonpossessive(lc($2)));
        # 2. Filter for applicable candidates
        my @inter_candidates = grep {$_->{tailwords}->[0] eq $next_word} @candidates;
        if (@inter_candidates) {
          # We have indeed a longer match, remove the first tailword
          shift @{$_->{tailwords}} foreach @inter_candidates;
          # record intermediate longest matches - the current empty tailwords
          my @step_matches = grep {@{$_->{tailwords}} == 0} @inter_candidates;
          if (@step_matches > 0) {
            @inter_matches = @step_matches;
            $match_offset = $inter_offset;
          }
          # candidates for next iteration must have leftover tail words
          @candidates = grep {@{$_->{tailwords}} > 0} @inter_candidates;
          # Move $step_offset right the text
          substr($inter_text,0,$step_offset)='';
        } else {last;} # Last here as well.
      } else {last;} # Otherwise we are done
    }
    # In the end, do we have one or more matches?
    if (@inter_matches > 0) {
      # Yes!
      # merge multi-links into single match entry
      # multi-link = same concept and category, different URLs 
      # CARE: careful not to confuse with cases of different categories, which need disambiguation 
      my @merged_matches;
      while (@inter_matches) {
        my $match = shift @inter_matches;
        my $category = $match->{category};
        my @multilinks = map {$_->{link}} grep {$_->{category} eq $category} @inter_matches;
        @inter_matches = grep {$_->{category} ne $match->{category}} @inter_matches;
        if (@multilinks>0) {
          unshift @multilinks, $match->{link};
          $match->{multilinks} = \@multilinks;
        }
        push @merged_matches, $match;
      }
      @inter_matches = @merged_matches;
      # Record offsets:
      foreach my $match(@inter_matches) {
        $match->{offset_begin} = $offset_begin;
        $match->{offset_end} = $offset_end + $match_offset;
        delete $match->{tailwords};
      }
      # And push to main matches array
      push @matches, @inter_matches;
      # And move the text forward with the match_offset
      substr($text,0,$match_offset)='';
      $offset += $match_offset;
    } else { next; } # If not, we just move on to the next word
  }
  \@matches;
}

1;

__END__
