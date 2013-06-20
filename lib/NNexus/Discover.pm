# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Concept Discovery Module                                            | #
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
package NNexus::Discover;
use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(mine_candidates);
use Encode qw/is_utf8/;
use utf8;
use Data::Dumper;
use Time::HiRes qw ( time alarm sleep );

use NNexus::StopWordList qw(stop_words_ref);
use NNexus::Morphology qw(normalize_word);
use NNexus::Concepts qw(clone_concepts);

use HTML::Parser;

# Reusable parser object (TODO: What happens if we thread/fork ?)
our $HTML_Parser = 
    HTML::Parser->new(
      'api_version' => 3,
      'start_h' => [sub {
        my ($self,$tagname,$attr)=@_;
        if ($tagname=~/^(head|style|title|script|xmp|iframe|code|math|svg|sup|a|(h\d+))$/ || 
         (($tagname eq 'span') && $attr->{class} && ($attr->{class} =~ 'nolink'))) {
          $self->{fresh_skip}=1;
          $self->{noparse}++;
        } else {
          $self->{fresh_skip}=0;
        }
      } , 'self, tagname, attr'],
      'end_h' => [sub {
        my ($self,$tagname)=@_;
        if (($tagname=~/^(head|style|title|script|xmp|iframe|code|math|svg|sup|a|(h\d+))$/) ||
         (((length($tagname)==0)||($tagname eq 'span')) && ($self->{fresh_skip} == 1))) {
          $self->{noparse}--;
          $self->{fresh_skip}=0;
        }
      }, 'self,tagname'],
      'text_h'      => [\&_text_event_handler, 'self,text,offset']
    );
$HTML_Parser->unbroken_text;
$HTML_Parser->xml_mode;
$HTML_Parser->attr_encoded(1);
$HTML_Parser->empty_element_tags(1);

# Prepare cache for first-word concept lookup
our $first_word_cache_template = {map { ($_,[]) } @{stop_words_ref()}};
sub mine_candidates {
  my (%options) = @_;
  # State: We need a db object with a properly set database
  # Input: We need a string representing the (HTML) body of the chunk we're
  #        mining on, as well as its URL.
  # Optional: Deprecated details such as 'domain' or 'format'.
  #           Interesting: allow 'nolink' again?
  my ($db,$format,$body,$nolink,$url,$domain) = 
    map {$options{$_}} qw(db format body nolink url domain);
  die "The db key is a mandatory parameter for mine_candidates!\n" unless ref $db; # TODO: Maybe raise a better error?
  $format = 'html' unless defined $format;
  return ([],0) unless $body;
  # Prepare data, if we have a URL:
  my $objectid; # undefined if we don't have a URL, we only do MoC for named resources
  if ($url) {
    my $object = $db->select_object_by(url=>$url) || {};
    $objectid = $object->{objectid} || -1;
    $domain = $object->{domain} unless defined $domain;
    # If objectid is -1 , we will also need to add_object on the url
    if ($objectid == -1) {
      # TODO: Extract the domain from the URL, this is unreliable
      $objectid = $db->add_object_by(url=>$options{'url'},domain=>$domain);
    } else {
      # If already known, flush the links_cache for this object
      $db->delete_linkscache_by(objectid=>$objectid);
    }
  }
  # Keep a cache of first words, that will simultaneously act as a blacklist.
  # TODO: Incorporate the single words from  'nolink'
  $options{first_word_cache} = { %$first_word_cache_template }; # Default are stopwords
  # Always return an embedded annotation with links, as well as a stand-off mined_canidates hash, containing the individual concepts with pointers.
  my $time;
  if ($options{verbosity}) {
    $time = time();
  }
  my $mined_candidates=[];
  my $text_length=0;
  if ($format eq 'html') {
    ($mined_candidates,$text_length) = mine_candidates_html(\%options);
  } elsif ($format eq 'text') {
    ($mined_candidates,$text_length) = mine_candidates_text(\%options);
  } else {
    print STDERR "Error: Unrecognized input format for auto-linking.\n";
  }
  # Only mark-up first found candidate, unless requested otherwise
  my @uniq_candidates;
  while (@$mined_candidates) {
    my $candidate = shift @$mined_candidates;
    my $concept = $candidate->{concept};
    my $link = $candidate->{link};
    my $category = $candidate->{category};
    @$mined_candidates = grep {($_->{concept} ne $concept) || ($_->{link} ne $link) || ($_->{category} ne $category)} @$mined_candidates;
    push @uniq_candidates, $candidate;
  }
  # Also, don't add self-links, coming from $url
  @uniq_candidates = grep {$_->{link} ne $url} @uniq_candidates if $url;
  @$mined_candidates = @uniq_candidates;

  #TODO: When do we deal with the nolink settings? 
  #  next if (inset($concept,@$nolink));
  if ($options{verbosity}) {
    printf STDERR " Discovered %d concepts in %.3f seconds.\n",scalar(@uniq_candidates),time()-$time;
  }

  # Update linkscache:
  if ($objectid) {
    $db->add_linkscache_by(objectid=>$objectid,conceptid=>$_->{conceptid})
      foreach (@$mined_candidates);
  }
  return ($mined_candidates,$text_length);
}

