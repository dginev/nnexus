package NNexus;
use strict;

# This code is verbatim from the Noosphere project except package names.

use Unicode::String qw(latin1 utf8 utf16);

use vars qw{%ICHAR_TO_ASCII %ICHAR_TO_HTML $DEBUG $dbh};

# table to convert ISO-8859-1 chars into ASCII.
#
%ICHAR_TO_ASCII=(
 'ÿ'=>'y',
 'ý'=>'y',
 'ü'=>'u',
 'û'=>'u',
 'ú'=>'u',
 'ù'=>'u',
 'ø'=>'o',
 'ö'=>'o',
 'õ'=>'o',
 'ô'=>'o',
 'ó'=>'o',
 'ò'=>'o',
 'ñ'=>'n',
 'ð'=>'o',
 'ï'=>'i',
 'î'=>'i',
 'í'=>'i',
 'ì'=>'i',
 'ë'=>'e',
 'ê'=>'e',
 'é'=>'e',
 'è'=>'e',
 'ç'=>'c',
 'æ'=>'ae',
 'å'=>'a',
 'ä'=>'ae',
 'ã'=>'a',
 'â'=>'a',
 'á'=>'a',
 'à'=>'a',
 'ß'=>'ss',
 'Ý'=>'Y',
 'Ü'=>'U',
 'Û'=>'U',
 'Ú'=>'U',
 'Ù'=>'U',
 'Ø'=>'O',
 'Ö'=>'Oe',
 'Õ'=>'O',
 'Ô'=>'O',
 'Ó'=>'O',
 'Ò'=>'O',
 'Ñ'=>'N',
 'Ð'=>'D',
 'Ï'=>'I',
 'Î'=>'I',
 'Í'=>'I',
 'Ì'=>'I',
 'Ë'=>'E',
 'Ê'=>'E',
 'É'=>'E',
 'È'=>'E',
 'Ç'=>'C',
 'Æ'=>'Ae',
 'Å'=>'A',
 'Ä'=>'Ae',
 'Ã'=>'A',
 'Â'=>'A',
 'Á'=>'A',
 'À'=>'A'
);

# table to convert ISO-8859-1 chars into HTML entities.
#
%ICHAR_TO_HTML=(
 'ÿ'=>'&yuml;',
 'ý'=>'&yacute;',
 'ü'=>'&uuml;',
 'û'=>'&ucirc;',
 'ú'=>'&uacute;',
 'ù'=>'&ugrave;',
 'ø'=>'&oslash;',
 'ö'=>'&ouml;',
 'õ'=>'&otilde;',
 'ô'=>'&ocirc;',
 'ó'=>'&oacute;',
 'ò'=>'&ograve;',
 'ñ'=>'&ntilde;',
 'ð'=>'&eth;',
 'ï'=>'&iuml;',
 'î'=>'&icirc;',
 'í'=>'&iacute;',
 'ì'=>'&igrave;',
 'ë'=>'&euml;',
 'ê'=>'&ecirc;',
 'é'=>'&eacute;',
 'è'=>'&egrave;',
 'ç'=>'&ccedil;',
 'æ'=>'&aelig;',
 'å'=>'&aring;',
 'ä'=>'&auml;',
 'ã'=>'&atilde;',
 'â'=>'&acirc;',
 'á'=>'&aacute;',
 'à'=>'&agrave;',
 'ß'=>'&szlig;',
 'Ý'=>'&Yacute;',
 'Ü'=>'&Uuml;',
 'Û'=>'&Ucirc;',
 'Ú'=>'&Uacute;',
 'Ù'=>'&Ugrave;',
 'Ø'=>'&Oslash;',
 'Ö'=>'&Ouml;',
 'Õ'=>'&Otilde;',
 'Ô'=>'&Ocirc;',
 'Ó'=>'&Oacute;',
 'Ò'=>'&Ograve;',
 'Ñ'=>'&Ntilde;',
 'Ð'=>'&ETH;',
 'Ï'=>'&Iuml;',
 'Î'=>'&Icirc;',
 'Í'=>'&Iacute;',
 'Ì'=>'&Igrave;',
 'Ë'=>'&Euml;',
 'Ê'=>'&Ecirc;',
 'É'=>'&Eacute;',
 'È'=>'&Egrave;',
 'Ç'=>'&Ccedil;',
 'Æ'=>'&AElig;',
 'Å'=>'&Aring;',
 'Ä'=>'&Auml;',
 'Ã'=>'&Atilde;',
 'Â'=>'&Acirc;',
 'Á'=>'&Aacute;',
 'À'=>'&Agrave;'
);

use constant DAYS=>
 ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
use constant MONTHS=>
 ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

# BB: utility function
# encloses param in tag if param is nonempty, and returns '' if param is empty
sub produceHtmlParam {
	my $tag = shift;
	my $param = shift;
	if ($param) {
		$tag =~ /^<(\w+)/;
		return "$tag$param</$1>";
	} else {
		return '';
	}
}


# translate ampersands for URLs in PlanetMath entry bodies
#
sub protectURL {
	my $url = shift;

	$url =~ s/&(?!amp;)/&amp;/og;

	return $url;
}

