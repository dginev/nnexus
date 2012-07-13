package NNexus;

###############################################################################
#
# This package has data and functions for converting between character sets
# (and encodings, including TeX).
# 
# Author: Aaron Krowne 
###############################################################################

#
# this code is verbatim from Aaron Krowne's Noosphere project except for changing
# the package name.
#

use strict;
use Encode;

use vars qw{%ICHAR_TO_TEX %TEX_TO_ICHAR %TEX_TO_UTF8 %UTF8_TO_TEX %UTF8_TEXSP $TWC $ICHARS};

# table for converting ISO-8859-1 chars into TeX trigraphs.
#
%ICHAR_TO_TEX=(
 'ÿ'=>'\"y',
 'ý'=>"\\'y",
 'ü'=>'\"u',
 'û'=>'\^u',
 'ú'=>"\\'u",
 'ù'=>'\`u',
 'ø'=>'\o',
 'ö'=>'\"o',
 'õ'=>'\~o',
 'ô'=>'\^o',
 'ó'=>"\\'o",
 'ò'=>'\`o',
 'ñ'=>'\~n',
 'ð'=>'o',		# ???
 'ï'=>'\"i',
 'î'=>'\^i',
 'í'=>"\\'i",
 'ì'=>'\`i',
 'ë'=>'\"e',
 'ê'=>'\^e',
 'é'=>"\\'e",
 'è'=>'\`e',
 'ç'=>'\c{c}',
 'æ'=>'\ae',
 'å'=>'\aa',
 'ä'=>'\"a',
 'ã'=>'\~a',
 'â'=>'\^a',
 'á'=>"\\'a",
 'à'=>"\\`a",
 'ß'=>'\ss',
 'Ý'=>"\\'Y",
 'Ü'=>'\"U',
 'Û'=>'\^U',
 'Ú'=>"\\'U",
 'Ù'=>'\`U',
 'Ø'=>'\O',
 'Ö'=>'\"O',
 'Õ'=>'\~O',
 'Ô'=>'\^O',
 'Ó'=>"\\'O",
 'Ò'=>'\`O',
 'Ñ'=>'\~N',
 'Ð'=>'D',		# ???
 'Ï'=>'\"I',
 'Î'=>'\^I',
 'Í'=>"\\'I",
 'Ì'=>'\`I',
 'Ë'=>'\"E',
 'Ê'=>'\^E',
 'É'=>"\\'E",
 'È'=>'\`E',
 'Ç'=>'C',
 'Æ'=>'\AE',
 'Å'=>'\AA',
 'Ä'=>'\"A',
 'Ã'=>'\~A',
 'Â'=>'\^A',
 'Á'=>"\\'A",
 'À'=>'\`A'
);

# simple list of ISO-8859-1 international chars
#
$ICHARS = "ÿýüûúùøöõôóòñðïîíìëêéèçæåäãâáàßÝÜÛÚÙØÖÕÔÓÒÑÐÏÎÍÌËÊÉÈÇÆÅÄÃÂÁÀ";

# TeX word chars.  this can be used wherever character classes can be used.
#
$TWC = $ICHARS.'\w\-\*';

# table for converting TeX trigraphs into iso 8859-1 chars
#
%TEX_TO_ICHAR = (
'\"y'=> 'ÿ',
"\\'y"=> 'ý',
'\"u'=> 'ü',
'\^u'=> 'û',
"\\'u"=> 'ú',
'\`u'=> 'ù',
'\o'=> 'ø',
'\oe'=> 'ö',
'\\"o'=> 'ö',
'\~o'=> 'õ',
'\^o'=> 'ô',
"\\'o"=> 'ó',
'\`o'=> 'ò',
'\~n'=> 'ñ',
 'o'=>'ð',		# ???
'\"i'=> 'ï',
'\^i'=> 'î',
"\\'i"=> 'í',
'\`i'=> 'ì',
'\"e'=> 'ë',
'\^e'=> 'ê',
"\\'e"=> 'é',
'\`e'=> 'è',
'\c{c}'=> 'ç',
'\ae'=> 'æ',
'\aa'=> 'å',
'\"a'=> 'ä',
'\~a'=> 'ã',
'\^a'=> 'â',
"\\'a"=> 'á',
"\\`a"=> 'à',
'\ss'=> 'ß',
"\\'Y"=> 'Ý',
'\"U'=> 'Ü',
'\^U'=> 'Û',
"\\'U"=> 'Ú',
'\`U'=> 'Ù',
'\O'=> 'Ø',
'\OE'=> 'Ö',
'\"O'=> 'Ö',
'\~O'=> 'Õ',
'\^O'=> 'Ô',
"\\'O"=> 'Ó',
'\`O'=> 'Ò',
'\~N'=> 'Ñ',
 'D'=>'Ð',		# ???
'\"I'=> 'Ï',
'\^I'=> 'Î',
"\\'I"=> 'Í',
'\`I'=> 'Ì',
'\"E'=> 'Ë',
'\^E'=> 'Ê',
"\\'E"=> 'É',
'\`E'=> 'È',
'C'=> 'Ç',
'\AE'=> 'Æ',
'\AA'=> 'Å',
'\"A'=> 'Ä',
'\~A'=> 'Ã',
'\^A'=> 'Â',
"\\'A"=> 'Á',
'\`A'=> 'À',

# hungarian.  this is all approximation for now, unfortunately (the mappings
# are really not to hungarian characters)
#
'\H{o}'=> 'ö',
'\H{u}'=> 'ü',
'\H{u}'=> 'ü',
'\H{y}'=> 'ÿ',
'\H{i}'=> 'ï',
'\H{e}'=> 'ë',
'\H{a}'=> 'ä',
'\H{U}'=> 'Ü',
'\H{O}'=> 'Ö',
'\H{I}'=> 'Ï',
'\H{E}'=> 'Ë',
'\H{A}'=> 'Ä',

# other junk
#
'\v{C}'=>'C',
'\v{c}'=>'c',

);

