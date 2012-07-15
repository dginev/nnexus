package NNexus;

###########################################################################
#	text morphology 
###########################################################################

#
# this code is verbatim from Aaron Krowne's Noosphere project except for changing
# the package name.
#

use strict;

use Encode qw{is_utf8};

use NNexus::Charset;

# take a title in "index" form (Euler, Leonhard) and swap it to "inline" form
# (Leonhard Euler)
#
sub swaptitle {
	my $title = shift;

	$title =~ s/,,/;/g;	# "escape" double commas 

	# escape math portions
	#
	($title, my $math) = escapeMathSimple($title);

	# do swapping
	#
	if ($title =~ /,/) {
		my @array = split(/\s*,\s*/,$title);
		$title = $array[1].' '.$array[0];
	}

	$title =~ s/;/,/g;	# unescape commas

	# unescape math portions
	#
	$title = unescapeMathSimple($title, $math);

	return $title;
}

# pluralize a word
#
sub pluralize {
	my $word=shift;
	
	# "root of unity" pluralizes as "roots of unity" for example
	#
	if ($word=~/(\w+)(\s+of\s+.+)/) {
		return pluralize($1).$2;
	}

	# normal pluralization
	#
	if ($word=~/(.+ri)x$/) {
		return "$1ces";
	}
	if ($word=~/(.+t)ex$/) {
		return "$1ices";
	}
	if ($word=~/(.+[aeiuo])x$/) {
		return "$1xes";
	}
	if ($word=~/(.+[^aeiou])y$/) {
		return "$1ies";
	}
	if ($word=~/(.+)ee$/) {
		return "$1ees";
	}
	if ($word=~/(.+)us$/) {
		return "$1i";
	}
	if ($word=~/(.+)ch$/) {
		return "$1ches";
	}
	if ($word=~/(.+)ss$/) {
		return "$1sses";
	}
	return $word.'s';
}	

# see if a title contains math ($.+$)
#
sub ismathy {
	my $title = shift;

	return 1 if ($title =~ /\$.+\$/);
	
	return 0;
}

# get a title without math (two levels... one removes $$s, one removes all)
#
sub getnonmathy {
	my $title = shift;
	my $level = shift || 1;

	if ($level == 1) {
		$title =~ s/\$\\?(.+?)\$/$1/g;
	} else {
		$title =~ s/\$.+?\$//g;
		$title =~ s/\s+$//;
		$title =~ s/^\s+//;
	}

	return $title;
}

# return true if a word is possessive (ends in 's)
#
sub ispossessive {
	my $word = shift;

	if ($word =~ /\s/) {
		my @wlist = split(' ',$word);
		return 1 if ($wlist[0]=~/'s$/ || $wlist[0]=~/s'$/); 
		return 0;
	}
	else { 
		return 1 if ($word=~/'s$/ || $word=~/s'$/); 
		return 0;
	}
}

# return phrase without possessive suffix ("Euler's" becomes "Euler")
#
sub getnonpossessive {
	my $phrase = shift;

	my @words = split(' ',$phrase);
	$words[0] =~ s/'s$//;
	$words[0] =~ s/s'$/s/;

	return join(' ',@words);
}

# return first word with possessive suffix ("Euler" becomes "Euler's")
#
sub getpossessive {
	my $word = shift;

	my @words = split(' ',$word);
	if (not ispossessive($words[0])) {
		if ($words[0] =~ /s$/) {
			$words[0] .= "'";
		} else {
			$words[0] .= "'s";
		}
	}

	return join(' ',@words);
}

# boolean for tagged or not
#
sub istagged {
	my $word = shift;
	my $word2 = bareword($word);

	return (lc($word) ne $word2);
}

# boolean for plural or not
# 
sub isplural {
	my $word = shift;
	my $word2 = depluralize($word);

	return ($word ne $word2);
}

