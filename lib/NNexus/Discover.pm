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

use NNexus::Morphology qw(get_nonpossessive get_possessive depluralize is_possessive is_plural);
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
    my $object = $db->select_object_by(url=>) || {};
    $objectid = $object->{objectid} || -1;
    $domain = $object->{domain} unless defined $domain;
    # If objectid is -1 , we will also need to add_object on the url
    if ($objectid == -1) {
      $objectid = $db->add_object_by(url=>$options{'url'},domain=>$domain);
    }
    # TODO: Flush the links_cache for this object!
  }
  #my $start = time();
  # TODO: Assemble a blacklist and push it to 'nolink'
  #pull this blacklist into a config file
  #	my @blacklist = ( 'g', 'and','or','i','e', 'a','means','set','sets',
  #			'choose', 'it',  'o', 'r', 'in', 'the', 'my', 'on', 'of');
  # Always return an embedded annotation with links, as well as a stand-off mined_canidates hash, containing the individual concepts with pointers.
  my ($annotated_body,$mined_candidates)=('',[]);
  if ($format eq 'html') {
    ($mined_candidates,$annotated_body) = mine_candidates_html(\%options);
  } elsif ($format eq 'text') {
    ($mined_candidates,$annotated_body) = mine_candidates_text(\%options);
  } else {
    print STDERR "Error: Unrecognized input format for auto-linking.\n";
  }

  #my $end = time();
  #my $total = $end - $start;
  my $numlinks = scalar(@$mined_candidates);

  #print STDERR "\nMined $numlinks concepts in $total seconds.\n";
  if ($url) {
    # TODO: Update the links_cache for this object with the mined_candidates!
  }
  return ($mined_candidates,$annotated_body);

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
		      $_[0]->{annotated_body} .= $_[2];} , 'self, tagname, text'],
       'end_h' => [sub {
		     $_[0]->{noparse}--
		       if (($_[1]=~/^\<\/head|style|title|script|xmp|iframe|math|svg|a|(h\d+)\>$/) ||
			   ((length($_[1])==0) && ($_[0]->{fresh_skip})));
		     $_[0]->{annotated_body} .= $_[1];}, 'self,text'],
       'default_h' => [sub { $_[0]->{annotated_body} .= $_[1]; }, 'self, text'],
       'text_h'      => [\&_text_event_handler, 'self,text']
  );
  $parser->{annotated_body} = "";
  $parser->{mined_candidates} = [];
  $parser->{linked}={};
  $parser->{state_information}=$options; # Not pretty, but TODO: improve
  $parser->unbroken_text;
  $parser->xml_mode;
  $parser->empty_element_tags(1);
  $parser->parse($body);
  $parser->eof();

  return ( $parser->{mined_candidates}, $parser->{annotated_body});
}

sub _text_event_handler {
  my ($self,$text) = @_;
  my $state = $self->{state_information};
  # Skip if in a silly element:
  if (($self->{noparse} && ($self->{noparse}>0)) || ($text !~ /\w/)) {
    $self->{annotated_body}.=$text;
    return;
  }
  # Otherwise - discover concepts and annotate!
  my ($mined_candidates, $annotated_body) = 
    mine_candidates_text({config=>$state->{config},
			   nolink=>$state->{nolink},
			   body=>$text,
			   class=>$state->{class}});
  $self->{annotated_body}.=$annotated_body;
  push @{$self->{mined_candidates}}, @$mined_candidates;
}

