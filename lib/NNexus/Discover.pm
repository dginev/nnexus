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

  my $config = $options{config};
  my $db = $config->get_DB;
  my $format = $options{format}||'html';
  my $body = $options{body};
  my $nolink = $options{'nolink'};
  # TODO: Raise error if body, or URL are missing

  # Prepare data:
  my $object = $db->select_object_by(url=>$options{'url'}) || {};
  my $objectid = $object->{objectid} || -1;
  my $domain = $options{domain}||$object->{domain};
  # If objectid is -1 , we will also need to add_object on the url
  if ($objectid == -1) {
    $objectid = $db->add_object_by(url=>$options{'url'},domain=>$domain);
  }
  my $start = time();
  # TODO: Assemble a blacklist and push it to 'nolink'
  #pull this blacklist into a config file
  #	my @blacklist = ( 'g', 'and','or','i','e', 'a','means','set','sets',
  #			'choose', 'it',  'o', 'r', 'in', 'the', 'my', 'on', 'of');
  my $mined_candidates = [];
  if ($format eq 'html') {
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
	  $_[0]->{annotated} .= $_[2];} , 'self, tagname, text'],
        'end_h' => [sub {
	  $_[0]->{noparse}--
	    if (($_[1]=~/^\<\/head|style|title|script|xmp|iframe|math|svg|a|(h\d+)\>$/) ||
		((length($_[1])==0) && ($_[0]->{fresh_skip})));
	  $_[0]->{annotated} .= $_[1];}, 'self,text'],
	'default_h' => [sub { $_[0]->{annotated} .= $_[1]; }, 'self, text'],
	'text_h'      => [\&text_handler, 'self,text']
    );
    $parser->{annotated} = "";
    $parser->{linkarray} = [];
    $parser->{linked}={};
    $parser->{state_information}=\%options; # Not pretty, but TODO: improve
    $parser->unbroken_text;
    $parser->xml_mode;
    $parser->empty_element_tags(1);
    $parser->parse($body);
    $parser->eof();

    my ($annotated,$mined_candidates) = 
      ( $parser->{annotated}, $parser->{linkarray});
    my $numlinks = scalar(@$mined_candidates);
    my $end = time();
    my $total = $end - $start;
    print STDERR "Mined $numlinks concepts in $total seconds.\n";
    print STDERR Dumper($mined_candidates);
    return $mined_candidates;
  }
}

sub mine_candidates_html {
  my (%options) = @_;
  my ($config,$domain,$text,$syns,$targetid,$class) = map {$options{$_}} qw(config domain text nolink targetid class);
  my $db = $config->get_DB;
  $targetid = -1 unless defined $targetid; # from id - if this is null or -1, we dont touch links tbl
  # fix l2h stuff
  # separate math from linkable text, and do some massaging
  my @user_escaped;
  my $escaped;
  my $linkids;

  push @user_escaped, @$syns; #add synonyms to the user_esaped list for makeLaTeXLinks

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
				      $_[0]->{annotated} .= $_[2];} , 'self, tagname, text'],
		      'end_h' => [sub {
				    $_[0]->{noparse}--
				      if (($_[1]=~/^\<\/head|style|title|script|xmp|iframe|math|svg|a|(h\d+)\>$/) ||
					  ((length($_[1])==0) && ($_[0]->{fresh_skip})));
				    $_[0]->{annotated} .= $_[1];}, 'self,text'],
		      'default_h' => [sub { $_[0]->{annotated} .= $_[1]; }, 'self, text'],
		      'text_h'      => [\&text_handler, 'self,text']
		     );
  $parser->{annotated} = "";
  $parser->{linkarray} = [];
  $parser->{linked}={};
  $parser->{state_information}=\%options; # Not pretty, but TODO: improve
  $parser->unbroken_text;
  $parser->xml_mode;
  $parser->empty_element_tags(1);
  $parser->parse($text);
  $parser->eof();

  return ( $parser->{annotated}, $parser->{linkarray});
}

