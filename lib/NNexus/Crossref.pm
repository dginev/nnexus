# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Invasive linking and cross-referencing Module                       | #
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
package NNexus::Crossref;
use strict;
use warnings;
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

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(cross_reference);

# I assume this should populate the <links /> 
sub cross_reference_HTML {
  my (%options) = @_;
  my ($config,$domain,$text,$syns,$fromid,$class) = map {$options{$_}} qw(config domain text nolink fromid class);
  my $db = $config->get_DB;
  $fromid = -1 unless defined $fromid; # from id - if this is null or -1, we dont touch links tbl
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

  #print "Linking ";
  push @$matches, cross_reference_text($state->{config},
				     $text,
				     $state->{nolink},
				     $state->{class},
				     $state->{fromid});

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
       #	addLink($fromid,$object->{'objectid'}) if ($fromid);
    }
    my $finaltext = join('', grep (defined, @ltext));
    $linked_result .= $finaltext;
  }
  $self->{annotated}.=$linked_result;
  push @{$self->{linkarray}}, @linkarray;
}

# new main entry point for cross-referencing, you send it some markup text and the mode (latex or html)
# and it returns the same text linked up in the same markup format
# This (in theory) is our all-powerful method
sub cross_reference {
  my (%opts) = @_;
  my ($config,$format,$domain,$text,$nolink,$fromid,$class,$detail) =
    map {$opts{$_}} qw(config format domain text nolink fromid class detail);
  my $db = $config->get_DB;
  if (! defined $fromid) {
    $fromid = -1;
    $opts{fromid}=$fromid;
  }
  #pull this blacklist into a config file
  #	my @blacklist = ( 'g', 'and','or','i','e', 'a','means','set','sets',
  #			'choose', 'it',  'o', 'r', 'in', 'the', 'my', 'on', 'of');
  my $domainbl = get_domain_blacklist( $config, $domain );
  push @$nolink, @$domainbl;
  foreach my $n ( @$nolink ) {
    push @$nolink, lc($n) if ($n && ($n ne lc($n)));
  }
  $opts{nolink}=$nolink;

  my $DEBUG = 0;
  #print STDERR "LINKING IN MODE $format\n";
  if ( $format eq 'html' ) {
    #print STDERR "LINKING IN HTML MODE\n"	if $DEBUG;
    return cross_reference_HTML(%opts);
  } else {
    print STDERR "Mode $format is not (yet?) supported\n";
  }
}