sub mine_candidates_html {
  my ($options) = @_;
  my ($db,$domain,$body,$syns,$targetid,$class) = map {$options->{$_}} qw(db domain body nolink targetid class);
  # Current HTML Parsing strategy - fire events for all HTML tags and explicitly skip over tags that 
  # won't be of interest. We need to autolink in all textual elements.
  # TODO: Handle MathML better
  return ([],0) unless $body;

  $HTML_Parser->{mined_candidates} = [];
  $HTML_Parser->{text_length} = 0;
  $HTML_Parser->{state_information}=$options; # Not pretty, but TODO: improve
  $HTML_Parser->parse($body);
  $HTML_Parser->eof();
  return ($HTML_Parser->{mined_candidates},$HTML_Parser->{text_length});
}

sub _text_event_handler {
  my ($self,$body,$offset) = @_;
  my $state = $self->{state_information};
  # Skip if in a silly element:
  if (($self->{noparse} && ($self->{noparse}>0)) || ($body !~ /\w/)) {
    return;
  }
  # Otherwise - discover concepts and annotate!
  my $time = time();
  my ($mined_candidates,$chunk_length) = 
    mine_candidates_text({db=>$state->{db},
         nolink=>$state->{nolink},
         body=>$body,
         domain=>$state->{domain},
	       first_word_cache=>$state->{first_word_cache},
         class=>$state->{class}});
  #printf STDERR " --processed textual chunk in %.3f seconds\n",time()-$time;
  foreach my $candidate(@$mined_candidates) {
    $candidate->{offset_begin}+=$offset;
    $candidate->{offset_end}+=$offset;
  }
  push @{$self->{mined_candidates}}, @$mined_candidates;
  $self->{text_length} += $chunk_length;
}