%TEX_TO_UTF8 = (
  '\"y'  => pack('U',0xFF),
  '\th'  => pack('U',0xFE),
  "\\'y" => pack('U',0xFD),
  '\"u'  => pack('U',0xFC),
  '\^u'  => pack('U',0xFB),
  "\\'u" => pack('U',0xFA),
  '\`u'  => pack('U',0xF9),
  '\o'   => pack('U',0xF8),
  '\oe'  => pack('U',0x153),
  '\\"o' => pack('U',0xF6),
  '\~o'  => pack('U',0xF5),
  '\^o'  => pack('U',0xF4),
  "\\'o" => pack('U',0xF3),
  '\`o'  => pack('U',0xF2),
  '\~n'  => pack('U',0xF1),
  '\dh'  => pack('U',0xF0),
  '\"\i' => pack('U',0xEF),
  '\^\i' => pack('U',0xEE),
  "\\'\\i"=> pack('U',0xED),
  '\`\i' => pack('U',0xEC),
  '\^\j' => pack('U',0x135),
  '\"e'  => pack('U',0xEB),
  '\^e'  => pack('U',0xEA),
  "\\'e" => pack('U',0xE9),
  '\`e'  => pack('U',0xE8),
  '\c{c}'=> pack('U',0xE7),
  '\ae'  => pack('U',0xE6),
  '\aa'  => pack('U',0xE5),
  '\"a'  => pack('U',0xE4),
  '\~a'  => pack('U',0xE3),
  '\^a'  => pack('U',0xE2),
  "\\'a" => pack('U',0xE1),
  '\`a'  => pack('U',0xE0),
  '\ss'  => pack('U',0xDF),
  '\TH'  => pack('U',0xDE),
  "\\'Y" => pack('U',0xDD),
  '\"U'  => pack('U',0xDC),
  '\^U'  => pack('U',0xDB),
  "\\'U" => pack('U',0xDA),
  '\`U'  => pack('U',0xD9),
  '\O'   => pack('U',0xD8),
  '\OE'  => pack('U',0xD7),
  '\"O'  => pack('U',0xD6),
  '\~O'  => pack('U',0xD5),
  '\^O'  => pack('U',0xD4),
  "\\'O" => pack('U',0xD3),
  '\`O'  => pack('U',0xD2),
  '\~N'  => pack('U',0xD1),
  '\DH'  => pack('U',0xD0), 
  '\"I'  => pack('U',0xCF),
  '\^I'  => pack('U',0xCE),
  "\\'I" => pack('U',0xCD),
  '\`I'  => pack('U',0xCC),
  '\^J'  => pack('U',0x134),
  '\"E'  => pack('U',0xCB),
  '\^E'  => pack('U',0xCA),
  "\\'E" => pack('U',0xC9),
  '\`E'  => pack('U',0xC8),
  '\c{C}'=> pack('U',0xC7),
  '\AE'  => pack('U',0xC6),
  '\AA'  => pack('U',0xC5),
  '\"A'  => pack('U',0xC4),
  '\~A'  => pack('U',0xC3),
  '\^A'  => pack('U',0xC2),
  "\\'A" => pack('U',0xC1),
  '\`A'  => pack('U',0xC0),
# hungarian
  '\H{o}'=> pack('U',0x151),
  '\H{u}'=> pack('U',0x171),
  '\H{O}'=> pack('U',0x150),
  '\H{U}'=> pack('U',0x170),
# misc (anyone what language uses these?)
  '\v{c}'=> pack('U',0x10D),
  '\v{C}'=> pack('U',0x10C),
  '\v{s}'=> pack('U',0x161),
  '\v{S}'=> pack('U',0x160),
  '\v{z}'=> pack('U',0x17E),
  '\v{Z}'=> pack('U',0x17D),
  "\\'z" => pack('U',0x17A),
  "\\'Z" => pack('U',0x179),
  "\\'n" => pack('U',0x144),
  '\^c'  => pack('U',0x109),
  '\^C'  => pack('U',0x108),
  "\\'c" => pack('U',0x107),
  "\\'C" => pack('U',0x106),
  "\\'l" => pack('U',0x13A),
  "\\'L" => pack('U',0x139),
  '\c{t}'=> pack('U',0x163),
  '\c{T}'=> pack('U',0x162),
  "\\'g" => pack('U',0x1F5),
  '\^h'  => pack('U',0x125),
  '\^H'  => pack('U',0x124),
# capital russian letter
  '\CYRA'=> pack('U',0x410),
  '\CYRB'=> pack('U',0x411),
  '\CYRV'=> pack('U',0x412),
  '\CYRG'=> pack('U',0x413),
  '\CYRD'=> pack('U',0x414),
  '\CYRE'=> pack('U',0x415),
  '\CYRYO'=> pack('U',0x401), 
  '\CYRZH'=> pack('U',0x416),
  '\CYRZ'=> pack('U',0x417),
  '\CYRI'=> pack('U',0x418),
  '\CYRISHRT'=> pack('U',0x419),
  '\CYRK'=> pack('U',0x41A),
  '\CYRL'=> pack('U',0x41B),
  '\CYRM'=> pack('U',0x41C),
  '\CYRN'=> pack('U',0x41D),
  '\CYRO'=> pack('U',0x41E),
  '\CYRP'=> pack('U',0x41F),
  '\CYRR'=> pack('U',0x420),
  '\CYRS'=> pack('U',0x421),
  '\CYRT'=> pack('U',0x422),
  '\CYRU'=> pack('U',0x423),
  '\CYRF'=> pack('U',0x424),
  '\CYRH'=> pack('U',0x425),
  '\CYRC'=> pack('U',0x426),
  '\CYRCH'=> pack('U',0x427),
  '\CYRSH'=> pack('U',0x428),
  '\CYRSHCH'=> pack('U',0x429),
  '\CYRHRDSN'=> pack('U',0x42A),
  '\CYRERY'=> pack('U',0x42B),
  '\CYRSFTSN'=> pack('U',0x42C),
  '\CYREREV'=> pack('U',0x42D),
  '\CYRYU'=> pack('U',0x42E),
  '\CYRYA'=> pack('U',0x42F),
# lower-case russian letters
  '\cyra'=> pack('U',0x430),
  '\cyrb'=> pack('U',0x431),
  '\cyrv'=> pack('U',0x432),
  '\cyrg'=> pack('U',0x433),
  '\cyrd'=> pack('U',0x434),
  '\cyre'=> pack('U',0x435),
  '\cyryo'=> pack('U',0x451), 
  '\cyrzh'=> pack('U',0x436),
  '\cyrz'=> pack('U',0x437),
  '\cyri'=> pack('U',0x438),
  '\cyrishrt'=> pack('U',0x439),
  '\cyrk'=> pack('U',0x43A),
  '\cyrl'=> pack('U',0x43B),
  '\cyrm'=> pack('U',0x43C),
  '\cyrn'=> pack('U',0x43D),
  '\cyro'=> pack('U',0x43E),
  '\cyrp'=> pack('U',0x43F),
  '\cyrr'=> pack('U',0x440),
  '\cyrs'=> pack('U',0x441),
  '\cyrt'=> pack('U',0x442),
  '\cyru'=> pack('U',0x443),
  '\cyrf'=> pack('U',0x444),
  '\cyrh'=> pack('U',0x445),
  '\cyrc'=> pack('U',0x446),
  '\cyrch'=> pack('U',0x447),
  '\cyrsh'=> pack('U',0x448),
  '\cyrshch'=> pack('U',0x449),
  '\cyrhrdsn'=> pack('U',0x44A),
  '\cyrery'=> pack('U',0x44B),
  '\cyrsftsn'=> pack('U',0x44C),
  '\cyrerev'=> pack('U',0x44D),
  '\cyryu'=> pack('U',0x44E),
  '\cyrya'=> pack('U',0x44F)
);