# MAIN PLAIN TEXT LINKER (!!!)
# returns back the matches and position of disambiguated links of the supplied text.
sub cross_reference_text {
  my ($config,$text,$nolink,$class,$fromid) = @_;
  $fromid = -1 unless defined $fromid;
  deleteLinksFrom( $fromid ) if ($fromid > 0);

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
    my $finals = disambiguate($config, $candidates, $matchterms, $class, $fromid);
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





# disambiguate a link
#
# disambigute now returns a hash of list of the form
#a->{domain} =  [ [internalobjectid,  score], [..] ... ] 
#a->{domain2} = [ [internalobjectid2, score2] , []... ] 
#in the future this function will sort the results by score. but for now we assume
# that the first object is the one to use since we have no scoring metrics as of yet.
sub disambiguate {
  my ($config,$candidates,$title,$classes,$fromid) = @_;
  my $db = $config->get_DB;
  my @tempclass = ();
  my %scorelist = ();
  my ($start, $finish, $DEBUG);

  my @ids = @$candidates;
  @ids = post_resolve_linkpolicy($db, $fromid, $title, $classes, @ids); #speed is good

  my %domainobjects = ();  # {domainid}->[list of objects, in domain] 
  foreach my $id ( @ids ) {
    # TODO : REFACTOR THIS!!!
    # my $obj = get_object_hash($db,$id);
    #push @{$domainobjects{$obj->{'domainid'}}}, $id;
  }


  if ( $DEBUG ) {
    print "Disambiguating $title\n";
    print "BEFORE classification = @ids\n";
    my $num = $#ids+1;
    print "BEFORE num = $num\n";
    #	print Dumper( \%domainobjects );
  }

  my $graphDisambig = 1;

  if ( $graphDisambig ) {
    @ids = ();
    foreach my $k ( keys %domainobjects ) {
      push @ids, disambiguate_classification($config, $classes, $k, 
					      @{$domainobjects{$k}} );
    }
  }

		
  if ( $DEBUG ) {
    print "AFTER classification = @ids\n";
    my $num = $#ids+1;
    print "AFTER num = $num\n";
  }
	
  foreach my $j ( @ids ) {
    my $obj = get_object_hash($db,$j);
    #	print "adding $j to list\n";
    my @fixer = ($j,1);
    if ( defined $scorelist{$obj->{'domainid'}} ) {
      my $temp = $scorelist{$obj->{'domainid'}};
      push @$temp, \@fixer; 
      $scorelist{$obj->{'domainid'}} = $temp;
    } else {
      $scorelist{$obj->{'domainid'}} = [\@fixer];
    }
  }
	
  return \%scorelist;
}

sub disambiguate_graph {
  my $fromid = shift;
  my @toplist = @_;
	
  my ($start, $finish, $DEBUG);
  $DEBUG = 0;
	
  if ($DEBUG) {
    $start = time();
  }

	
  # if nothing above produced a single winner id, do the graph method
  #
  if ($#toplist > 0) {
		
    # do the BFS traversal
    my $winner = getBestByBFS($fromid, \@toplist, 2);
    warn "*** link score: winner (for $fromid) by graph walking is $toplist[$winner]\n", 2;
    if ($DEBUG) {
      $finish = time();
      my $total = $finish - $start;
      print "makelinks->disambiguate->disambiguate_graph: $total seconds\n";
    }	

    return $toplist[$winner];
  }
	
  if ($DEBUG) {
    $finish = time();
    my $total = $finish - $start;
    print "makelinks->disambiguate->disambiguate_graph: $total seconds\n";
  }	


  return $toplist[0];
}

sub disambiguate_classification {
  my ($config, $class, $domain,@ids) = @_; # this will be implemented in SOC 2007

  #	print "disambiguate_classification called with arguments:\n";
  #	print "class = $class\n";
  #	print Dumper($class);
  #	print "domain = $domain\n";
  #	print "ids = @ids\n";

  #	print Dumper( $class );

  my @classes = ();
  my @cstrings = ();

  my $min = 10000000;
  my @toplist = ();    # list of top scored entries
  #my @topclass = ();	# their classifications
	
  my ($start, $finish, $DEBUG);
  $DEBUG = 0;
	
  if ($DEBUG) {
    $start = time();
  }
  my @blah = ();
  foreach my $j ( @{$class} ) {
    push @blah, $j->{'scheme'} . ":" . $j->{'externalid'};
  }

  my $temp = $config->{classification}->normalizeclass(join(", ", @blah) );

  my @cats = split(/\s*,\s*/,$temp);
  #my @cats = @{$class};

  # if we have classification, we can compare it to the classifications of
  # the link choices
  #
  if ($#cats >= 0) {
    # get classifications
    #
    if ($DEBUG) {
      print "there are " . ($#ids + 1) . " concepts to get possible classes\n";
    }
		
    foreach my $id (@ids) {
      my ($str, $cf) = $config->{classification}->classinfo( $id );
      push @classes,$cf;
      push @cstrings,$str;
    }
		
		
    # loop through and score the classification for each id
    # against the current classification
    #
    my $i = -1;
    foreach my $id (@ids) {
      $i++;
      my @compare = split(/\s*,\s*/,$cstrings[$i]);
	
      next if ($#compare<0);	# no classification, skip

      # find score, update "winner"
      # this scoring scheme is a combination of scores considering full
      # category specification, and top-level specification, with 
      # preference going to full.
      #
      #		print "Comparing @cats to @compare\n";
      # compute the minimum classification distance.
      foreach my $c1 ( @cats ) {
	foreach my $c2 ( @compare ) {
	  print "Class1: $c1 vs Class2: $c2\n\n";
	  my $d = $config->{classification}->class_distance( $c1, $c2 );
	  #		print "Distance between $c1 and $c2 is $d\n";
	  if ( $d < $min ) {
	    $min = $d;
	    @toplist = ();
	    push @toplist, $id;
	  } elsif ( $d == $min ) {
	    push @toplist, $id;
	  }
	}
      }
    }


    @toplist = uniquify( @toplist ) if $DEBUG;
    if ($#toplist > 0) {
      print "*** warning -- link score: tie between: @toplist" if $DEBUG;
    }
  }
  #	print "The minimum distance was $min\n";
	
		
  if ($DEBUG) {
    $finish = time();
    my $total = $finish - $start;
  }

  if ($#toplist < 0) {
    return @ids;
  }

  return uniquify( @toplist );
}

# filter a list of candidate concept IDs by subcollection in our new context this is really the domain
# TODO : fix this up later.
sub disambiguate_subcollection {
  my $fromid = shift;
  my @ids = @_;

  my $table = getConfig('en_tbl');

  # reduce the candidate pool using source collection commonality
  #
  if ($#ids >= 1) {

    my $thissource = getConfig('proj_nickname');
    if ($fromid != -1) {
      $thissource = getSourceCollection($table, $fromid);
    }

    # get a subset of IDs of items which match this entry's collection
    # 
    my @subset = ();
    foreach my $cid (@ids) {
      if ($thissource eq getSourceCollection($table, getobjectidbycid($cid)) ) {
	push @subset, $cid;
      }
    }

    # if the subset is not empty, use it instead of original set
    #
    if (scalar @subset) {
      @ids = @subset;
    }
  }
	
  return @ids;
}

#this function returns a standard <a href=link>text</a> string
sub make_link_string { 
  my ($db , $objectid, $anchor) = @_;
  my $object = get_object_hash( $db, $objectid );
  my $domain = get_domain_hash( $db, $object->{'domainid'} );
  my $template = $domain->{'urltemplate'};
  my $linkstring = $template . HTML::Entities::encode($object->{'identifier'});
  #	my $domainnick = $domain->{'nickname'};

  #the <a> class is set = to the domain nickname provided by the user. 
  #This allows for user customizable stylesheets for how the links appear
  # in the browser.
  return "<a href=\"$linkstring\">$anchor</a>";
}

# remove things from the tags that should go "outside" the anchor.
#
sub outertags {
  my $tags = shift;

  my $first = "";
  my $last = "";

  my $l = scalar @$tags - 1;
	
  if ($tags->[0] =~ /^(["`\(\[]+)([^`\(\[].+)?$/) {
    $first = $1;
    $tags->[0] = $2;
  }

  if ($tags->[$l] =~ /^(.+[^\)"\]'.?!:])?([\)"\]'.?!:}]+)$/) {
    $last = $2;
    $tags->[$l] = $1;
  }

  return ($first, $last);
}

# get a left anchor word without tags
#
sub notagsleft {
  my $word = shift;

  $word =~ s/^["`\(\[]+//;

  return $word;
}

# get a right anchor word without tags
#
sub notagsright {
  my $word = shift;

  $word =~ s/[\)"\]'.?!:}]+$//;

  return $word;
}


# slap tags onto anchor words. input: tag arrayref, anchor string
#
sub taganchor {
  my $tags = shift;
  my $anchor = shift;

  my @tagged = ();		# array of tagged words

  my $i = 0;
  foreach my $word (split(/\s+/,$anchor)) {
    push @tagged, $tags->[2*$i].$word.$tags->[2*$i+1];
    $i++;
  }

  return join (' ',@tagged);
}

# get the anchor text for a link match term (pluralizes/possessivizes)
#
sub getanchor {
  my $match = shift;

  my $term = $match->{'term'};
  my $plural = $match->{'plural'};
  my $psv = $match->{'possessive'};

  my $anchor = $term;
  if ($psv == 1) {
    $anchor = get_possessive($term);
  } 
  if ($plural == 1) {
    $anchor = pluralize($term);
  }

  return $anchor;
}

# build a match description structure based on text and synonyms list
sub find_matches {
  my ($db,$text) = @_;
  my ($finish, $DEBUG);
  $DEBUG = 1;
  my $start = time() if ($DEBUG);
  my %matches;         # main matches hash (hash key is word position)
  my %termlist = ();
  my @tlist = split(/(\W+)/, $text);


  # loop through words in the text. this is the O(m) main loop.
  my $tlen = $#tlist+1;
  for (my $i = 0; $i < $tlen; $i++) {
    # if the word is of the form @@\d+@@, ##\d+##, __\w+-- we skip it
    my $word = lc($tlist[$i]);  #make sure it is lowercase for hash
    next if ( $word =~ /\@\@\d+\@\@/ || $word =~ /\#\#\d+\#\#/ || $word =~ /__\w+__/ ||
	 $word =~ /^\d+$/ || length($word) < 2);
    my $COND = 0;		# turn this to 1 to debug this portion

    # look for the first word, then try to match additional words
    my $rv = 0;
    my $fail = 1;

    # get all possible candidates for both posessive and plural forms of $word 
    my @cand = $db->select_firstword_matches($word);
    next unless @cand; # if there are no candidates skip the word

    #now figure out the code for making the match hash.
    #we now generate the small terms hash using the old noosphere logic.
    # NOTE: this should be fast since we are dealing with a small subset
    my $terms = generateterms(\@cand);

    #add these terms to the big hash of terms.
    # WAS: %termlist = (%termlist, %{$terms});
    # What about overrides?
    foreach my $key(keys %$terms) {
      $termlist{$key} = $terms->{$key};
    }
    if (defined $terms->{$word}) {
      $fail = 0;
      #print "*** xref: found [$word] for [$tlist[$i]] in hash\n" if $COND;
      $rv = maximize_match(\%matches,
		      $word,$terms->{$word},
		      \@tlist,$tlen,$i);
      #	[$stag,$etag]);
      $fail = !$rv;
      if (!$rv) {
	#print "*** xref: rejected initial match for [$word]\n" if $COND;
      }
    }
    if ($fail) {
      if (is_possessive($word)) {
	#print "*** xref: trying unpossesive for [$word]\n" if $COND;
	$word = get_nonpossessive($word);
	$rv = maximize_match(\%matches,
			$word,$terms->{$word},
			\@tlist,$tlen,$i);
	#					[$stag,$etag]);
      } elsif (is_plural($word)) {
	#print "*** xref: trying nonplural for [$word]\n" if $COND;
	my $np = depluralize($word);
	$rv = maximize_match(\%matches,
			$word,$terms->{$np},
			\@tlist,$tlen,$i);
	#					[$stag,$etag]);
      } else {
	#print "*** xref: found no forms for [$word]\n" if $COND;
      }
    }
    # now lets update $i so we don't check terms that are already matched (this should speed up
    # the code quite a bit also.
    if ( defined ( $matches{$i} ) ) {
      my $mlen = $matches{$i}->{'length'};
      $i += $mlen;
      #print "MOVING $i forward $mlen\n" if $DEBUG;
    }
  }

  if ($DEBUG) {
    $finish = time();
    my $total = $finish - $start;
    my $len = keys %matches;
    #print "find matches: $total seconds to make $len matches\n";
  }

  #modify the matches hash to contain the candidate link information for each term.
  foreach my $pos (sort {$a <=> $b} keys %matches) {
    my $matchterms = $matches{$pos}->{'term'};
    $matchterms =~ /^([^\s]+)(\s|$)/;
    my $fw = lc($1);
    $matches{$pos}->{'candidates'} = $termlist{$fw}->{$matchterms};
  }
  return \%matches;
}



# generate a list of terms 
#
# this list takes the form of a hash-of-hashes.	The hash is of the 
# form first_word_of_term => { hash containing all matching term => name's}
#
# this allows us a quick answer to the question "is word X a term, or the
# prefix of a term", in what is optimally O(1) time.	We can then find the 
# largest matching word at the current position in what should be O(1) on 
# average, depending on how many terms on average share their first word with
# another term.
#
sub generateterms {
  my $candidates = shift;	# the array of hashrefs of candidates 
  # (concept, conceptid, objectid)
  my $terms={};			# terms hash
  # build firstword->{concept->{cid}, concept->{cid} ,...} hash
  #
  newterm($terms, $_) foreach (@$candidates);
  return ($terms);
}

# add to terms hash-of-hashes
sub newterm {
  my ($terms,$concepthash,$encoding) = @_;		#hash of terms to keep updating
  #$concepthash := hash of concept (firstword, concept, conceptid, objectid)
  $encoding //= '';
	
  my $fw = lc($concepthash->{'firstword'});
  my $concept = lc($concepthash->{'concept'});
  my $objectid = $concepthash->{'objectid'};
	
  # do the actual adding
  if ((! defined $terms->{$fw}) || (!defined $terms->{$fw}->{$concept})) {
    $terms->{$fw}->{$concept} = []; # create array
  } 
  push @{$terms->{$fw}->{$concept}}, $objectid;
}

# return true if "word" shouldn't be considered in matching
sub skipword {
  my $word = shift;
  return 1 if ($word =~ m/^\s*$/ );
  #	return 1 if ($word eq '__NL__');
  #	return 1 if ($word eq '__CR__');
  return 0;
}

# match the rest of a title after getting a first-word match.
#	
sub maximize_match {
  my $matches = shift; # matches structs we keep updated (pointer to hash)
  my $word = shift;    # first word in matched sequence
  my $subhash = shift; # hash of matching terms to $word
  my $tlist = shift;   # text words list (pointer to list)
  my $tlen = shift;    # text words count
  my $i = shift;       # position in text words list we're at

  return 0 if $word !~ /\w/;	# fail if blank input
  my ($start, $finish, $DEBUG);

  # find longest matching term from subhash
  # since sorting in reverse order, we stop at first (longest) match.
  my $matchterm = '';	  # this gets set to non "" if we have a match
  my $matchlen = 0;	  # length of match, the larger the better.
 
  foreach my $title (sort {lc($b) cmp lc($a)} keys %$subhash) {
    my $COND = 0;		# debug printing condition
    #print " *** xref: comparing $word to $title\n" if $COND;
    my @words = split(/\s+/,$title); # split into words
    # go through the words and make them non-plural and non-possessive
    foreach my $w ( @words ) {
      my $temp = depluralize ( get_nonpossessive ( $w ) );
      $w = $temp;
    }

    my $midx = 0;   # last matched index - we start at entry 0 matched
    my $widx = $#words;
    my $skip = 0;	 # text index adjuster based on skipped words 

    #print "*** xref: skip starts out as $skip\n" if $COND;
    #print "*** xref: next text word is $tlist->[$i+$skip+1]\n" if $COND;
    # see how many words we can match against this title
    while (($i+$midx+$skip+1 < $tlen) && ($midx<$widx)) {
      if (skipword($tlist->[$i+$midx+$skip+1]) ) {
	     $skip++;
      } else {
	     my $nextterm = lc(depluralize(get_nonpossessive($tlist->[$i+$midx+$skip+1])));
	     if ( $nextterm eq lc( $words[$midx+1] ) ) {
	     $midx++;		# update indexes
	     last if ( $midx == $widx );
	     #	$skip++ if (skipword($tlist->[$i+$midx+$skip+1])); 
      } else {
	     last;
    	}
	     #print " *** xref: matched word $tlist->[$i+$midx+$skip+1]\n" if $COND;
	     #print "*** xref: skip is now $skip\n" if $COND;
      }
    }
    #print " *** xref: skip is $skip\n" if $COND;

    # if we matched all words, store match info
    if ($midx == $widx) {	 
      $matchterm = $title;
      $matchlen = $widx + $skip + 1;
      #print " *** xref: matched all words, $midx = $widx\n" if $COND;
      #print " *** xref: matchterm is [$matchterm]" . 
      #" with length $matchlen\n" if $COND;
      last;
    }
  }

  # try to add match if we found one.
  if ($matchterm ne "") {
    insert_match($matches,$i,$matchterm,$matchlen);
  }
	 
  return ($matchterm eq "")?0:1; # return success or fail
}


# add to matches list - only if we found a better (larger) match for a position
sub insert_match {
  my ($matches,$pos,$term,$length)=@_;
  #my ($matches,$pos,$term,$length,$plural,$psv)=@_;
	
  # CHANGED : handling this at display time now to fix some behavior
  # check for term already being included, since we dont want repeats
  #return if (defined $mterms->{$term});

  my $COND = 0;			#DEBUGING
  # check for existing entry 
  if (defined $matches->{$pos}) {
    if ($matches->{$pos}->{'length'} < $length) {
      print "replacing $term at $pos, length $length with $term, length $length\n" if ($COND);
      $matches->{$pos}->{'term'} = $term;
      $matches->{$pos}->{'length'} = $length;
      #			$matches->{$pos}->{'plural'} = $plural;
      #			$matches->{$pos}->{'possessive'} = $psv;
      #			$matches->{$pos}->{'tags'} = $tags;
		
      # remove matches at positions within the newly extended boundary
      #
      for (my $i=$pos;$i<($pos+$length);$i++) {
	if (defined $matches->{$i}) {
	  #dwarn "removing $matches->{$i}->{term}, swallowed up by $term";
	  $matches->{$i}=undef;
	}
      }
    } else {
      #dwarn "not adding $term at $pos, length $length\n";
    }
  } 
	
  # nonexistant - insert
  #
  else {
    my $ppos = undef;
    my $safe = 1;
    foreach my $key (sort {$a <=> $b} keys %$matches) {
      last if ($key >= $pos);
      $ppos = $key;
    }
    if (defined $ppos) {
      $safe = 0 if ($pos < ($ppos + $matches->{$ppos}->{'length'}));
    } 
    if ($safe) {
      #warn "*** xref: adding match $term at $pos, length $length\n";
      $matches->{$pos}={
			'term'=>$term, 
			'length'=>$length };
      #	'plural'=>$plural,
      #	'possessive'=>$psv,
      #	'tags'=>$tags};
    } else {
      #dwarn "match $term at $pos is inside range of previous term at $ppos, not adding\n";
    }
  }
}

# keep track of manual links
#
sub doManualLinks {
  my $list = shift;
  my $fromid = shift;

  return unless ($fromid > 0);

  foreach my $id (@$list) {
    addLink($fromid,$id) if ($fromid);
  }
}

###########################################################################
#	xref stuff
###########################################################################

# invalidate all entries that link to an entry with the given indentifier
#
sub invalidateInlinks {
  my $objectid = shift;
	
  deleteLinksTo($objectid);

}



# call this when a title changes
# 
sub xrefChange {
  my $id = shift;
	
  # just delete all links to this object and invalidate cache
  deleteLinksTo($id);
}

# add a link from->to (if its not already there)
#
sub addLink {
  my ($db,$fromid,$toid)=@_;

  if ($fromid<0 || $toid<0 ) {
    #dwarn "we were passed a bad linking parameter: fromid=$fromid, toid=$toid";
    return;
  }

  #dwarn "*** xref: adding link table entry for $fromid -> $toid" if ($DEBUG);
  if (!linkPresent($fromid , $toid)) {
    my $sth = $db->prepare("INSERT into links (fromid, toid) VALUES (?, ?)");
    eval {
      $sth->execute($fromid, $toid);
      $sth-finish();
    };
  }
}

# see if a particular link is present in the db
# 
sub linkPresent {
  my ($db,$fromid,$toid)=@_;

  my $sth = $db->prepare("select fromid from links WHERE fromid = ? AND toid = ?");
  $sth->execute( $fromid, $toid );
  my $rc = $sth->rows();

  $sth->finish();

  return $rc?1:0;
}

# completely remove an item from the cross referencing links table
#
sub unlink {
  my $id = shift;

  deleteLinksTo($id);
  deleteLinksFrom($id);
}

# delete from links table all objects point *to* given object
#	 also invalidate their cache records.
#
sub deleteLinksTo {
  my ($db,$id) = @_;

  my $sth = $db->prepare("delete from links where toid = ?");
  eval {
    $sth->execute($id);
    $sth->finish();
  };
}

# delete all links *from* given object
#
sub deleteLinksFrom {
  my ($db,$id) = @_;
	
  return if ($id<0);		# sanity

  my $sth = $db->prepare("delete from links WHERE fromid = ?");
  eval {
    $sth->execute($id);	
    $sth->finish();
  };
	
}

sub getlinkedto {
  my ($db,$objid) = @_;
  my $sth = $db->prepare("select fromid from links where toid = ?");
  $sth->execute($objid);
  my @links = ();
  while (my $row = $sth->fetchrow_hashref() ) {
    push @links, $row->{'fromid'};
  }
	
  return @links;
}


# main entry point to graph categorization inference
#
sub getBestByBFS {
  my $rootid = shift;		# root id to enter the object graph
  my $homonyms = shift;		# list of homonym ids 
  my $depth = shift; # how deep to go into the graph. we have to be careful
		     # because entries have an average of 10 links, which 
		     # means that by the second level we are analyzing 100
		     # nodes!

  my $level = 1;	# initialize level
  my @queue = ();	# bfs queue
  my %seen;		# hash of ids we've seen (don't revisit nodes)

  # get classifications of the homonyms we are comparing against
  #
  my $hclass = [];
  foreach my $hid (@$homonyms) {
    push @$hclass, [getclass($hid)];	
  }
	
  push @queue,$rootid;

  $seen{$rootid} = 1;
  my $ncount = expandBFSQueue(\@queue,\%seen); # init list w/first level

  # each stage of this while loop represents a deeper "layer" of the graph
  my $w = -1;			# winner
  while ($w == -1 && $ncount > 0 && $level <= $depth) {
    #foreach my $node (@queue) {
    #	print "($level) $node\n";
    #}

    my @scores = scoreAgainstArray($hclass,\@queue);
    #foreach my $i (0..$#scores) {
    #	print "$level) $homonyms->[$i] scores $scores[$i]\n";
    #}
	
    $w = winner(\@scores);
    my $ncount = expandBFSQueue(\@queue,\%seen);	 
    $level++;
  }

  return $w;			# return winner index (or -1)	
}

# select the winning index out of an array of scores, -1 if indecisive
#
sub winner {
  my $scores = shift;

  my $top = -1;				
  my $topidx = -1;

  foreach my $i (0..scalar @{$scores}-1) {
    my $score = $scores->[$i];
    if ($score > $top) {
      $top = $score;
      $topidx = $i;
    } elsif ($score == $top) {
      return -1;		# if we have a single tie, we fail
    }
  }

  return $topidx;
}

# returns an array which gives the score for each node in the input homonym
# list, which represents how much each homonym's classification coincides with
# the aggregate of the classifications on the input object list
#
sub scoreAgainstArray {
  my $class = shift;
  my $array = shift;

  my @scores = ();
  my @carray = ();
	
  # get classification for the array items
  #
  foreach my $a (@$array) {
    #print "getting class for $a\n";
    my $fetchc = [getclass($a)];
    push @carray,$fetchc if ($fetchc->[0]);
  }

  # loop through each input classification and score it
  #
  foreach my $ca (@$class) {
    my $total = 0;
    foreach my $cb (@carray) {
      #print "comparing a={$ca->[0]->{ns},$ca->[0]->{cat}, b={$cb->[0]->{ns},$cb->[0]->{cat}}\n";
      $total += classCompare($ca,$cb);
    }
    push @scores,$total;
  }

  return @scores;
}

# expand id queue by pushing all the nodes immediately connected onto it
#
sub expandBFSQueue {
  my $queue = shift;
  my $seen = shift;
	
  my $count = scalar @{$queue};	# we're going to remove current elements
  #	print "count on queue $count\n";

  my @neighbors = xrefGetNeighborListByList($queue,$seen);
  push @$queue,@neighbors;
  splice @$queue,0,$count;	# delete front elements

  return scalar @neighbors;	# return count of novel nodes
}

# pluralize the below, throwing out things in 'seen' list
#
sub xrefGetNeighborListByList {
  my $sources = shift;
  my $seen = shift;
 
  my @outlist = ();		# initialize output list
	
  foreach my $sid (@$sources) {
    my @list = xrefGetNeighborList($sid);
    foreach my $nid (@list) {
      if (! defined $seen->{$nid}) { # add only novel items
	       push @outlist,$nid;
	       $seen->{$nid} = 1;	 
      }
    }
  }

  return @outlist;
}

# get a list of "neighbors" in the cross_reference graph, from a particular
# node (i.e. nodes the source node can "see" or has outgoing links to)
#
sub xrefGetNeighborList {
  my ($db,$source) = @_;

  my @list = ();

  my $sth = $db->prepare("select toid from links where fromid = ?");
  $sth->execute($source);

  while ( my $row = $sth->fetchrow_hashref() ) {
    push @list,$row->{'toid'};
  }

  return @list;
}

# compare and score two classifications against each other.	gives a count
# of the coinciding categories.
#
# TODO: perhaps make this smarter than just brute force O(nm) where n and m
# are the lengths of each classification
#
sub classCompare {
  my $classa = shift;
  my $classb = shift;

  my $total = 0;
	
  foreach my $cata (@$classa) {
    foreach my $catb (@$classb) {
      $total += catCompare($cata,$catb);
    }
  }

  return $total;
}

# an elementary operation... compare two classification hashes to determine if
# they are "equal" (in the same scheme, in the same section)
#
sub catCompare {
  my $a = shift;
  my $b = shift;

  # TODO: make this handle mappings between schemes
  #			 also, handlers for other schemes

  #print "comparing categories {$a->{ns},$a->{cat}}, {$b->{ns},$b->{cat}}\n";

  return 0 if ($a->{ns} ne $b->{ns});

  if ($a->{ns} eq 'msc') {
    $a->{cat} =~ /^([0-9]{2})/;
    my $aprefix = $1;
    $b->{cat} =~ /^([0-9]{2})/;
    my $bprefix = $1;

    return 1 if ($aprefix eq $bprefix);
  }

  # TODO: handlers for other schemes?

  return 0;
}

sub spaceOutHTML {
  my $text = shift;
  $text =~ s/</ </g;
  $text =~ s/>/> /g;
  return $text;
}


1;

__END__