# MAIN PLAIN TEXT LINKER (!!!)
# returns back the matches and position of disambiguated links of the supplied text.
sub mine_candidates_text {
  my ($options) = @_;
  my ($config,$domain,$body,$syns,$targetid,$nolink,$class) =
    map {$options->{$_}} qw(config domain body nolink targetid nolink class);

  my $matches = find_matches($config->get_DB, $body );
  #this matches hash now contains the candidate links for each word.
  # we now no longer need the terms from find_matches so we remove it.
	
  #we need to disambiguate the matches here and mark active matches. 
  my %linked;		       #used to mark active links and targets 
  #loop through the candidate matches and disambiguate and update match hash
  # with disambiguated links
  foreach my $match (@$matches) {
    my $matchterms = $match->{'term'};
    my $candidates = $match->{'candidates'};
    next if ($linked{$matchterms});
    next if (inset(lc($matchterms),@$nolink));
    # get array of ids of qualifying entries
    #$matchterms =~ /^([^\s]+)(\s|$)/;
    #my $fw = lc($1);
    #		my $candidates = $terms->{$fw}->{$matchterms};
    my $finals = disambiguate($config, $candidates, $matchterms, $class, $targetid);
    #print Dumper( $finals );
    $linked{$matchterms} = $finals; #mark the term as linked with the optional targets
    $matches->{'active'}=1; # turn the link "on" in the matches hash
    $matches->{'links'} = $finals; #save the link targets in the matches hash.
  }

  #loop through the matches and delete those matches that are no longer active
  @$matches = grep { defined $_->{'active'}} @$matches;

  # TODO: This should really be an array, with unique pointers...
  #return the matches hash which is of the form
  #'3' => {
  #                   'plural' => 1,
  #                   'length' => 1,
  #                   'possessive' => 0,
  #                   'active' => 1,
  #                   'links' => {
  #                                '3' => [
  #                                         [
  #                                           '2586',
  #                                           1
  #                                         ],
  #                                         [
  #                                           '4609',
  #                                           1
  #                                         ],
  #                                         [
  #                                           '3569',
  #                                           1
  #                                         ]
  #                                       ],
  #                                '2' => [
  #                                         [
  #                                           '15598',
  #                                           1
  #                                         ]
  #                                       ]
  #                              },
  #                   'tags' => [
  #                               '',
  #                               ''
  #                             ],
  #                   'term' => 'state'
  #                 },

  # TODO: Reconceptualize
 # TODO: Belongs somewhere here:
 # # DG: ??? Domain priorities?
 #  # my $priorities = get_domain_priorities($state->{config}, $state->{domain} );
 #  my $linked_result;
 #  my @linkarray;		# array of href's
 #  for my $i( 0..scalar(@$matches)-1 ) {
 #    my $match = $matches->[$i];
 #    my @ltext = split(/(\W+)/, $text);
 #    # do the text substitution here.
 #    #loop through the text backwards
 #    foreach my $pos (sort {$b <=> $a} keys %$match) {
 #      my $length = $match->{$pos}->{'length'};
 #      my $objects = $match->{$pos}->{'links'};
 #      my $rltext = $ltext[$pos+$length-1];
 #      my $texttolink = "";
 #      $texttolink = join( '', @ltext[$pos..$pos+$length-1] );
 #      my $domainid = get_domain_id($state->{config}, $state->{domain});
 #      my $linktarget = $objects->{$domainid}[0][0];
 #      my $lnk = make_link_string($state->{config}->get_DB, $linktarget, $texttolink );
 #      #print "looking at $lnk against ",$state->{domain},"\n";
 #      if ( $lnk =~ $state->{domain} ) {
 #      	#print "adding lnk = [$lnk]\n";
 #     	  push @linkarray, $lnk;
 #        delete @ltext[$pos+1..$pos+$length-1] if ($length>1);
 #        $ltext[$pos]=$lnk;
 #      }
 #       # add to links table if we have a from id
 #       # 
 #       #TODO - figure out how to do the addlinks in the database 
 #       #	addLink($targetid,$object->{'objectid'}) if ($targetid);
 #    }
 #    my $finaltext = join('', grep (defined, @ltext));
 #    $linked_result .= $finaltext;
 #  }
  # # Only ANNOTATE the FIRST occurrence of each term
  # # = delete all following duplicates
  # my $linked = $self->{linked};
  # foreach my $m ( @$matches ) {
  #   print STDERR Dumper($m),"\n";
  #   foreach my $pos (sort {$a <=> $b} keys %$m) {
  #     my $matchtitle = $m->{$pos}->{'term'};
  #     delete $m->{$pos} if defined $linked->{$matchtitle};
  #     $linked->{$matchtitle} = 1;
  #   }
  # }
  return ($matches,$body);
}

sub find_matches {
  my ($db,$text) = @_;
  # TODO: We have to make a distinction between "defined concepts" and "candidate concepts" here.
  # Probably just based on whether we find a URL or not?

  my %matches;         # main matches hash (hash key is word position)
  my %termlist = ();
  # TODO: Upgrade the word detection to use absolute offsets, the lossy split should be refactored away
  my $offset=0;
  while ($text=~s/^(.*?)(\w(\w|\-){2,})//) {
    $offset += length($1);
    my $start_position = $offset;
    $offset += length($2);
    my $word = $2;
    next unless $word =~ /\D/; # Skip pure numbers
    # Normalize word
    my $norm_word = lc($word);
    $norm_word = get_nonpossessive($norm_word);
    $norm_word = depluralize($norm_word);
    # get all possible candidates for both posessive and plural forms of $word 
    my @candidates = $db->select_firstword_matches($norm_word);
    next unless @candidates; # if there are no candidates skip the word
    print STDERR "Candidates: \n",Dumper(@candidates),"\n";
    # Pick the right candidate...

    # Increase the offset
}

  #modify the matches hash to contain the candidate link information for each term.
  foreach my $pos (sort {$a <=> $b} keys %matches) {
    my $matchterms = $matches{$pos}->{'term'};
    $matchterms =~ /^([^\s]+)(\s|$)/;
    my $fw = lc($1);
    $matches{$pos}->{'candidates'} = $termlist{$fw}->{$matchterms};
  }
 # return \%matches;
 [];
}

1;

__END__