# Core Data Mining routine - inspects plain-text strings
# returns back the matches and position of disambiguated links of the supplied text.
sub mine_candidates_text {
  my ($options) = @_;
  my ($db,$domain,$body,$syns,$targetid,$nolink,$class,$first_word_cache) =
    map {$options->{$_}} qw(db domain body nolink targetid nolink class first_word_cache);

  # TODO: We have to make a distinction between "defined concepts" and "candidate concepts" here.
  # Probably just based on whether we find a URL or not?
  my @matches;
  my %termlist = ();
  my $offset=0;
  my $text_length = length($body);
  # Read one (2+ letter) word at a time
  my $concept_word_rex = $NNexus::Morphology::concept_word_rex;
  CONCEPT_TRAVERSAL:
  while ($body =~ s/^(.*?)($concept_word_rex)//s) {
    $offset += length($1);
    my $offset_begin = $offset;
    $offset += length($2);
    my $offset_end = $offset;
    my $word = lc($2); # lower-case to match stopwords
    # Use a cache for first-word lookups, with the dual-role of a blacklist.
    my $cached = $first_word_cache->{$word};
    my @candidates=();
    if (! (ref $cached )) {
      # Normalize word
      my $norm_word = normalize_word($word);
      # get all possible candidates for both posessive and plural forms of $word 
      @candidates = $db->select_firstword_matches($norm_word);
      # Cache the candidates:
      my $saved_candidates = clone_concepts(\@candidates); # Clone the candidates
      $first_word_cache->{$word} = $saved_candidates;
      $first_word_cache->{$norm_word} = $saved_candidates;
    } else {
      #Cached, clone into a new array
      @candidates = @{ clone_concepts($cached)};
    }
    next CONCEPT_TRAVERSAL unless @candidates; # if there are no candidates skip the word
    # Split tailwords into an array
    foreach my $c(@candidates) {
      $c->{tailwords} = [split(/\s+/,$c->{tailwords}||'')]; }
    my $inner_offset = 0;
    my $match_offset = 0; # Record the offset of the current longest match, add to end_position when finalized    
    my $inner_body = $body; # A copy of the text to munge around while searching.
    my @inner_matches = grep {@{$_->{tailwords}} == 0} @candidates; # Record the current longest matches here
    # Longest-match: 
    # as long as:
    #  - there is leftover tail in some candidate(s)
    @candidates = grep {@{$_->{tailwords}} > 0} @candidates;
    CANDIDATE_LOOP:
    while (@candidates) {
      #  - AND there are leftover words in current phrase
      if ($inner_body =~ /^(\s+)($concept_word_rex)/s) {
        # then: pull and compare next word, reduce text and tailwords
        # 1. Pull next.
        my $step_offset = length($1) + length($2);
	$inner_offset += $step_offset;
        my $next_word = normalize_word($2);
        # 2. Filter for applicable candidates
        my @inner_candidates = grep { $_->{tailwords}->[0] eq $next_word } @candidates;
        if (@inner_candidates) {
          # We have indeed a longer match, remove the first tailword
          shift @{$_->{tailwords}} foreach @inner_candidates;
          # candidates for next iteration must have leftover tail words
          @candidates = grep {@{$_->{tailwords}} > 0} @inner_candidates;
          # record intermediate longest matches - the current empty tailwords
          my @step_matches = grep {@{$_->{tailwords}} == 0} @inner_candidates;
          if (@step_matches) {
            @inner_matches = @step_matches;
            $match_offset = $inner_offset;
	  }
          # Move $step_offset right the text
          substr($inner_body,0,$step_offset)='';
        } else {last CANDIDATE_LOOP;} # Last here as well.
      } else {last CANDIDATE_LOOP;} # Otherwise we are done
    }
    # In the end, do we have one or more matches?
    if (@inner_matches > 0) {
      # Yes!
      # merge multi-links into single match entry
      # multi-link = same concept, category and domain, different URLs 
      # CARE: careful not to confuse with cases of different categories, which need disambiguation 
      my @merged_matches;
      #print STDERR Dumper(\@inner_matches);
      while (@inner_matches) {
        my $match = shift @inner_matches;
        my $category = $match->{category};
        my $domain = $match->{domain};
        my @multilinks = map {$_->{link}} 
          grep {($_->{category} eq $category) && ($_->{domain} eq $domain)} @inner_matches;
        @inner_matches = grep {($_->{category} ne $category) || ($_->{domain} ne $domain)} @inner_matches;
        if (@multilinks>0) {
          unshift @multilinks, $match->{link};
          $match->{multilinks} = \@multilinks;
        }
        push @merged_matches, $match;
      }
      @inner_matches = @merged_matches;
      # Record offsets:
      $offset += $match_offset;
      $offset_end += $match_offset;
      foreach my $match(@inner_matches) {
        $match->{offset_begin} = $offset_begin;
        $match->{offset_end} = $offset_end;
        delete $match->{tailwords};
      }
      # And push to main matches array
      push @matches, @inner_matches;
      # And move the text forward with the match_offset
      substr($body,0,$match_offset)='' if $match_offset;
    } else { next CONCEPT_TRAVERSAL; } # If not, we just move on to the next word
  }
  return (\@matches,$text_length);
}

1;

__END__

=pod 

=head1 NAME

C<NNexus::Discover> - Concept discovery for plain-text and HTML entries

=head1 SYNOPSIS

  use NNexus::Discover qw(mine_candidates);
  ($concepts_mined,$text_length) =
    mine_candidates(
      db=>$db,
      body=>$body,
      url=>$url,
      domain=>$domain,
      format=>'text|html',
      verbosity=>$verbosity);

=head1 DESCRIPTION

C<NNexus::Discover> provides a single concept discovery routine,
  parametric in:

=over 4

=item *

db: Database object from NNexus::DB

=item *

body: The textual/HTML body to be analyzed

=item *

url: The resource locator of the given body (optional, for invalidation)

=item *

domain: request a specific domain of the NNexus index
  from which to seek concept definitions
  (optional, default: all)

=item *

format: Specify whether the given body is plain-text or an HTML document

=item *

verbosity: If true, prints verbose messages, quiet otherwise.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the MIT License (MIT)

=cut