# same as above but for anchor text; replace tildes with \~{}
#
sub protectAnchor {
	my $anchor = shift;

	$anchor =~ s/~/\\~{}/og;
	$anchor =~ s/_/\\_/og;
	$anchor =~ s/&(?!amp;)/&amp;/og;

	return $anchor;
}

# utility function: copy the contents of the right hash in to the left hash
#
sub merge_hashes_left {
	my $left = shift;
	my $right = shift;

	foreach my $key (keys %$right) {
		$left->{$key} = $right->{$key};
	}
}

# strip HTML tags from text entirely.
# 
sub striphtml {
	my $text = shift;

	$text =~ s/<.+?>//g;

	return $text;
}

# check for non-user-allowed HTML tags in user-supplied text.  if one is found,
# the text is replaced with an error message.
# 
sub htmlcheck {
	my $html = shift;

	my $allowed = getConfig('allowed_html_tags');
	
	my @errors = ();
	
	# find HTML tags (we dont care about closing tags, by the way)
	#
	while ($html =~ /<\s*(\w+)(?:\s+([^>]*?))?\s*>/gs) {
		my $tag = lc($1);
		my $attrs = lc($2);
		
		if (exists $allowed->{$tag}) {
			# check attributes
			my @attrlist = split(/\s+/,$attrs);

			foreach my $a (@attrlist) {

				my ($aname) = split(/\s*=\s*/, $a);
				if (!$allowed->{$tag}->{$aname}) {
					push @errors, "Attribute '$aname' not allowed for tag '$tag'.";
				} 
			}
		} else {
			push @errors, "Tag '$tag' not allowed.";
		}
	}

	# return informative error message if there were errors
	#
	if (@errors) {
		my $etext = join ("\n",(map "<li>$_</li>", @errors));

		$html = "ERROR: Text not displayed for the following reasons:<br/>
		<ul>
			$etext
		</ul>
		";
	}

	# translate raw ampersands
	#
	$html =~ s/&(?!amp;)/&amp;/sog;
	
	return $html;
}

# duplicate a hash, except for a list of keys
#
sub hashExcept {
	my $hash = shift;
	my @fields = @_;

	my %hash2 = %$hash;

	foreach my $field (@fields) {
		delete $hash2{$field};
	}

	return {%hash2};
}

# format a date in cookie-style
#
sub makeDate {
	my $date = shift;
	my $local = shift || 0;

	my @months = MONTHS;
	my @days = DAYS;

	my ($s,$m,$h,$dd,$mm,$yy,$wday,$x,$y) = $local ? localtime($date) : gmtime($date);

	$yy += 1900;
	$yy = sprintf("%04d",$yy);
	$dd = sprintf("%02d",$dd);
	my $mon = $months[$mm];
	my $day = $days[$wday];
	$h = sprintf("%02d",$h);
	$m = sprintf("%02d",$m);
	$s = sprintf("%02d",$s);

	return("$day, $dd-$mon-$yy $h:$m:$s GMT"); 
}