# initialization
# 
foreach my $key (keys %TEX_TO_UTF8) { 
   # reverse the hash
   my $code = unpack("U",$TEX_TO_UTF8{$key});
   $UTF8_TO_TEX{$code} = $key;
   # create a hash of LaTeX commands
   if ($key =~ /^\\(?:\w+|.\\i|.\\j)\z/) {$UTF8_TEXSP{$code} = ''};
};


sub getAllUTF8Entities {
	my $string = "";
	foreach my $e (keys %TEX_TO_UTF8) {
		$string .= $TEX_TO_UTF8{$e};	
	}
	return $string;
}

# convert TeX trigraphs and character-producing commands to UTF8
#
sub TeXtoUTF8 {
	my $string = shift;

	# command-like symbols matchings ({\o} {\ae} etc)
	# However, this does not process these commands without
	# enclosing brackets, and TeX permits such commands at 
	# the end of words without braces
	while ($string =~ /\{(\\\w+)\}/g) {
    	my $pat = $1;
        if (defined $TEX_TO_UTF8{$pat}) {
			$string =~ s/\{\Q$pat\E\}/$TEX_TO_UTF8{$pat}/;
		}
	}
   
	# this takes care of \o and friends  at the end of a word
	# (?= look ahead is need to handle cases like \nonsense\ae
	while ($string =~ /(\\\w+)(?=(\W|\z))/g) { 
		my $pat = $1; 
		my $c2 = $2; 
		
		# make regexp that will match the letter that follows \o
		# in order to parse things like \o\o\oe 
		my $rex = ($c2 eq '') ? '\z' : (($c2 eq "\\")? "\\\\" : $c2); 
		if (defined $TEX_TO_UTF8{$pat}) { 
			$string =~ s/\Q$pat\E$rex/$TEX_TO_UTF8{$pat}$c2/g; 
		}           
	}

	# trigraph matching
	# \i and \j are letters too
	# TODO: we should check whether there are no letters after \i or \j
	#       however I do not know of any command starting from \i or \j
	#       that has any meaning with TeX trigraphs
	while ($string =~ /\\([\w^'`"~])(\{(\w)\}|(\w|\\i|\\j))/g) {   
	
		my $c1 = $1; 
		my $c2 = $2; 
		my $c3 = $3.$4; 
		
		$c3 = $2 if ($c1 eq 'c' || $c1 eq 'H' || $c1 eq 'v'); 
		
		my $pat = qq|\\$c1$c3|; 
		if (defined $TEX_TO_UTF8{$pat}) { 
			my $rex = qq|\\$c1$c2|; 
			$string =~ s/(\{\Q$rex\E\}|\Q$rex\E)/$TEX_TO_UTF8{$pat}/; 
		} 
	}

	return $string;
}


# convert UTF8 to TeX
# NOTE: UTF8toTeX(TeXtoUTF8) != id
# Example: UTF8toTeX(TeXtoUTF8('\ae\oe B\oe'))='\ae\oe{} B\oe'
#
sub UTF8toTeX {
	my $string = shift;
	Encode::_utf8_on($string); # Assume that string is UTF8
	my @unpck = unpack("U*", $string);
	my $prev = 0;
	my $str = '';

	foreach my $elt (@unpck) { 
		if (defined $UTF8_TO_TEX{$elt}) {
			$str .= $UTF8_TO_TEX{$elt}; 
			$prev = (exists $UTF8_TEXSP{$elt});               
	    } else { 
			$str .= (($prev)?'{}':'').pack("U",$elt);
			$prev = 0; 
		} 
	}
	return $str;
}

# convert iso-8859-1 strings to TeX trigraphs
#
sub latin1ToTeX {
	my $string = shift;

	my @out;
	foreach my $char (split(//,$string)) {
		if (exists $ICHAR_TO_TEX{$char}) {
			push @out, $ICHAR_TO_TEX{$char};
		} else { 
			push @out, $char;
		}
	}
		
	return join('',@out);
}

# convert TeX to UTF-8 (from Latin1)
#
sub TeXtoUTF8_fromLatin1 {
	my $string = shift;
	
	return latin1ToUTF8(TeXtoLatin1($string));
}


# convert TeX trigraphs to iso-8859-1
#	this is really convoluted in order for us to be able to go without
#	listing every combination of braces/no braces in the TEX_TO_ICHAR table.
#
sub TeXtoLatin1 {
	my $string = shift;

	while ($string =~ /\\([\w^'`"~])(\{?(\w)\}?)/g) {
		my $c1 = $1;
		my $c2 = $3;
		my $c3 = $2;

		$c2 = $2 if ($c1 eq 'c');

		my $pat = qq|\\$c1$c2|;
		if (defined $TEX_TO_ICHAR{$pat}) {
			my $rex = qq|\\$c1$c3|;
			$string =~ s/\Q$rex\E/$TEX_TO_ICHAR{$pat}/;
		}
	}

	return $string;
}


1;