# singularize a word... remove root and replace
#
sub depluralize {
	my $word = shift;
	my $debug = shift;
	
	# "spaces of functions" depluralizes as "space of functions" for example.
	#
	if ($word=~/(^\w[\w\s]+\w)(\s+of\s+.+)$/) {
		my $l = $1;
		my $r = $2;
		return depluralize($l).$r;
	}

	if ($word=~/(.+ri)ces$/) {
		return "$1x";
	}
	if ($word=~/(.+t)ices$/) {
		return "$1ex";
	}
	if ($word=~/(.+[aeiuo]x)es$/) {
		return "$1";
	}
	if ($word=~/(.+)ies$/) {
		return "$1y";
	}
	if ($word=~/(.+)ees$/) {
		return "$1ee";
	}
	if ($word=~/(.+)ches$/) {
		return "$1ch";
	}
	if ($word=~/(.+o)ci$/) {
		return "$1cus";
	}
	if ($word=~/(.+)sses$/) {
		return "$1ss";
	}
	if ($word=~/(.+ie)s$/) {
		return "$1";
	}
	if ($word=~/(.+[^eiuos])s$/) {
		return "$1";
	}
	if ($word=~/(.+[^aeio])es$/) {
		return "$1e";
	}
	return $word;
}

# get the non-plural root for a word
#
sub getroot {
	my $word=shift;
	
	if ($word=~/(.+ri)ces$/) {
		return "$1";
	}
	if ($word=~/(.+[aeiuo]x)es$/) {
		return "$1";
	}
	if ($word=~/(.+)ies$/) {
		return "$1";
	}
	if ($word=~/(.+)ches$/) {
		return "$1ch";
	}
	if ($word=~/(.+o)ci$/) {
		return "$1c";
	}
	if ($word=~/(.+)sses$/) {
		return "$1ss";
	}
	if ($word=~/(.+[^eiuos])s$/) {
		return "$1";
	}
	if ($word=~/(.+[^aeio])es$/) {
		return "$1e";
	}
	return $word;
}

# bogostem - really elementary "stemming" algorithm
#
sub bogostem {
	my $word = shift;

	$word = getnonpossessive($word);
	$word = getroot($word);
	$word =~ s/'//g;

	return $word;
}

# get tags/modifiers in front of a word
#
sub getstarttag {
	my $word = shift;

	return igetstarttag($word) if $word=~/\\/;
	
	$word =~ /([^$TWC]*?(\\\w+\{)?)[$TWC]+('s|s')?[^$TWC]*/;
	return $1;
}

# get tags/modifiers in front of a word (international ver)
#
sub igetstarttag {
	my $word = TeXtoLatin1(shift);

	$word =~ /([^$TWC]*?(\\\w+\{)?)[$TWC]+('s|s')?[^$TWC]*/;
	return $1;
}

# get tags/modifiers after a word
#
sub getendtag {
	my $word = shift;

	return igetendtag($word) if $word =~ /\\/;
	
	$word =~ /[^$TWC]*?(\\\w+\{)?[$TWC]+('s|s')?([^$TWC]*)/;
	return $3;
}

# get tags/modifiers after a word (international ver)
#
sub igetendtag {
	my $word = TeXtoLatin1(shift);

	$word =~ /[^$TWC]*?(\\\w+\{)?[$TWC]+('s|s')?([^$TWC]*)/;
	return $3;
}

# return word with no LaTeX, brackets, punctuation, or quotes.
# .. ie	"\command{word}" becomes "word"
#				"(word)" becomes word , etc
#
sub bareword {
	my $word = shift;

	return ibareword($word) if $word=~/\\/;
	
	$word =~ /[^$TWC]*?(\\\w+\{)?([$TWC]+('s|s')?)[^$TWC]*/;
	return lc($2);
}

# international trigraph-aware bareword
#
sub ibareword {
	my $word = TeXtoLatin1(shift);
	
	$word =~ /[^$TWC]*?(\\\w+\{)?([$TWC]+('s|s')?)[^$TWC]*/;
	return lc(latin1ToTeX($2));
}

1;