# turn a string of binary data to octal
#
sub octify {
	my $string = shift;
	
	return join('',(map {sprintf('\%03O',ord($_))} (split(//,$string))));
}

# chdirFileBox - change the current directory to the file box for an object.
# returns the original directory, or '' for failed.
#
sub chdirFileBox {
	my $table = shift;
	my $id = shift;

	my $fileroot = getConfig('file_root'); 
	my $cwd = `pwd`; 
	chomp $cwd; 
	
	my $dir = "$fileroot/$table/$id";
	if (-e $dir) { 
		chdir $dir; 
	} else { 
	return ''; 
	}

	return $cwd;
}

# debug warn. takes a string and an optional debug level at which the string
#	should be displayed.
#
sub dwarn {
	my $warning = shift;
	my $level = shift || 1;

	warn $warning if ($level <= $DEBUG);

	return;
}

# clean up a SQL timestamp
#
sub nicifyTimestamp {
	my $ts = shift;

	my $year = (localtime)[5] + 1900;
	
	if ($ts =~ /(\d{4})-(\d\d)-(\d\d)\s+(\d\d:\d\d):\d\d(.\d{6})?.\d\d/) {
		my $yr = $1;
		my $mon = sprintf("%i",$2);
		my $day = sprintf("%i",$3);
		return "$mon/$day at $4" if ($yr eq $year);
		return "$yr-$mon-$day at $4";
	}
	elsif ($ts =~ /(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
		my $yr = $1;
		my $mon = sprintf("%i",$2);
		my $day = sprintf("%i",$3);
		return "$mon/$day at $4" if ($yr eq $year);
		return "$yr-$mon-$day at $4";
	}
	
	return $ts;
}

# convert latin1 strings to utf8 strings
#
sub latin1ToUTF8 {
	my $string = shift;

	return latin1($string)->utf8;
}

# convert utf8 strings to latin1 strings
#
sub UTF8ToLatin1 {
	my $string = shift;

	return utf8($string)->latin1;
}

# convert HTML entities to ISO-8859-1.	This is useful for 
# entry inputting. we don't want titles to actually contain
# HTML entities, since those won't link to TeX.
#
sub htmlToLatin1 {
	my $string = shift;
 
	my %table = reverse %ICHAR_TO_HTML;
	
	while ($string =~ /(&\w+;)/g) {
		my $entity = $1;

		if (exists $table{$entity}) {
		$string =~ s/\Q$entity\E/$table{$entity}/;
	}
	}
 
	return $string;
}

# convert ISO-8859-1 strings to HTML entity representations
#
sub latin1ToHtml {
	my $string = shift;

	my @out;
	foreach my $char (split(//,$string)) {
		if (exists $ICHAR_TO_HTML{$char}) {
		push @out, $ICHAR_TO_HTML{$char};
	} else {
		push @out, $char;
	}
	}
 
	return join('',@out);
}

# convert UTF-8 strings to ascii
#
sub UTF8ToAscii {
	my $string = shift;
	
	return latin1ToAscii(UTF8ToLatin1($string));
}

# add un-internationalized aliases to a UTF8 word list. 
#
sub unI18nAlias {
	my @words = @_;

	my @outlist = ();

	foreach my $word (@words) {

		my $un = UTF8ToAscii($word);

		push @outlist, $word;

		push @outlist, $un if ($un ne $word);
	}

	return @outlist;
}

# convert ISO-8859-1 strings to ascii representations
#
sub latin1ToAscii {
	my $string = shift;

	my @out;
	
	foreach my $char (split(//,$string)) {
		if (exists $ICHAR_TO_ASCII{$char}) {
			push @out, $ICHAR_TO_ASCII{$char};
		} else {
			push @out, $char;
		}
	}
 
	return join('',@out);
}


# turn whitespace into non-breaking space
#
sub nbspace {
	my $string=shift;

	$string=~s/ /&nbsp;/gs;
	
	return $string;
}

# return true if the given type (integer or string)
#
sub isAttachmentType {
	my $type=shift;

	if ($type =~/^[0-9]+$/) {
		return 1 if ($type == PROOF());
		return 1 if ($type == RESULT());
		return 1 if ($type == EXAMPLE());
		return 1 if ($type == DERIVATION());
		return 1 if ($type == COROLLARY());
		return 1 if ($type == APPLICATION());
	} else {
		return 1 if ($type eq 'Proof');
		return 1 if ($type eq 'Example');
		return 1 if ($type eq 'Result');
		return 1 if ($type eq 'Corollary');
		return 1 if ($type eq 'Derivation');
		return 1 if ($type eq 'Application');
	}

	return 0;
}

# get a title or a subject for an object
sub lookuptitle {
	my $table = shift;
	my $id = shift;

	my $title = lookupfield($table,'title',"uid=$id");
	if (!$title) {	 # maybe the field is named "subject"
		$title = lookupfield($table,'subject',"uid=$id");
	}

	return $title;
}

# get the next value for a sequence
sub nextval {
	my $sequence = shift;
	
	if (getConfig('dbms') eq 'pg') {
		my ($rv,$sth) = dbLowLevelSelect($dbh,"select nextval('$sequence')");
		my $row = $sth->fetchrow_hashref();
		$sth->finish();
	
		return $row->{'nextval'};
	}

	# 'simulate' sequences in mysql (using tables)
	#
	if (getConfig('dbms') eq 'mysql') {
		
		# insert dummy row
		my $sth = $dbh->prepare("insert into $sequence values()");
		$sth->execute();

		# get id of primary key
		my $iid = $sth->{'mysql_insertid'};
		$sth->finish();

		# clean up so table doesn't grow without bound
		$dbh->do("delete from $sequence where val < $iid");

		return $iid;
	}
}

# convert a number to the corresponding ascii string 
#
sub chardecode {
	my $num=shift;

	return chr hex $num;
}

# descape an escaped string
#
sub urlunescape {
	my $string=shift;

	$string=~s/\+/ /g;

	$string=~s/\%([0-9A-F][0-9A-F])/chardecode($1)/gse;

	return $string;
}

# return a "safe" encoding of a char
#
sub charencode {
	my $char=shift;

	return $char if ($char=~/^[\w\-]$/);
	#return '+' if ($char eq ' ');

	return '%'.sprintf('%2X',ord($char));
}

# escape a string for inclusion in a URL (as in CGI parameter)
#
sub urlescape {
	my $string=shift;

	return join ('',map charencode($_),split(//,$string));
}

# generate a file list for the current directory.
# recognizes an 00index.txt containing a list of file names.
#
sub getfilelist {
	my $table = shift;
	my $id = shift;
	my $html = '';
	
	my $fileurl = getConfig('file_url');
	my %index;
	my $count = 0;

	# process index, if present 
	#
	if ( -e '00index.txt' ) {
		open INDEX,"00index.txt";
		my $line = '';
		while ($line = <INDEX>) {
			next if ($line =~ /^#/ || $line =~ /^\s*$/ );
			$line =~ /^([^\s]+)\s+(.*)$/;
			$index{$1} = $2;
		}
		close INDEX;
	}

	$html .= "<table>";
	my @files = <*>;
	foreach my $file (@files) {
		next if ( $file eq "00index.txt" );
	next if ( $file =~ /^coverimage/ );
	$html .= "<tr>";
	$html .= "<td valign=\"top\" align=\"left\"><a href=\"$fileurl/$table/$id/$file\">$file</a></td>";
	my $description = ' ';
	if (defined($index{$file})) {
		$description = $index{$file};
	}
	$html .= "<td>&nbsp;&nbsp;</td>";
	$html .= "<td valign=\"top\" align=\"left\">$description</td>";
	$html .= "</tr>";
	$count++;
	}
	$html.="</table>";

	return '' if (!$count);

	return $html;
}

# generate a file list for an object's file box. outputting XML.
# recognizes an 00index.txt containing a list of file names.
#
sub getFileListXML {
	my $table = shift;
	my $id = shift;
	
	my $xml = '';
	
	my $fileurl = getConfig('file_url');
	my %index;
	my $count = 0;

	my $cwd = chdirFileBox($table, $id) or return '';

	# process index, if present 
	#
	if ( -e '00index.txt' ) {
		open INDEX,"00index.txt";
		my $line = '';
		while ($line = <INDEX>) {
			next if ($line =~ /^#/ || $line =~ /^\s*$/ );
			$line =~ /^([^\s]+)\s+(.*)$/;
			$index{$1} = $2;
		}
		close INDEX;
	}

	$xml .= "<files>";
	my @files = <*>;
	foreach my $file (@files) {
		next if ( $file eq '00index.txt' );
	next if ( $file =~ /^coverimage/ );

	$xml .= "<file name=\"$file\" url=\"$fileurl/$table/$id/$file\">";

	my $description = ' ';
	if (defined($index{$file})) {
		$description = $index{$file};
	}

	$xml .= "$description</file>\n";

	$count++;
	}
	$xml .= "</files>";

	chdir $cwd;

	return '' if (!$count);

	return $xml;
}

# get the canonical viewing operation for a table
#
sub getop {
	my $table=shift;

	return ('getmsg','') if ($table eq getConfig('msg_tbl'));

	return ('getobj',$table);
} 

# turn hyperlinks in text into real hyperlinks
#
sub activateLinks {
	my $text = shift;

	my $lcc = '[\w~\-\?+\%\&=;\/#]';  # link "character class"
	$text =~ s/((http|ftp):\/\/(\.$lcc|$lcc)+)/<a href="$1">$1<\/a>/ig;

	return $text;
}

# stdmsg - print a message in standard layout
#
sub stdmsg {
	my $message = shift;
	
	$message = tohtmlascii($message);

	$message = activateLinks($message);

	return "<font class=\"source\">$message</font>";
}

# tohtmlascii - convert a message to printable "ascii" form 
#
sub tohtmlascii {
	my $msg = htmlescape(shift);	# nix html tags

	$msg =~ s/ +\n/\n/gm;		# kill extra end-of-line spaces
	$msg =~ s/ {2,}/\&nbsp;/g;	# turn spaces to &nbsp;
	$msg =~ s/^ /\&nbsp;/gm;	# turn spaces to &nbsp;
	$msg =~ s/\n/<br \/>/g;		# \n to <br>

	return $msg;
}

# return 1 if a given item is in a list (set) (really should use hashes instead)
#
sub inset {
	my $find = shift;
	my @list = @_;

	foreach my $item (@list) {
		return 1 if ($item eq $find);
	}

	return 0;
}

# prepare text to be displayed within html (basically escape lt,gt)
#	also useful for XML.
#
sub htmlescape {
	my $text = shift;

	$text =~ s/&/&amp;/g;
	$text =~ s/</\&lt\;/g;
	$text =~ s/>/\&gt\;/g;

	#return latin1ToUTF8($text);
	return $text;
}

sub qhtmlescape {
	my $text = htmlescape(shift);

	$text =~ s/"/\&quot;/g;
	return $text;
}

# quotefields - turn a list of strings into a comma-separated, escaped and 
#							 quoted list as a single string for INSERT statements
sub quotefields {
	return join(',',map("'".sq($_)."'",@_));
}

# basefilename - get filename from a full path string 
#
sub basefilename {
	my $path = shift;
	
	return $1 if ($path =~ /\\([^\\]+)$/);
	return $1 if ($path =~ m|/([^/]+)$|);

	return $path;
}

# blank - opposite of below
# 
sub blank {
	return (not nb(shift));
}

# nb - (not blank) , make sure a variable is both defined and contains 
#								 something other than whitespace
sub nb {
	my $st=shift;
	return (defined $st and not ($st=~/^\s*$/));
}

# normalize a string to the form ThisIsATitleString
#
sub normalize {
	my $name = UTF8ToAscii(shift);
	
	$name =~ s/-/ /g;
	$name =~ s/[^\w ]//g;
	$name =~ s/\s+/ /g;
	$name =~ s/^\s*the\s+//gi;
	my @words = split(' ',$name);
	$name = '';
	
	foreach my $word (@words) { $name .= ucfirst($word); }
	
	return $name;
}

# take a title string and return a database-unique name. we do this via 
# brute force; if "Complex" is taken, we use "Complex2.	if "Complex2" is
# taken, we use "Complex3".	Genius, no?
#
sub uniquename {
	my $title = shift;
	my $avoid = shift;	 # a name to avoid that isn't in the db yet

	my $root = "";
	my $name = "";

	$root = normalize($title);	# get name root
	$name = $root;							# start off with the root
	my $count = 2;
	while (objectExistsByName($name) || ($avoid && ($name eq $avoid))) {
		$name = "$root$count";	 # try next name
		$count++;
	}

	return $name;
}

# return 1 if the name given is a registered user, 0 otherwise
#
sub user_registered {
	my $value = shift;
	my $name = shift;
	
	(my $rv,my $sth) = dbSelect($dbh,{WHAT=>'uid',FROM=>getConfig('user_tbl'),WHERE=>"lower($name)=lower('$value')",LIMIT=>1});

	my $rows = $sth->rows();
	$sth->finish();

	return $rows;
}

# get object name by id 
sub getnamebyid {
	my $id = shift;
	my $table = shift || getConfig('en_tbl');

	my $index = getConfig('index_tbl');

	my ($rv,$sth) = dbSelect($dbh,{WHAT=>'cname',FROM=>$index,
	 WHERE=>"tbl='$table' and objectid=$id"});

	my $row = $sth->fetchrow_hashref();

	return $row->{cname};
}

# getuidbyusername 
#
sub getuidbyusername {
	my $name = shift;

	my ($rv,$sth) = dbSelect($dbh,{WHAT=>'uid',FROM=>'users',WHERE=>"username='$name'"});

	my $row = $sth->fetchrow_hashref();

	return $row->{uid};
}


# getownerid - get the user id of the owner of an object 
#
sub getownerid {
	my $id = shift;
	
	my ($rv,$sth) = dbSelect($dbh,{WHAT=>'userid',FROM=>'objects', WHERE=>"uid=$id"});
 
	my $row = $sth->fetchrow_hashref();
	return $row->{userid};
}

# get object id by name of encyclopedia object (and version)
#
sub getidbyname {
	my $name = shift;
	my $table = shift||getConfig('en_tbl');

	my $index = getConfig('index_tbl');

	(my $rv,my $sth) = dbSelect($dbh,{WHAT=>'objectid',FROM=>$index,WHERE=>"tbl='$table' and cname='$name'",LIMIT=>1});

	my $row = $sth->fetchrow_hashref();
	$sth->finish();
	
	return $row->{objectid} if (defined $row->{objectid});
	return -1;
}

# remove a temporary cache directory
#
sub removeTempCacheDir {
	my $cachedir=shift;
	my $root=getConfig('cache_root');

	return if ((not defined($cachedir)) or $cachedir eq "");

	system('rm','-rf',"$root/$cachedir");
}

# get a temporary cache directory name
#
sub makeTempCacheDir {
	my $root=getConfig('cache_root');
	my $path="$root/temp";
	my $i=0;

	# find the first free numbered cache dir
	#
	while ( -e "$path/$i" ) {
		$i++;
	}

	mkdir "$path/$i"; 		# making the dir grabs it
	return "temp/$i";
}

# getTempFileName - get the name of an unused system temp file
# 
sub getTempFileName {
	my $range = 65536;
	my $prefix = "/tmp/noosphere.temp.";
	my $suffix = "";
	
	# get a name that doesn't exist
	#
	$suffix = rand $range;
	while (-e "$prefix$suffix" ) {
		$suffix = rand $range;
	}

	return "$prefix$suffix";
}

# get object owner id by object id
# 
sub objectOwnerByUid { 
	my $uid = shift;
	my $table = shift;

	my ($rv,$sth) = dbSelect($dbh,{WHAT=>'userid',FROM=>$table,WHERE=>"uid=$uid",LIMIT=>1});

	$sth->execute();
	my $row = $sth->fetchrow_hashref();
	$sth->finish();

	return $row->{'userid'};
}

# return whether an object exists based on either a uid or name
#
sub objectExistsByAny {
	my $identifier = shift;

	return objectExistsByUid($identifier) if ($identifier=~/^[0-9]+$/);

	return objectExistsByName($identifier);
}

# check if any object in any table exists, by uid
#
sub objectExistsById {
	my $uid = shift;
	my $domid = shift;
	
	my $sth = $dbh->prepare("SELECT objectid from object where identifier = ? AND domainid = ?"); 
	my $count=$sth->rows();
	$sth->finish();

	return ($count==0)?0:1;
}

# check for an objects existance by name
#
sub objectExistsByName {
	my $name = shift;
	my $table = shift||getConfig('en_tbl');
	
	my $rows;

	my $index = getConfig('index_tbl');
	
	my ($rv,$sth) = dbSelect($dbh,{
		WHAT=>'objectid',FROM=>$index,
		WHERE=>"tbl='$table' and cname='$name'",LIMIT=>"1"});
	
	$rows = $sth->rows();
	my $row = $sth->fetchrow_hashref();
	$sth->finish();
 
	return $row->{'objectid'} if ($rows);
	return 0;
}

sub objectTitleByName {
	my $name=shift;
	my $table=shift||getConfig('en_tbl');

	my $index=getConfig('index_tbl');

	my ($rv,$sth)=dbSelect($dbh,{WHAT=>'title',FROM=>$index,
															 WHERE=>"tbl='$table' and cname='$name'"});
								 
	my $row=$sth->fetchrow_hashref();
	return $row->{title};
}

sub loginExpired {
	my $template=new Template('error.html');
	
	$template->setKey('error', 'Login Expired');

	return makeBox('Error',$template->expand());
}

# turn a hash into some hidden formvars for inclusion in a form
#
sub hashToFormVars { 
	my $hash = shift;		 # the hash
	my $except = shift;	 # list to exclude
	my $form = '';

	my %ehash;					# build an exclude hash for convenience
	
	foreach my $exclude (@$except) {
		$ehash{$exclude} = 1;
	}
	
	foreach my $k (keys %$hash) {
		if (not exists $ehash{$k}) {
			$form .= "<input type=\"hidden\" name=\"$k\" value=\"$hash->{$k}\"/>\n";
		}
	}

	return $form;
}

# case-insensitive string comparison, remove garbage
#
sub cleanCmp {
	my ($a, $b) = @_;
 
	$a =~ s/\W//g;
	$b =~ s/\W//g;

	return lc($a) cmp lc($b);
}

# Compare two strings in a manner that yields an ordering more suitable
# for selectboxes
#
sub humanReadableCmp {
	my ($a, $b) = @_;

	$a =~ s/["',.]//go;
	$b =~ s/["',.]//go;
	$a =~ s/\s+/ /go;
	$b =~ s/\s+/ /go;
	if($a =~ /^[^A-Z]/io) {
		return $a cmp $b if $b =~ /^[^A-Z]/io;
	return -1;
	}
	return 1 if $b =~ /^[^A-Z]/io;
	return lc($a) cmp lc($b);
}

# a form of select box that doesn't take a hash, assumes that key = val
# also, keeps things in array order.
#
sub getSelectBoxFromArray {
	my $name = shift;
	my $optarray = shift;
	my $selected = shift;
	my $attrs = shift;
	
	my $selectbox = '';

	$attrs = defined $attrs ? ' ' . $attrs : '';
	
	$selectbox = "<select name=\"$name\"$attrs>";
	foreach my $val (@$optarray) {
	
	my $enc = urlescape($val);	# encoded value
	my $show = htmlescape($val);
	
		if (defined $selected and $selected eq $val) {
			$selectbox .= "<option value=\"$enc\" selected=\"selected\">$show</option>";
	} else {
			$selectbox .= "<option value=\"$enc\">$show</option>";
	}
	}
	$selectbox .= "</select>";

	return $selectbox;
}

# make a HTML select box
#
sub getSelectBox {
	my $name = shift;
	my $opthash = shift;
	my $selected = shift;
	my $attrs = shift;
	
	my $sel = '';

	$attrs = defined $attrs ? ' ' . $attrs : '';
	
	$sel = "<select name=\"$name\"$attrs>";
	foreach my $val (sort { humanReadableCmp $a, $b } keys %$opthash) {
	
	#my $enc = urlescape($val);	# encoded value
	my $enc = $val;
	my $show = htmlescape($opthash->{$val});
	
		if ((defined $selected) && ($selected eq $val)) {
			$sel .= "<option value=\"$enc\" selected=\"selected\">$show</option>";
	} else {
			$sel .= "<option value=\"$enc\">$show</option>";
	}
	}
	$sel.="</select>";

	return $sel;
}

# make a HTML select box with entries sorted by value
#
sub getSelectBoxSortByValue {
	my $name = shift;
	my $opthash = shift;
	my $selected = shift;
	my $attrs = shift;
	
	my $sel = '';

	if(defined $attrs) {
		$attrs = " " . $attrs;
	} else {
	$attrs = "";
	}
	$sel="<select name=\"$name\"$attrs>";
	foreach my $val (sort { humanReadableCmp $opthash->{$a}, $opthash->{$b} } keys %$opthash) {
	
	my $enc = urlescape($val);
	my $show = htmlescape($opthash->{$val});

		if (defined $selected and $selected eq $val) {
			$sel.="<option value=\"$enc\" selected=\"selected\">$show</option>";
	} else {
			$sel.="<option value=\"$enc\">$show</option>";
	}
	}
	$sel.="</select>";

	return $sel;
}

# get a HTML editing widget for a schema item
#
sub getFormWidget {
	my $schema = shift;	 # schema the keys abide by
	my $key = shift;			# which key are we looking at
	my $values = shift;	 # key -> value pairs
	my $input = "";
	
	if (defined $schema->{$key}) {
		my $sarray = $schema->{$key};
		my $val = qhtmlescape($values->{$key});
	if ($sarray->[1] eq 'check') {
		if ($values->{$key} eq 'on' || $values->{$key} == 1) {
			$input = "<input type=\"checkbox\" name=\"$key\" checked=\"checked\" />";
		}
		else {
			$input = "<input type=\"checkbox\" name=\"$key\" />";
		}
	} 
	elsif ($sarray->[1] eq 'int' or $sarray->[1] eq 'text') {
		$input = "<input type=\"text\" name=\"$key\" value=\"$val\" size=\"$sarray->[3]\" />";
	}
	elsif ($sarray->[1] eq 'tbox') {
		$input = "<textarea name=\"$key\" rows=\"$sarray->[3]\" cols=\"$sarray->[4]\">$val</textarea>";
	}
	elsif ($sarray->[1] eq 'select') {
			$input = getSelectBox($key,$sarray->[3],$val);
	}
	return ($input,$sarray->[0]);	# return widget and description
	} else {
		return ('','');								# no match
	}
}

# get a HTML selector for the preferences key with the given name
#
sub getPrefsWidget {
	my $userinf = shift;
	my $key = shift;
	
	my $prefs = $userinf->{prefs};
	my $prefinf = getConfig('prefs_schema');
	
	return getFormWidget($prefinf,$key,$userinf->{prefs});
}

# get a prefs hash given a user id
#
sub getUserPrefs {
 my $uid = shift;
 
 if ($uid eq 0) {
	$uid = -1; }
	
 my ($rv,$dbq) = dbSelect($dbh,{
	WHAT=>'prefs',
	FROM=>'users',
	WHERE=>"uid=$uid"});
	
 my $row = $dbq->fetchrow_hashref();
 $dbq->finish();
 return(parsePrefs($row->{prefs})); }

# turn a prefs hash into a string
#
sub hashtoprefs {
	my $hash = shift;
	
	my @array = ();
	
	foreach my $key (keys %$hash) {
		push @array,"$key=$hash->{$key}";
	}
	
	my $prefs = join(';',@array);
	
	#dwarn "formed prefs string $prefs";
	return $prefs;
}

# set a user's prefs line in the database
#
sub setUserPrefs {
 my $uid = shift;
 my $prefs = hashtoprefs(shift);
 
 if ($uid <= 0) { dwarn "bad uid" ; return; }
 
 my ($rv,$sth) = dbUpdate($dbh,{
	WHAT=>'users',
	SET=>"prefs='$prefs'",
	WHERE=>"uid=$uid"
 });
 
 $sth->finish();
}

# ymd - get a YEAR - MONTH - DAY string from a timestamp 
#			 a timestamp looks like YYYY-MM-DD HH:MM:SS+TZ, we simply grab
#			 the part before the space
#
sub ymd {
	my $ts = shift;
	
	my $ymd = "";

	if ($ts =~ /(\d{4}-\d{2}-\d{2})/) {
		$ymd = $1;	
	}
	elsif ($ts =~ /^(\d{4})(\d{2})(\d{2})/) {
		$ymd = "$1-$2-$3";
	}
	
	return $ymd;
}

# md - get a MONTH/DAY string from a timestamp
#
sub md {
	my $ts = shift;

	my @months = MONTHS;
	
	my $thisyear = (localtime)[5] + 1900;
	
	my ($year, $mon, $day, $hour, $min);

	if ($ts =~ /(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})/ ||
		$ts =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/) {
	
		$year = $1;
		$mon = $2;
		$day = $3;
		$hour = $4;
		$min = $5;
	}

	return $months[int($mon)-1].' '.int($day) if ($thisyear == $year);

	return "$year-$mon-$day";
}

# mdhm - get a MONTH/DAY HOUR:MINUTE string from a timestamp
#
sub mdhm {
	my $ts = shift;
	
	my @months = MONTHS;

	my $thisyear = (localtime)[5] + 1900;
	
	my ($year, $mon, $day, $hour, $min);

	if ($ts =~ /(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})/ ||
		$ts =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/) {

		$year = $1;
		$mon = $2;
		$day = $3;
		$hour = $4;
		$min = $5;

	}


	return $months[int($mon)-1].' '.int($day)." $hour:$min" if ($thisyear == $year);

	return "$year-$mon-$day $hour:$min";
}

# sq - sql quote (replaces ' with '', \ with \\)
#
sub sq {
	my $word = shift;

	if (not defined($word)) {
		return 'null';
	}

	$word =~ s/'/''/g;
	$word =~ s/\\/\\\\/g;
	
	return $word;
}

# sq - sql quote (replaces ' with '', \ with \\)
#
sub sqa {
	my @words = @_;

	my @outlist;

	foreach my $word (@words) {

		if (not defined($word)) {
			return 'null';
		}

		$word =~ s/'/''/g;
		$word =~ s/\\/\\\\/g;
	
		push @outlist, $word;
	}

	return @outlist;
}

# go one step further and actually put in the '' around the text
sub sqq {
	my $text = shift;

	return "'".sq($text)."'";
}

# delete rows
#
sub delrows {
	my $table = shift;
	my $where = shift;

	my ($rv,$sth) = dbDelete($dbh,{FROM=>$table,WHERE=>$where});
	my $rows = $sth->rows();
	$sth->finish();
	
	return $rows;
}

# a wrapper for update
#
sub setfields {
	my $table = shift;
	my $set = shift;
	my $where = shift;

	my ($rv,$sth) = dbUpdate($dbh,{WHAT=>$table,SET=>$set,WHERE=>$where});
	$sth->finish();
}

# look up a single field
#
sub lookupfield {
	my $table = shift;
	my $field = shift;
	my $where = shift;

	my ($rv,$sth) = dbSelect($dbh,{WHAT=>$field,FROM=>$table,WHERE=>$where,LIMIT=>1});

	$sth->execute();
	my $row = $sth->fetchrow_hashref();
	$sth->finish();

	return $row->{$field};
}

# get an ordered array of field values
#
sub lookupfields {
	my $table = shift;
	my $fields = shift;
	my $where = shift;

	my ($rv,$sth) = dbSelect($dbh,{WHAT=>$fields, FROM=>$table, WHERE=>$where, LIMIT=>1});

	$sth->execute();
	my @row = $sth->fetchrow_array();
	$sth->finish();

	return @row;
}

# get the parent id of a synonym
#
sub synonymparentid {
	my $sid = shift;

	my $data = lookupfield(getConfig('en_tbl'),'data',"uid=$sid");
	
	if ($data=~/^id=(.+)$/) {
		return $1; 
	} elsif ($data=~/^name=(.+)$/) {
		return getidbyname($1);	
	}
}

# grab a row
#
sub getrow {
	my $table =shift;
	my $cols = shift;
	my $where = shift;

	my ($rv,$sth) = dbSelect($dbh,{WHAT=>$cols,FROM=>$table,WHERE=>$where,LIMIT=>1});

	$sth->execute();
	my $row = $sth->fetchrow_hashref();
	$sth->finish();

	return $row;
}

# get the row count for any basic query
#
sub getrowcount {
	my $table = shift;
	my $where = shift;

	my ($rv,$sth) = dbSelect($dbh,{WHAT=>'count(*) as cnt',FROM=>$table,WHERE=>$where});
	my $row = $sth->fetchrow_hashref();
	$sth->finish();

	return $row->{'cnt'};
}

# getmsgcount - get # of messages under an object
#
sub getmsgcount { 
	my $table = shift;
	my $id = shift;

	my ($rv, $sth) = dbSelect($dbh,{
		WHAT=>'count(uid) as cnt',
		FROM=>'messages',
		WHERE=>"objectid=$id and tbl='$table'"});
	
	if (! $rv) { return -1; }

	my $row = $sth->fetchrow_hashref();

	$sth->finish();
	
	return $row->{'cnt'};
}

# blanktemplatefields - blank out template fields as listed 
#
sub blanktemplatefields {
	my $template = shift;
	my @fields = @_;

	foreach my $field (@fields) {
		$template =~ s/\$$field//;
	}

	return $template;
}

# settemplatefields - set template fields from a params hash
#
sub settemplatefields {
	my $template = shift;
	my $params = shift;
	
	my @fields = @_;
	
	if (not defined($fields[0])) {
		@fields = keys %$params;
	}
 
	foreach my $field (@fields) {
		$template =~ s/\$$field/$params->{$field}/g;
	}

	return $template;
}

# dowtoa - day of week (numerical) to ascii (string)
#
sub dowtoa {
	my $dow = shift;
	my $long = shift;

	my @sdays = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	my @ldays = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');

	return $ldays[$dow] if ($long eq "long");
	return $sdays[$dow];
}

# get a type selector box, and select a given option. the option can be 
#	 numerical or a type string.
#
sub gettypebox {
	my $thash = shift;		 # this hash should contain name/value
	my $selected = shift||'definition';

	my $tsel = '';

	$tsel = '<select name="type">';
	foreach my $type (keys %$thash) {
		if (defined $selected and 
			($selected eq $type or $selected == $thash->{$type})) {
			$tsel .= "<option value=\"$type\" selected=\"selected\">$type</option>";
	} else {
			$tsel .= "<option value=\"$type\">$type</option>";
	}
	}
	$tsel .= '</select>';

	return $tsel;
}

# sendMail - send an email message with to name, with subject and body
#
sub sendMail {
	my $email = shift;
	my $body = shift;
	my $subject = shift || getConfig('projname');
	
	#dwarn "sending mail: $body";
	dwarn "sending mail: [$body]";

	$ENV{'PATH'} = '/bin:/usr/bin'; # security measure

	open (MAIL,"| ".getConfig('sendmailcmd')." -f".getConfig('system_email')." $email");
	print MAIL "From: ".getConfig('projname')."<".getConfig('reply_email').">\n";
	print MAIL "To: $email\n";
	print MAIL "Subject: $subject\n";
	print MAIL "\n$body";
	close MAIL;
}

# read in a file to a string
#
sub readFile {
	#BB: when pipe is opened, it is always successful
	#    so, we need to check whether program really exists
	if ($_[0] =~ /(\S+).*\|/) {
		unless (-e $1) {
			dwarn "Program $1 cannot be found.";
		}
	}

	unless (open(FILE,"$_[0]")) {
		dwarn "file $_[0] does not exist"; 
		return '';
	}
	my $data = '';
 
	while (<FILE>) { $data .= $_; }
 
	return $data; 
}

# write a string out to a file
#
sub writeFile {
	my $filename = shift;
	my $data = shift;

	unless (open(OUTFILE, ">$filename")) {
		dwarn "failed to open file $filename for writing!";
		return;
	}

	print OUTFILE $data;

	close OUTFILE;
}

sub uniquify {
        my @a = @_;
        my %seen = ();
        my @uniqu = grep { ! $seen{$_} ++ } @a;
        return @uniqu;
}


1;

