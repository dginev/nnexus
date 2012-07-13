package NNexus;
use strict;

use Encode qw{is_utf8};
use Time::HiRes qw ( time alarm sleep );

use NNexus::Classification;
use NNexus::Latex;
use NNexus::Morphology;
use NNexus::Linkpolicy;
use NNexus::Concepts;
use NNexus::Object;
use NNexus::Util;


# tags which allow linking to their contents
#
use vars qw{%LINKTAGS};

%LINKTAGS = (
	'PMlinkescapeword'=>1,
	'PMlinkescapephrase'=>1,
);

#new main entry paint for cross-referencing, you send it an preprocessed text
# and it returns a match array for the text with the link targets with position
# information.
sub crossReference {
	my $domain = shift; #domain of the object;
	my $text = shift;  #preprocessed text array ref of the object;
	my $nolink = shift;  #terms to not link to:
				#includes synonyms, user escaped, blacklisted terms
				# and phrases
	my $class = shift; #class of the object;
	my $fromid = shift || -1;
	
	#print "Cross-referencing $title";

	# delete old outgoing links
	#
	deleteLinksFrom( $fromid ) if ($fromid > 0);

	# do automatic linking
	#
	my ($matches, $terms) = findmatches( $text );
	#we need to disambiguate the matches here and mark active matches. 
	my %linked;  #used to mark active links and targets 
	foreach my $pos (sort {$a <=> $b} keys %$matches) {
		my $matchterms = $matches->{$pos}->{'term'};
		next if ($linked{$matchterms});
		my $anchor = getanchor($matches->{$pos});	
		next if (inset(lc($anchor),@$nolink));
		my $finals = disambiguate($terms, $matchterms, $class, $fromid);
		$linked{$matchterms} = $finals; #mark the term as linked with the optional targets
		$matches->{$pos}->{'active'}=1;	# turn the link "on" in the matches hash
		$matches->{$pos}->{'links'} = $finals; #save the link targets in the matches hash.
	}

	#loop through the matches and delete those matches that are no longer active
	foreach my $pos ( keys %$matches) {
		if ( not defined $matches->{$pos}->{'active'} ){
			print "deleting $pos for term " . $matches->{$pos}->{'term'} . "\n";
			delete $matches->{$pos};
		}
	}
	print "Matches and links for object $fromid and $domain with class:\n";
	print Dumper( $class );
	print Dumper( $matches );
	#print Dumper( \%linked );
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

sub newCrossReferenceLaTeX {
	my $domain = shift;
	my $latex = shift;
	my $title = shift;		# title of the object
	my $method = shift;
	my $syns = shift;		# synonyms, more things not to link to
	my $fromid = shift||-1;	# from id - if this is null or -1, we dont touch links tbl
	my $class = shift;		# classification array
	
	#print "Cross-referencing $title";

	# fix l2h stuff
	#
	$latex = l2hhacks($latex) if ($method eq 'l2h');
	
	# separate math from linkable text, and do some massaging
	#
	my @user_escaped;
	my $escaped;
	my $linkids;

	($latex,@user_escaped) = getEscapedWords($latex);
	($latex,$escaped,$linkids) = splitPseudoLaTeX($domain, $latex, $method);
	
	$latex = preprocessLaTeX($latex);
	my ($nonmath,$math) = splitLaTeX($latex, $escaped);

	my @blacklist = ( 'g', 'and','or','i','e', 'a','means','set','sets',
			'choose', 'it',  'o', 'r');
	my $domainbl = getdomainblacklist( $domain );

	foreach my $dbl ( @$domainbl ) {
		push @blacklist, lc($dbl);
	}
	foreach my $bl (@blacklist) {
		push @user_escaped,lc($bl);
	}	
	foreach my $k ( keys %$syns ) {
		push @user_escaped, lc($k);
	}

	push @user_escaped, lc($title);

	#lets just see what happens here.
	my $matches = crossReference( $domain, $nonmath, \@user_escaped, $class, $fromid ); 
	
	my ($linked,$links) = makelinks($domain, $nonmath,$math,$terms,$matches,
								$class,$fromid,\@user_escaped);
	
	my $recombined = recombine($linked, $math, $escaped);
	
	return (postprocessLaTeX($recombined),$links);
}


# crossReferenceLaTeX - main entry point for cross-referencing, you send it
# some LaTeX and it returns the same text, but with
# hyperlinks. Tres convenient, no?
#
sub crossReferenceLaTeX {
	my $domain = shift;
	my $latex = shift;
	my $title = shift;		# title of the object
	my $method = shift;
	my $syns = shift;		# synonyms, more things not to link to
	my $fromid = shift||-1;	# from id - if this is null or -1, we dont touch links tbl
	my $class = shift;		# classification array
	
	#print "Cross-referencing $title";

	# delete old outgoing links
	#
	deleteLinksFrom( $fromid ) if ($fromid > 0);
	

	# fix l2h stuff
	#
	$latex = l2hhacks($latex) if ($method eq 'l2h');
	
	# separate math from linkable text, and do some massaging
	#
	my @user_escaped;
	my $escaped;
	my $linkids;

	($latex,@user_escaped) = getEscapedWords($latex);
	($latex,$escaped,$linkids) = splitPseudoLaTeX($domain, $latex, $method);
	
	$latex = preprocessLaTeX($latex);
	my ($nonmath,$math) = splitLaTeX($latex, $escaped);

	#print $nonmath;

	# handle manual linking metadata
	# 
	doManualLinks($linkids, $fromid);

	# do automatic linking
	#
	
	#from here down needs to be rewritten. note that we should never have to pass
	# in the concepts hash or ever return it. We use the DB now.
	#print "starting automatic linking $title : $fromid\n";
	#print Dumper( [$syns] );
	
	my ($matches, $terms) = findmatches( $nonmath );
	foreach my $k ( keys %$syns ) {
		push @user_escaped, lc($k);
	}
	
	my ($linked,$links) = makelinks($domain, $nonmath,$math,$terms,$matches,
								$class,$fromid,\@user_escaped);
	
	my $recombined = recombine($linked, $math, $escaped);
	
	return (postprocessLaTeX($recombined),$links);
}


# handle figuring out the URLs for the \PMlinktofile pseudo-command
# \PMlinktofile directives get left after cross-referencing
#
sub dolinktofile {
	my $latex = shift;
	my $table = shift;	 
	my $id = shift;			# object id

	my $fileserver = getAddr('files');

	while ($latex =~ /\\PMlinktofile\{(.+?)\}\{(.+?)\}/s) {
		my $anchor = $1;
		my $filename = $2;
		my $url = protectURL("http://$fileserver/files/$table/$id/$filename");
		$latex =~ s/\\PMlinktofile\{.+?\}\{.+?\}/\\htmladdnormallink{$anchor}{$url}/s;
		#$latex=~s/\\PMlinktofile\{.+?\}\{.+?\}/$url/s;
	}

	return $latex;
}



# disambiguate a link
#
# disambigute now returns a hash of list of the form
#a->{domain} =  [ [internalobjectid,  score], [..] ... ] 
#a->{domain2} = [ [internalobjectid2, score2] , []... ] 
#in the future this function will sort the results by score. but for now we assume
# that the first object is the one to use since we have no scoring metrics as of yet.
sub disambiguate {
	my $terms = shift;
	my $title = shift;
	my $classes = shift;
	my $fromid = shift;

	my @tempclass = ();

	my %scorelist = ();
	
	#print Dumper($classes);
	
	my ($start, $finish, $DEBUG);
	$DEBUG = 1;
	
	if ($DEBUG) { $start = time(); }
		
	# get array of ids of qualifying entries
	#
	$title =~ /^([^\s]+)(\s|$)/;
	my $fw = lc($1);

	#print Dumper( $terms );
	
	my @ids = @{$terms->{$fw}->{$title}};
	@ids = post_resolve_linkpolicy($fromid, $title, $classes, @ids); #speed is good

	my %domainobjects = (); # {domainid}->[list of objects, in domain] 
	foreach my $id ( @ids ) {
		my $obj = getobjecthash($id);
		push @{$domainobjects{$obj->{'domainid'}}}, $id;
	}


	if ( $DEBUG ) {
		print "Disambiguating $title\n";
		print "BEFORE classification = @ids\n";
		my $num = $#ids+1;
		print "BEFORE num = $num\n";
	#	print Dumper( \%domainobjects );
	}

	my @ids = ();
	foreach my $k ( keys %domainobjects ) {
		push @ids, disambiguate_classification( $classes, $k, 
				@{$domainobjects{$k}} );
	}

		
	if ( $DEBUG ) {
		print "AFTER classification = @ids\n";
		my $num = $#ids+1;
		print "AFTER num = $num\n";
	}
	
#moved this up in the logic where it should be
	#@ids = post_resolve_linkpolicy($fromid, $title, $classes, @ids); #speed is good
	foreach my $j ( @ids ) {
		my $obj = getobjecthash($j);
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
	
	if ($DEBUG) { $start = time(); }

	
	# if nothing above produced a single winner id, do the graph method
	#
	if ($#toplist > 0) {
		
		# do the BFS traversal
		my $winner = getBestByBFS($fromid, \@toplist, 2);
		dwarn "*** link score: winner (for $fromid) by graph walking is $toplist[$winner]\n", 2;
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
	my $class = shift;
	my $domain = shift;	# this will be implemented in SOC 2007
	my @ids = @_;

#	print Dumper( $class );

	my @classes = ();
	my @cstrings = ();

	my $min = 10000000;
	my @toplist = ();	# list of top scored entries
	#my @topclass = ();	# their classifications
	
	my ($start, $finish, $DEBUG);
	$DEBUG = 1;
	
	if ($DEBUG) { $start = time(); }
	my @blah = ();
	foreach my $j ( @{$class} ) {
		push @blah, $j->{'scheme'} . ":" . $j->{'externalid'};
	}

	my $temp = normalizeclass(join(", ", @blah) );
	print "$temp\n";
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
			my ($str, $cf) = classinfo( $id );
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
					my $d = class_distance( $c1, $c2 );
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

		if ($#toplist > 0) {
			print "*** warning -- link score: tie\n";
			print "@toplist\n";
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

# get a score: this ranks the current object against a potential match
# by comparing how much their classifications coincide (order counts).
# this is boiled down into a single number which serves as a metric.
#
#This is old classification code. Left here for archival purposes.
#
#sub getscore {
#	my ($b_,$c_) = @_;
#
#	my @base = @$b_;
#	my @compare = @$c_;
#
#	my ($start, $finish, $DEBUG);
#	
#	return 0 if ($#compare<0);
#	return 0 if ($#base<0);
#
#	my %chash;
#
#	# determine the match set 
#	#
#	my $cc = scalar @compare;
#	my $i = $cc;
#	foreach my $c (@compare) {
#		# make the value for a match decrease based on position.  max is 
#		# 1 = #cats/#cats, min is 1/#cats
#		$chash{$c} = $i/$cc;	
#		$i--;
#	}
#
#	# calculate match points
#	#
#	my $points = 0;
#	foreach my $b (@base) {
#		if (exists $chash{$b}) {
#			$points += $chash{$b};
#		}
#	}
#	
#	# normalize matches by log # of cats. the goal of this is to favour 
#	# matches to entries which are "more precisely" a match for the input 
#	# set of categories
#	#
#	my $score = $points * 1/(1 + log($#base+1));
#	
#	return $score;
#}

# pull an object unique name from our two-level terms hash, based on title
#
#sub getnamebytitle {
#	my $terms = shift;
#	my $title = shift;
#
#	# pull out first word of term
#	#
#	$title =~ /^([^\s]+)(\s|$)/;
#	my $fw = lc($1);
#	#dwarn "looking up name for title $title, prefix $fw";
#
#	my $subhash = $terms->{$fw};
#	return $subhash->{$title};
#}

# make links in the LaTeX - combine matches info hash with the text
#
my %menuhash = (); # this is the menuhash used for the above mentioned purpose.
sub makelinks {
	my $domain = shift; 	#the domain we are linking
	my $text = shift;		# entry text
	my $math = shift;		# entry math.. so we can check for sentence ends
	my $terms = shift;		# object names hash
	my $matches = shift;	# match structure
	my $class = shift;		# classification arrayref of current object
	my $fromid = shift;		# id of current object (or -1)
	my $escaped = shift;    # user escaped words/phrases
	
	my @linkarray;			# array of href's
	my %linked;				# linked titles
	my %clinked;			# linked concepts

	my ($start, $finish, $DEBUG);
	$DEBUG = 0;
	
	if ($DEBUG) { $start = time(); }


	my $priorities = getdomainpriorities( $domain );
	foreach my $pos (sort {$b <=> $a} keys %$matches) {
		#dwarn "*** makelinks: looking at term ".$matches->{$pos}->{'term'};
		
		my $active = $matches->{$pos}->{'active'};
		next if (not $active);
	
		my $matchtitle = $matches->{$pos}->{'term'};
		my $length = $matches->{$pos}->{'length'};
		my $tags = $matches->{$pos}->{'tags'};
	
		my $objects = $linked{$matchtitle};
		
		#we don't want to get the name anymore since we don't keep it, we want to link by objectid
		my $listanchor = getanchor($matches->{$pos});
		# pull quotes/brackets out of boundary linked text
		#
		my ($left, $right) = outertags($tags);
		my $lltext = $ltext[$pos];
		my $rltext = $ltext[$pos+$length-1];
		$lltext =~ s/^\Q$left\E//;
		if ($length > 1) {
			$rltext =~ s/\Q$right\E$//;
		} else {
			$lltext =~ s/\Q$right\E$//;
		}

		# integrate hyperlink commands into output linked text
		#
		
		# create the external domain link string
		
	#objects is the hasref called finals above
		my $texttolink = "";
		$texttolink = join( " ", @ltext[$pos..$pos+$length-1] );
	#	print "Making link string for " . Dumper($objects) . "\n";
		makelinkstring( $objects, $left, $right, \$ltext[$pos], \$ltext[$pos+$length-1], $texttolink, $priorities );
				
		# add to simple links list 
		#
		my $lnk = getlinkstring( $objects, $listanchor );
		
		# push @linkarray, mathTitle($lnk, 'highlight');
		
		push @linkarray, $lnk;
	
		# add to links table if we have a from id
		# 
#TODO - figure out how to do the addlinks in the database 
	#	addLink($fromid,$object->{'objectid'}) if ($fromid);
	}
		
	my $finaltext = join(' ',@ltext);

	#loop through the menuhash and generate the menucode
#var menu1=new Array()
#menu1[0]='<a href="http://www.javascriptkit.com">JavaScript Kit</a>'
#menu1[1]='<a href="http://www.freewarejava.com">Freewarejava.com</a>'
#menu1[2]='<a href="http://codingforums.com">Coding Forums</a>'
#menu1[3]='<a href="http://www.cssdrive.com">CSS Drive</a>'

#	print Dumper( \%menuhash );


	#
	#Build the dynamic menu code for linking one term to multiple sites
	#
	my $menucode = "";
	for my $menukey ( keys( %menuhash ) ) {
	#	print "Building dynamic menu $menukey\n";
		my $tempa = $menuhash{$menukey};
		$menucode .= "var $menukey = new Array()\n";
		my $i = 0;
		foreach my $t ( @$tempa ) {
	#		print Dumper($t);
			my $link = $$t[0];
			my $nick = $$t[1];
			$menucode .= "$menukey" . "[$i]=\'<a href=\"$link\">$nick</a>\'\n";
			$i++;
		}
	}

	# print $menucode;

#here is the javascript code
my $script = <<'EOF';
<script type="text/javascript">
/***********************************************
* AnyLink Drop Down Menu- Â© Dynamic Drive (www.dynamicdrive.com)
* This notice MUST stay intact for legal use
* Visit http://www.dynamicdrive.com/ for full source code
***********************************************/
EOF

#insert contents of menus
$script .= $menucode;

$script .= <<'EOF';
var menuwidth='20em' //default menu width
var menubgcolor='lightyellow'  //menu bgcolor
var disappeardelay=250  //menu disappear speed onMouseout (in miliseconds)
var hidemenu_onclick="yes" //hide menu when user clicks within menu?

/////No further editting needed
var ie4=document.all
var ns6=document.getElementById&&!document.all

if (ie4||ns6)
document.write('<div id="dropmenudiv" style="visibility:hidden;width:'+menuwidth+';background-color:'+menubgcolor+'" onMouseover="clearhidemenu()" onMouseout="dynamichide(event)"></div>')

function getposOffset(what, offsettype){
var totaloffset=(offsettype=="left")? what.offsetLeft : what.offsetTop;
var parentEl=what.offsetParent;
while (parentEl!=null){
totaloffset=(offsettype=="left")? totaloffset+parentEl.offsetLeft : totaloffset+parentEl.offsetTop;
parentEl=parentEl.offsetParent;
}
return totaloffset;
}


function showhide(obj, e, visible, hidden, menuwidth){
if (ie4||ns6)
dropmenuobj.style.left=dropmenuobj.style.top="-500px"
if (menuwidth!=""){
dropmenuobj.widthobj=dropmenuobj.style
dropmenuobj.widthobj.width=menuwidth
}
if (e.type=="click" && obj.visibility==hidden || e.type=="mouseover")
obj.visibility=visible
else if (e.type=="click")
obj.visibility=hidden
}

function iecompattest(){
return (document.compatMode && document.compatMode!="BackCompat")? document.documentElement : document.body
}

function clearbrowseredge(obj, whichedge){
var edgeoffset=0
if (whichedge=="rightedge"){
var windowedge=ie4 && !window.opera? iecompattest().scrollLeft+iecompattest().clientWidth-15 : window.pageXOffset+window.innerWidth-15
dropmenuobj.contentmeasure=dropmenuobj.offsetWidth
if (windowedge-dropmenuobj.x < dropmenuobj.contentmeasure)
edgeoffset=dropmenuobj.contentmeasure-obj.offsetWidth
}
else{
var topedge=ie4 && !window.opera? iecompattest().scrollTop : window.pageYOffset
var windowedge=ie4 && !window.opera? iecompattest().scrollTop+iecompattest().clientHeight-15 : window.pageYOffset+window.innerHeight-18
dropmenuobj.contentmeasure=dropmenuobj.offsetHeight
if (windowedge-dropmenuobj.y < dropmenuobj.contentmeasure){ //move up?
edgeoffset=dropmenuobj.contentmeasure+obj.offsetHeight
if ((dropmenuobj.y-topedge)<dropmenuobj.contentmeasure) //up no good either?
edgeoffset=dropmenuobj.y+obj.offsetHeight-topedge
}
}
return edgeoffset
}

function populatemenu(what){
if (ie4||ns6)
dropmenuobj.innerHTML=what.join("")
}


function dropdownmenu(obj, e, menucontents, menuwidth){
if (window.event) event.cancelBubble=true
else if (e.stopPropagation) e.stopPropagation()
clearhidemenu()
dropmenuobj=document.getElementById? document.getElementById("dropmenudiv") : dropmenudiv
populatemenu(menucontents)

if (ie4||ns6){
showhide(dropmenuobj.style, e, "visible", "hidden", menuwidth)
dropmenuobj.x=getposOffset(obj, "left")
dropmenuobj.y=getposOffset(obj, "top")
dropmenuobj.style.left=dropmenuobj.x-clearbrowseredge(obj, "rightedge")+"px"
dropmenuobj.style.top=dropmenuobj.y-clearbrowseredge(obj, "bottomedge")+obj.offsetHeight+"px"
}

return clickreturnvalue()
}

function clickreturnvalue(){
if (ie4||ns6) return false
else return true
}

function contains_ns6(a, b) {
while (b.parentNode)
if ((b = b.parentNode) == a)
return true;
return false;
}

function dynamichide(e){
if (ie4&&!dropmenuobj.contains(e.toElement))
delayhidemenu()
else if (ns6&&e.currentTarget!= e.relatedTarget&& !contains_ns6(e.currentTarget, e.relatedTarget))
delayhidemenu()
}

function hidemenu(e){
if (typeof dropmenuobj!="undefined"){
if (ie4||ns6)
dropmenuobj.style.visibility="hidden"
}
}

function delayhidemenu(){
if (ie4||ns6)
delayhide=setTimeout("hidemenu()",disappeardelay)
}

function clearhidemenu(){
if (typeof delayhide!="undefined")
clearTimeout(delayhide)
}

if (hidemenu_onclick=="yes")
document.onclick=hidemenu

</script>
EOF
	#we need to add the script info to the final text
	my $scriptstuff = "\n" . '\begin{rawhtml}' . "\n";
	$scriptstuff .= $script;
	$scriptstuff .= "\n" . '\end{rawhtml}' . "\n";

	#print $scriptstuff;

	$finaltext = $scriptstuff . $finaltext;
	
	if ($DEBUG) {
		$finish = time();
		my $total = $finish - $start;
		print "makelinks: $total seconds to make " . ($#linkarray+1). " links\n";
	}

	
	return ($finaltext, \@linkarray);
}

#this function returns a standard <a href=link> string
sub getlinkstring{ 
	my $object = shift;
	my $anchor = shift;

	my $domain = getdomainhash( $object->{'domainid'} );
	my $linkstring = $domain->{'urltemplate'} . $object->{'identifier'};

	
	return "<a href=\"$linkstring\">$anchor</a>";
}

#
# make the link string in the form of latex or whatever wrapped around urltemplate . externalobjectid
#
# remember this function makes the link string for one phrase or concept label in the object. I.e. this function
# is called multiple times (once for each linked concept).

my $nummenus = 0; #this global is used to keep track of the number of menus necessary to add to the javascript
			#that will be generated.
sub makelinkstring{
	my $objects = shift;
	my $left = shift;
	my $right = shift;
	my $textbegin = shift; #scalar reference to first position linked text array
	my $textend = shift; 
	my $texttolink = shift;
	my $priorities = shift; #this is needed for the domain priorities (i.e. which domain to link to first 
	
	#a->{domain} =  [ [internalobjectid, score], [..] ... ] 
	#a->{domain2} = [ [internalobjectid2, score2] , []... ] 

	my @larray = (); #this is the array of alternate links.
	my $lstring = ""; #link string

	my $first = 0; #this is used to mark whether or not the first link had been added to the
			#string to be linked
	
	my @optionallinks = (); #array list of optional links for a concept
	my $menuname = "menu" . $nummenus;

	#this sort function needs to be based on the domain priority rather than using
	# for each

	#the <a> class is set = to the domain nickname provided by the user. 
	#This allows for user customizable stylesheets for how the links appear
	# in the browser.
	foreach my $k ( @$priorities ) {
		if ( ! defined $objects->{$k} ) {
			next;
		}
		
		#print Dumper( $objects->{$k} );
	
		my $domain = getdomainhash( $k );
		#this is very hackish but works until we get the scoring functionality working
		my $id = ${$objects->{$k}}[0];
		if ( ref ($id) ) {
			$id = ${@$id}[0];
		}
		#print $id;
		my $identifier = getobjecthash($id)->{'identifier'};
		my $linkstring = $domain->{'urltemplate'} . $identifier;

#		print "adding : " . $linkstring . "\n";
		my $domainnick = $domain->{'nickname'};
		#my $size = length($domainnick) . 'em';
		my $size = "13em";

#		print "making link to $domainnick\n";
		if ( $first == 0 ) {
			my $htmlonly = "\n" . '\begin{rawhtml}' . "\n";
			$htmlonly .= "<a class=\"$domainnick\" href=\"$linkstring\" onClick=\"return clickreturnvalue()\" onMouseover=\"dropdownmenu(this, event, $menuname, '$size')\" onMouseout=\"delayhidemenu()\">"; 
			$htmlonly .= $texttolink;
			$htmlonly .= "</a>\n";
			$htmlonly .= '\end{rawhtml}';
			$$textbegin =  $left. $htmlonly. "\n" .'\begin{latexonly}' . "\n" . '\htmladdnormallink{'.notagsleft($$textbegin);
			$$textend = notagsright($$textend) . '}{' . $linkstring . '}' . $right;	
			$first = 1;
		} else {
			push @larray, 
				'{\scriptsize \{\htmladdnormallink{'.$domain->{'code'}.'}{'.$linkstring.'}\} }';
		}
		push @optionallinks, [$linkstring, $domainnick];
	}
	$menuhash{$menuname} = \@optionallinks;
	$nummenus++;
	$lstring = join('', @larray);
	$$textend = $$textend . $lstring . "\n" . '\end{latexonly}' . "\n";	
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

	my @tagged = ();	# array of tagged words

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
		$anchor = getpossessive($term);
	} 
	if ($plural == 1) {
		$anchor = pluralize($term);
	}

	return $anchor;
}

# build a match description structure based on text and synonyms list
#
sub findmatches {
	my $text = shift;

	my ($finish, $DEBUG);
	$DEBUG = 0;
	
	my $start = time() if ($DEBUG);

	my %termlist = ();
	
	#dwarn "*** xref: text is [$text]";
#
#? this was already done so why do again?
#
	#($text,) = getEscapedWords($text);	# pull out \PMlinkescapeword/phrase
	my @tlist = split(/\s+/,$text);

	my %matches;	 # main matches hash (hash key is word position)
	
	#my $terms = \%terms;

	# loop through words in the text. this is the O(m) main loop.
	my $tlen = $#tlist+1;
	for (my $i = 0; $i < $tlen; $i++) {

		my $stag = getstarttag($tlist[$i]);	# get tags around first word 
		my $etag = getendtag($tlist[$i]);			

		# if the word is of the form @@\d+@@, ##\d+##, __\w+-- we skip it
		my $word = $tlist[$i];
		if ( $word =~ /\@\@\d+\@\@/ || $word =~ /\#\#\d+\#\#/ || $word =~ /__\w+__/ ){
		#	print "skipping special word: $word\n";
			next;
		} 
		
		my $word = bareword($tlist[$i]);
		#print "building matches for $word\n";
		my $COND = 0;	 # turn this to 1 to debug this portion
	
		# look for the first word, then try to match additional words
		#
		my $rv = 0;
		my $fail = 1;
		
		#we now try to mimic the logic below using the uber-fast concepthash
		# so we now have the word and we try to find the longest phrase match
		# from the database
		
		#we begin be pulling all possible matches from the database including when the
		# word is not possessive and not plural.
		
		#since the first word is guaranteed to exist in nonplural and nonposessive
		
		my @cand = getpossiblematches( $word );
		
		# notice that here we get all possible candidates for both posessive and plural if the
		# $word was either - the old code should clean up the duplicates.
		
		#if we still have no candidates then we don't link the word
		if ($#cand < 0){ next; }
		
		#now we have the candidates
		
		#if we removed all the candidates go on to the next word.
		if ($#cand < 0 ){ next; }
		
		#now figure out the code for making the match hash.
		#we now generate the small terms hash using the old noosphere logic.
		# NOTE: this should be fast since we are dealing with a small subset
		
		my $terms = generateterms(\@cand);
		
		
		#add these terms to the big hash of terms.
		%termlist = (%termlist, %{$terms});

		if (defined $terms->{$word}) {
			$fail = 0;
			print "*** xref: found [$word] for [$tlist[$i]] in hash\n" if $COND;
			$rv = matchrest(\%matches,
						$word,$terms->{$word},
						\@tlist,$tlen,$i,
						[$stag,$etag]);
			$fail = !$rv;
			if (!$rv) {
				print "*** xref: rejected initial match for [$word]\n" if $COND;
			}
		}
		if ($fail) {
			if (ispossessive($word)) {
				print "*** xref: trying unpossesive for [$word]\n" if $COND;
				$word = getnonpossessive($word);
				$rv = matchrest(\%matches,
					$word,$terms->{$word},
					\@tlist,$tlen,$i,
					[$stag,$etag],1);
			} elsif (isplural($word)) {
				print "*** xref: trying nonplural for [$word]\n" if $COND;
				my $np = depluralize($word);
				$rv = matchrest(\%matches,
					$word,$terms->{$np},
					\@tlist,$tlen,$i,
					[$stag,$etag],
					undef,1);
				} else {
					print "*** xref: found no forms for [$word]\n" if $COND;
				}
		}
	}

	if ($DEBUG) {
		$finish = time();
		my $total = $finish - $start;
		my $len = keys %matches;
		print "find matches: $total seconds to make $len matches\n";
	}

	
	return \%matches, \%termlist;	
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
	my $candidates = shift; # the array of hashrefs of candidates (concept, conceptid, objectid)
	my %terms;			# terms hash
	# build firstword->{concept->{cid}, concept->{cid} ,...} hash
	#
	foreach my $cand (@{$candidates}) {
		newterm(\%terms, $cand);
	}	
	return (\%terms);
}

# add to terms hash-of-hashes
#
sub newterm {
	my $terms = shift;		#hash of terms to keep updating
	my $concepthash = shift;	#hash of concept (firstword, concept, conceptid, objectid)
	my $encoding = shift || '';
	
	my $fw = lc($concepthash->{'firstword'});
	my $concept = lc($concepthash->{'concept'});
	my $objectid = $concepthash->{'objectid'};
	
	# do the actual adding
	#
	if (not defined $terms->{$fw} || not defined $terms->{$fw}->{$concept}) {
		$terms->{$fw}->{$concept} = [];	# create array
	} 
	push @{$terms->{$fw}->{$concept}}, $objectid;
}

# return true if "word" shouldn't be considered in matching
#
sub skipword {
	my $word = shift;

	return 1 if ($word eq '__NL__');
	return 1 if ($word eq '__CR__');

	return 0;
}

# match the rest of a title after getting a first-word match.
#	
sub matchrest {
	my $matches = shift;	# matches structs we keep updated (pointer to hash)
	my $word = shift;		# first word in matched sequence
	my $subhash = shift;	# hash of matching terms to $word
	my $tlist = shift;		# text words list (pointer to list)
	my $tlen = shift;		# text words count
	my $i = shift;			# position in text words list we're at
	my $tags = shift;		# array of tags
	
	my ($start, $finish, $DEBUG);
	
	# fail if blank input
	return 0 if $word =~ /^\s*$/;

	# optional parameters
	my $psv = shift || 0;		# append possessive flag
	my $plural = shift || 0;	# gets set to 1 if ending word was plural
 
		
	# find longest matching term from subhash
	# since sorting in reverse order, we stop at first (longest) match.
	#
	my $matchterm = '';		# this gets set to non "" if we have a match
	my $matchlen = 0;		# length of match, the larger the better.
	my @mtags;				# match tags
 
	foreach my $title (sort {lc($b) cmp lc($a)} keys %$subhash) {
		my $COND = 0;						# debug printing condition
		#my $COND=($word=~/^banach/i);		# debug printing condition
		print " *** xref: comparing $word to $title\n" if $COND;

		@mtags = ();						# reset match tags
		my @words = split(/\s+/,$title);	# split into words
		# go through the words and add in non-plural and non-possessive
		foreach my $w ( @words ) {
			my $temp = depluralize ( getnonpossessive ( $w ) );
			if ( $w ne $temp ) {
				push @words, $temp;
			}
		}
		

		my $midx = 0;	# last matched index - we start at entry 0 matched
		my $widx = $#words;
		my $skip = 0;	# text index adjuster based on skipped words 
		my $saccum = 0;	# accumulator of total skipped words within match
		my $squeue = 0;	# queued (not yet saved) skipped words
		
		# see how many words we can match against this title
		
		if (skipword($tlist->[$i+1])) {
			$skip++;
			$squeue++;
		} 
		print "*** xref: skip starts out as $skip\n" if $COND;
		print "*** xref: text word is $tlist->[$i+1]\n" if $COND;
		while (($i+$midx+$skip+1 < $tlen) && 
				 ($midx<$widx ) && 
			 (bareword($tlist->[$i+$midx+$skip+1]) eq lc($words[$midx+1]))) {

			print " *** xref: matched word $tlist->[$i+$midx+$skip+1]\n" if $COND;

			push @mtags,getstarttag($tlist->[$i+$midx+$skip+1]); # keep tags
			push @mtags,getendtag($tlist->[$i+$midx+$skip+1]);
		
			$midx++;			# update indexes
			if (skipword($tlist->[$i+$midx+$skip+1])) {
				$skip++;
				$squeue++;
			} else {
				$saccum += $squeue;
				$squeue = 0;
			}
			print "*** xref: skip is now $skip\n" if $COND;
		}

		print " *** xref: skip is $skip\n" if $COND;

		# if we matched all words, store match info
		#
		if ($midx == $widx) {	 
			print " *** xref: matched all words, $midx = $widx\n" if $COND;
			$matchterm = $title;
			$matchlen = $widx + $saccum + 1;
			print " *** xref: matchterm is [$matchterm]\n" if $COND;
			last;
		}

		# if we only need one more matching word...
		#
		if ($midx+1 == $widx) {	
			# ... check for plural last word ( and/or tag)
			#
			if (skipword($tlist->[$i+$midx+$skip+1])) {
				$skip++;
				$squeue++;
			}
			my $nextword = $tlist->[$i+$midx+$skip+1];
			print " *** xref: nextword is '$nextword'\n" if $COND;
			my $istagged = istagged($nextword);
			my $isplural = isplural(bareword($nextword));
			if ($isplural || $istagged) {
				my $clean = $nextword;
				$clean = bareword($nextword) if ($istagged);
				$clean = depluralize($clean) if ($isplural);
				if ($clean eq lc($words[$widx])) {
					print " *** xref: we have a match\n" if $COND;

					$saccum += $squeue;
					$squeue = 0;
					
					$plural = $isplural;
					$matchterm = $title;
					$matchlen = $widx + $saccum + 1;
					print " *** xref: match length is $matchlen\n" if $COND;

					push @mtags,getstarttag($nextword);	
					push @mtags,getendtag($nextword);

					last;
				}
			}
		}
	}

	# try to add match if we found one.
	#
	if ($matchterm ne "") {
		push @$tags,@mtags;		# save all the tags
		insertmatch($matches,$i,$matchterm,$matchlen,$plural,$psv,$tags);
	}
	 
	return ($matchterm eq "")?0:1;		# return success or fail
}


# add to matches list - only if we found a better (larger) match for a position
#
sub insertmatch {
	my ($matches,$pos,$term,$length,$plural,$psv,$tags)=@_;
	
	# CHANGED : handling this at display time now to fix some behavior
	# check for term already being included, since we dont want repeats
	#return if (defined $mterms->{$term});
	
	# check for existing entry 
	#
	if (defined $matches->{$pos}) {
		if ($matches->{$pos}->{'length'} < $length) {
			dwarn "replacing $term at $pos, length $length with $term, length $length\n";
			$matches->{$pos}->{'term'} = $term;
			$matches->{$pos}->{'length'} = $length;
			$matches->{$pos}->{'plural'} = $plural;
			$matches->{$pos}->{'possessive'} = $psv;
			$matches->{$pos}->{'tags'} = $tags;
		
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
			dwarn "*** xref: adding match $term at $pos, length $length\n";
			$matches->{$pos}={
		 		'term'=>$term, 
			 	'length'=>$length, 
				'plural'=>$plural,
				'possessive'=>$psv,
				'tags'=>$tags};
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
	my $fromid = shift;
	my $toid = shift;
	
	
	if ($fromid<0 || $toid<0 ) {
		#dwarn "we were passed a bad linking parameter: fromid=$fromid, toid=$toid";
		return;
	}
	
	#dwarn "*** xref: adding link table entry for $fromid -> $toid" if ($DEBUG);
	if (!linkPresent($fromid , $toid)) {
		my $sth = $dbh->prepare("INSERT into links (fromid, toid) VALUES (?, ?)");
		eval {
			$sth->execute($fromid, $toid);
			$sth-finish();
		};
	}
}

# see if a particular link is present in the db
# 
sub linkPresent {
	my $fromid = shift;
	my $toid = shift;
	
	my $sth = $dbh->prepare("select fromid from links WHERE fromid = ? AND toid = ?");
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
	my $id = shift;
	
	my $sth = $dbh->prepare("delete from links where toid = ?");
	eval {
		$sth->execute($id);
		$sth->finish();
	};
}

# delete all links *from* given object
#
sub deleteLinksFrom {
	my $id = shift;
	
	return if ($id<0);	 # sanity

	my $sth = $dbh->prepare("delete from links WHERE fromid = ?");
	eval {
		$sth->execute($id);	
		$sth->finish();
	};
	
}

sub getlinkedto {
	my $objid = shift;
	my $sth = $dbh->prepare("select fromid from links where toid = ?");
	$sth->execute($objid);
	my @links = ();
	while (my $row = $sth->fetchrow_hashref() ){
		push @links, $row->{'fromid'};
	}
	
	return @links;
}


# main entry point to graph categorization inference
#
sub getBestByBFS {
	my $rootid = shift;		# root id to enter the object graph
	my $homonyms = shift;	# list of homonym ids 
	my $depth = shift;		# how deep to go into the graph. we have to be careful
				# because entries have an average of 10 links, which 
				# means that by the second level we are analyzing 100
				# nodes!

	my $level = 1;		# initialize level
	my @queue = ();		# bfs queue
	my %seen;			# hash of ids we've seen (don't revisit nodes)

	# get classifications of the homonyms we are comparing against
	#
	my $hclass = [];
	foreach my $hid (@$homonyms) {
		push @$hclass, [getclass($hid)];	
	}
	
	push @queue,$rootid;

	$seen{$rootid} = 1;
	my $ncount = expandBFSQueue(\@queue,\%seen);	# init list w/first level

	# each stage of this while loop represents a deeper "layer" of the graph
	my $w = -1;		# winner
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

	return $w;	 # return winner index (or -1)	
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
			return -1;			 # if we have a single tie, we fail
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
		push @carray,$fetchc if (@{$fetchc}[0]);
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
	
	my $count = scalar @{$queue};	 # we're going to remove current elements
#	print "count on queue $count\n";

	my @neighbors = xrefGetNeighborListByList($queue,$seen);
	push @$queue,@neighbors;
	splice @$queue,0,$count;			# delete front elements

	return scalar @neighbors;			# return count of novel nodes
}

# pluralize the below, throwing out things in 'seen' list
#
sub xrefGetNeighborListByList {
	my $sources = shift;
	my $seen = shift;
 
	my @outlist = ();	 # initialize output list
	
	foreach my $sid (@$sources) {
		my @list = xrefGetNeighborList($sid);
		foreach my $nid (@list) {
			if (! defined $seen->{$nid}) {	# add only novel items
				push @outlist,$nid;
				$seen->{$nid} = 1;	 
			}
		}
	}

	return @outlist;
}

# get a list of "neighbors" in the crossreference graph, from a particular
# node (i.e. nodes the source node can "see" or has outgoing links to)
#
sub xrefGetNeighborList {
	my $source = shift;
	
	my @list = ();

	my $sth = $dbh->prepare("select toid from links where fromid = ?");
	$sth->execute($source);
	
	while ( my $row = $sth->fetchrow_hashref() ){
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


1;