sub text_handler {
  my ($self,$text) = @_;
  my $state = $self->{state_information};
  # Skip if in a silly element:
  if (($self->{noparse} && ($self->{noparse}>0)) || ($text !~ /\w/)) {
    $self->{annotated}.=$text;
    return;
  }
  # Otherwise - discover concepts and annotate!

  #$matches: matches array for each text node in the HTML Tree.
  #$textref: this is an array of references to the original text
  #           of the HTML tree. allowing us to modify the tree directly.
  my $matches = [];
  my $textref = [];

  push @$matches, mine_candidates_text($state->{config},
				     $text,
				     $state->{nolink},
				     $state->{class},
				     $state->{targetid});

  # Only ANNOTATE the FIRST occurrence of each term
  # = delete all following duplicates
  my $linked = $self->{linked};
  foreach my $m ( @$matches ) {
    foreach my $pos (sort {$a <=> $b} keys %$m) {
      my $matchtitle = $m->{$pos}->{'term'};
      delete $m->{$pos} if defined $linked->{$matchtitle};
      $linked->{$matchtitle} = 1;
    }
  }

  # DG: ??? Domain priorities?
  my $priorities = get_domain_priorities($state->{config}, $state->{domain} );
  my $linked_result;
  my @linkarray;		# array of href's
  for my $i( 0..scalar(@$matches)-1 ) {
    my $match = $matches->[$i];
    my @ltext = split(/(\W+)/, $text);
    # do the text substitution here.
    #loop through the text backwards
    foreach my $pos (sort {$b <=> $a} keys %$match) {
      my $length = $match->{$pos}->{'length'};
      my $objects = $match->{$pos}->{'links'};
      my $rltext = $ltext[$pos+$length-1];
      my $texttolink = "";
      $texttolink = join( '', @ltext[$pos..$pos+$length-1] );
      my $domainid = get_domain_id($state->{config}, $state->{domain});
      my $linktarget = $objects->{$domainid}[0][0];
      my $lnk = make_link_string($state->{config}->get_DB, $linktarget, $texttolink );
      #print "looking at $lnk against ",$state->{domain},"\n";
      if ( $lnk =~ $state->{domain} ) {
      	#print "adding lnk = [$lnk]\n";
     	  push @linkarray, $lnk;
        delete @ltext[$pos+1..$pos+$length-1] if ($length>1);
        $ltext[$pos]=$lnk;
      }
       # add to links table if we have a from id
       # 
       #TODO - figure out how to do the addlinks in the database 
       #	addLink($targetid,$object->{'objectid'}) if ($targetid);
    }
    my $finaltext = join('', grep (defined, @ltext));
    $linked_result .= $finaltext;
  }
  $self->{annotated}.=$linked_result;
  push @{$self->{linkarray}}, @linkarray;
}

# MAIN PLAIN TEXT LINKER (!!!)
# returns back the matches and position of disambiguated links of the supplied text.
sub mine_candidates_text {
  my ($config,$text,$nolink,$class,$targetid) = @_;
  $targetid = -1 unless defined $targetid;
  deleteLinksFrom( $targetid ) if ($targetid > 0);

  my $matches = find_matches($config->get_DB, $text );
  #this matches hash now contains the candidate links for each word.
  # we now no longer need the terms from find_matches so we remove it.
	
  #we need to disambiguate the matches here and mark active matches. 
  my %linked;		       #used to mark active links and targets 
  #loop through the candidate matches and disambiguate and update match hash
  # with disambiguated links
  foreach my $pos (sort {$a <=> $b} keys %$matches) {
    my $matchterms = $matches->{$pos}->{'term'};
    my $candidates = $matches->{$pos}->{'candidates'};
    next if ($linked{$matchterms});
    next if (inset(lc($matchterms),@$nolink));
    # get array of ids of qualifying entries
    #$matchterms =~ /^([^\s]+)(\s|$)/;
    #my $fw = lc($1);
    #		my $candidates = $terms->{$fw}->{$matchterms};
    my $finals = disambiguate($config, $candidates, $matchterms, $class, $targetid);
    #print Dumper( $finals );
    $linked{$matchterms} = $finals; #mark the term as linked with the optional targets
    $matches->{$pos}->{'active'}=1; # turn the link "on" in the matches hash
    $matches->{$pos}->{'links'} = $finals; #save the link targets in the matches hash.
  }

  #loop through the matches and delete those matches that are no longer active
  foreach my $pos ( keys %$matches) {
    if ( not defined $matches->{$pos}->{'active'} ) {
      #	print "deleting $pos for term " . $matches->{$pos}->{'term'} . "\n";
      delete $matches->{$pos};
    }
  }
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

  return $matches;
}


1;

__END__
