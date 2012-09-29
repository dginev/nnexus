package Noosphere;
use strict;

use Noosphere::Latex;
use Noosphere::Morphology;
use Noosphere::Stopper;
use Noosphere::DB;

use vars qw{%wordids};

# get the first alphanum character of a title
#
sub getIndexChar {
	my $title = shift;

	# remove math font stuff
	$title =~ s/\\(mathbb|mathrm|mathbf|mathcal|mathfrak)\{//g;

	# grab first wordical character
	$title =~ /^\W*(\w)/;
	my $ichar = $1;

#	dwarn "title $title ichar $ichar";
	
	return uc($ichar);
}

# add a title to the main index
#
sub indexTitle {
	my $table = shift;
	my $objectid = shift;
	my $ownerid = shift;
	my $title = shift;
	my $cname = shift;
	my $source = shift || getConfig('proj_nickname'); # source collection

	my $index = getConfig('index_tbl');

	deleteTitle($table,$objectid);	 # precautionary delete

	my $ichar = getIndexChar(mangleTitle($title));

	my ($rv,$sth) = dbInsert($dbh,{INTO=>$index,COLS=>'objectid,tbl,userid,title,cname,source,ichar',VALUES=>"$objectid,'$table',$ownerid,'".sq($title)."','$cname', '$source', '$ichar'"});
	$sth->finish();
}

# delete a title from the main index.
#
sub deleteTitle {
	my $table = shift;
	my $objectid = shift;

	my $index = getConfig('index_tbl');

	my ($rv,$sth) = dbDelete($dbh,{FROM=>$index,WHERE=>"tbl='$table' and objectid=$objectid"});
	$sth->finish();
}

# top level subroutine to invalidation index an entry.  actually may result in re-indexing
# many entries, due to cascading updates in adaptive index.
#
sub invalIndexEntry {
	my $objectid = shift;
	my $invphrases = shift || {};

	my %entries;
	
	# put the first entry on the queue
	my @queue = ($objectid);

	my $scanned = 0;

	# loop over, scanning an indexing entries, until the queue is empty
	while (scalar @queue > 0) {

		# cache entries on the queue
		invalCacheEntryData(\%entries,@queue);

		my $h = shift @queue;
		my %inventries = map { $_ => 1 } @queue;
		my @reinv = invalScanEntry({uid => $objectid, data => $entries{$objectid}}, $invphrases, {%inventries});

		push @queue, @reinv;

		$scanned++;
	}

	warn "scanned $scanned entries for invalidation of $objectid!";
	my @p = keys %$invphrases;
	warn "invalidation phrases were {".join(', ',@p)."}";

	return $scanned;
}

# update entry cache from database, based on list.
#
sub invalCacheEntryData {
	my $cache = shift;
	my @list = @_;

	my @new;

	# figure out which entries to read in this time
	#
	foreach my $id (@list) {
		if (not exists $cache->{$id}) {
			push @new, $id;
		}
	}

	my $list = join(', ', @new);

	return if (!$list);

	# read in the new entries
	#
	my $sth = $dbh->prepare("select uid, data from objects where uid in ($list)");
	$sth->execute();

	while (my $row = $sth->fetchrow_hashref()) {
		$cache->{$row->{'uid'}} = $row->{'data'};
	}

	$sth->finish();
}

# "scan" an individual entry for invalidation data.  indexes novel words/phrases.
# returns a list of other entries which need to be scanned.
#
sub invalScanEntry { 
	my $row = shift;
	my $invphrases = shift;
	my $inventries = shift;
	
	my $uid = $row->{'uid'};
	my $code = $row->{'data'};

	my $MAXDF = getConfig('inval_maxdf');

	my $text = getPlainText($code);
	my @list = getwordlist($text);
	my $OLDDEBUG = $DEBUG;

	my @reinv = ();

	$DEBUG = 0;
	
	# keep track of phrases which were added, so we dont add more than 
	# once and screw up df (and have lots of junk extra instances)
	#
	my $addhash = {};

	# fill the addhash with IDs previously indexed for this record
	#
	my $sth = $dbh->prepare("select * from inv_idx where objectid = ?");
	$sth->execute($uid);
	while (my $row = $sth->fetchrow_hashref()) {
		my $mul = $row->{'word_or_phrase'} == 1 ? 1 : -1;
		$addhash->{$row->{'id'}*$mul} = 1;
	}
	$sth->finish();

	# ensure an entry for each word into dictionary 
	#
	ensureInvalWords(@list);

	# index words/phrases
	#
	for (my $i = 0; $i <= $#list; $i++) {

		my $j = $i;

		# add phrases starting at the current position until the first
		# phrase where dfs don't max out.
		#
		my $df = getInvalDf(@list[$i..$j]);
		while ($j <= $#list && defined($df) && $df >= $MAXDF) {
			
			addInvalInstance($addhash, $uid, @list[$i..$j]);

			$j++;

			$df = getInvalDf(@list[$i..$j]) if ($j <= $#list);
		}
		addInvalInstance($addhash, $uid, @list[$i..$j]) if ($j <= $#list);

		# if we just hit the max for this phrase, invalidate entries for
		# next prefix back, as they might contain the new, longer phrase.
		#
		# NOTE : I think we can change this back to checking for df being undefined,
		# since we no longer remove entries before re-indexing them.  when entries
		# are truly removed, df can go to zero for some phrases, and this shouldn't
		# trigger a re-index (we also would no longer need invphrases at the global
		# level).
		#
		if ($j > $i && $df == 0) {
			
			my $invphrase = join(' ',@list[$i..($j-1)]);

			if (not exists $invphrases->{$invphrase}) {
				$invphrases->{$invphrase} = 1;

				if (not exists $inventries->{$row->{'objectid'}}) {

					$inventries->{$row->{'objectid'}} = 1;

					my ($wp, $pid) = getInvalWordOrPhraseid(0, @list[$i..($j-1)]);
					my $sth = $dbh->prepare("select objectid from inv_idx where word_or_phrase = ? and id = ?");
					$sth->execute($wp, $pid);
					while (my $row = $sth->fetchrow_hashref()) {
						next if $row->{'objectid'} == $uid;
#						print "due to indexing phrase [".join(' ', @list[$i..$j])."], i'd have to invalidate entry $row->{objectid}\n";
						push @reinv, $row->{'objectid'};
					}
					$sth->finish();
				}
			}
		}
	}

	$DEBUG = $OLDDEBUG;

	return @reinv;
}

# add an instance of a phrase to the invalidation index
#
sub addInvalInstance {
	my $addhash = shift;
	my $objectid = shift;
	my @phrase = @_;

	my ($wp, $pid) = getInvalWordOrPhraseid(1, @phrase);

	# maintain hash of added phrases for dupe checking purposes
	#
	if (defined $addhash) {
		my $addid = $wp ? $pid : -1*$pid;

		# don't re-add dupes
		return if (exists $addhash->{$addid});

		# update hash with current phrase/word
		$addhash->{$addid} = 1;
	}

	# insert phrase into index table
	#
	my $sth = cachedPrepare("insert into inv_idx (id, word_or_phrase, objectid) values (?, ?, ?)");
	my $rv = $sth->execute($pid, $wp, $objectid);
	$sth->finish();

	# update df
	# 
	$sth = cachedPrepare("select count from inv_dfs where word_or_phrase = ? and id = ?");
	$sth->execute($wp, $pid);

	my ($curdf) = $sth->fetchrow_array();
	$sth->finish();

	# add new df entry or increment old one
	if (not defined $curdf) {
		$sth = cachedPrepare("insert into inv_dfs (word_or_phrase, id, count) values (?, ?, 1)");
	} else {
		$sth = cachedPrepare("update inv_dfs set count = count + 1 where word_or_phrase = ? and id = ?");
	}
	$sth->execute($wp, $pid);
#	$sth->finish();
}

# drop object from invalidation index
#
sub dropFromInvalIndex {
	my $id = shift;
	
	my $indexed_phrases = $dbh->selectall_arrayref("select distinct id, word_or_phrase from inv_idx where objectid = $id");
	foreach my $phrase (@$indexed_phrases) {
		my $sth = $dbh->prepare("update inv_dfs set count = count - 1 where word_or_phrase = ? and id = ?");
		$sth->execute($phrase->[1], $phrase->[0]);
		$sth->finish();
	}

	# now do the deletion of instances in index
	#
	my $sth = $dbh->prepare("delete from inv_idx where objectid = ?");
	$sth->execute($id);

	$sth->finish();
}

# make sure words in the given list are in the dictionary
#
sub ensureInvalWords {
	my @list = @_;

	%wordids = (); # clear global wordid cache

	$dbh->{PrintError} = 0;	# no, we dont need to see uniqueness errors.

	my @qlist = map "('$_')", sqa(@list);
=quote
	my $q = "replace into inv_words (word) values ".join(', ', @qlist);
	my $sth = $dbh->prepare($q);
	$sth->execute();

	$sth->finish();
=cut

	my $sth = cachedPrepare("insert into inv_words (word) values (?)");

	foreach my $word (@list) {
	
		# insert into word list (will not do anything if word is there)
		#
		my $rv = $sth->execute($word);
	}
	
#	$sth->finish();

	# build wordID hash
	#
	$sth = $dbh->prepare("select id, word from inv_words where word in (".join(', ', @qlist).")");
	$sth->execute();
	while (my $row = $sth->fetchrow_hashref()) {
		$wordids{$row->{'word'}} = $row->{'id'};
	}
	
	$sth->finish();
	
	$dbh->{PrintError} = 1;
}

# get the "document frequency" of an invalidation phrase
# 
sub getInvalDf {
	my @phrase = @_;

	my ($wp, $pid) = getInvalWordOrPhraseid(0, @phrase);

	my $df;

	if (defined $pid) {

		my $sth = cachedPrepare("select count from inv_dfs where word_or_phrase = ? and id = ?");
		$sth->execute($wp, $pid);

		($df) = $sth->fetchrow_array();

#		$sth->finish();
	}

	return $df || 0;	# squash undef to 0
}

sub getInvalWordOrPhraseid {
	my $add = shift;
	my @phrase = @_;

	my $pid;
	my $wp = 0; # default is word
	if (scalar @phrase == 1) {
		$pid = getInvalWordid($phrase[0]);
	} else {
		$pid = getInvalPhraseid(join(' ', @phrase), $add);
		$wp = 1; # phrase bit
	}
	
	return ($wp, $pid);
}


# look up unique word ID from words table
# 
sub getInvalWordid {
	my $word = shift;

	# try to use cache built by ensureInvalWordids
	#
	if (exists $wordids{$word}) {
		return $wordids{$word};
	}

	# otherwise look the word up
	#
	my $sth = cachedPrepare("select id from inv_words where word = ?");
	my $rv = $sth->execute($word);

	my ($id) = $sth->fetchrow_array();

#	$sth->finish();

	return $id;
}

# get a phrase ID from phrase table
#
sub getInvalPhraseid {
	my $phrase = shift;
	my $add = shift;

	my $sth = cachedPrepare("select id from inv_phrases where phrase = ?");
	my $rv = $sth->execute($phrase);

	my ($id) = $sth->fetchrow_array();

#	$sth->finish();

	# insert phrase anew
	# 
	if ((not defined $id) && $add) {
		$sth = cachedPrepare("insert into inv_phrases (phrase) values (?)");
		$sth->execute($phrase);

		# TODO : database driver abstractify this
		$id = $dbh->{'mysql_insertid'};

#		$sth->finish();
	}
	
	return $id;
}
		
# strip out any latex and junk from text
#
sub getPlainText {
	my $text = shift;
	
	# remove math tags
	#
	$text =~ s/\\\[.+?\\\]//sg;
	$text =~ s/\$\$.+?\$\$//gs;
	$text =~ s/\$.+?\$//gs;
	$text =~ s/\\begin\{eqnarray[*]{0,1}\}.+?\\end\{eqnarray[*]{0,1}\}//gs;
	$text =~ s/\\begin\{displaymath\}.+?\\end\{displaymath\}//gs;

	# remove emph, underline, leaving whats in the tags
	# 
	$text =~ s/\\underline\{(.+?)\}/$1/gs;
	$text =~ s/\\emph\{(.+?)\}/$1/gs;

	# remove all other non-environment tags
	#
	$text =~ s/\\\w+\{.+?\}\[.+?\]//gs;
	$text =~ s/\\\w+(\{.+?\})+//gs;

	# remove environment tags (leaving whats in the environment)
	#
	$text =~ s/\{\\\w+\s(.+?)\}/$1/gs;

	# kill non-brace-parameter tags like \item or \item[]
	#
	$text =~ s/\\\w+\[.+?\]//gs;
	$text =~ s/\\\w+//gs;
	
	# kill all backslashes 
	#
	# APK - we want to be able to process trigraphs
#	$text =~ s/\\//gs;

	return $text;
}

# turn text into a word list
# 
sub getwordlist {
	my $text = shift;
	
	# kill almost everything but word characters
	#
	$text =~ s/[\\\:\=\?\.\|,_\{\}\-\[\]";\(\)\*`\&\^\%\$\#\@\!~]/ /gs;

	# split into list
	#
	my @list = stopList(split('\s+',lc($text)));

	# remove certain entries from the list
	#
	my $i = 0;
	while ($i <= $#list) {
		my $remove = 0;
	
		# do elementary stemming of word
		#
		$list[$i] = bogostem($list[$i]);

		# numerical-starting entries 
		#
		$remove = 1 if ($list[$i]=~/^[0-9]/);

		# one letter entries 
		#
		$remove = 1 if (length($list[$i])<2);
	
		# do the removal
		#
		if ($remove == 1){
			splice @list,$i,1;
		} else {
			$i++;	# and go to next item.
		}
	}

	return @list;
}

# split a list of titles that can possibly be in "index" format. The list is
# comma separated, so ,, indicates a comma that is part of a title.
#
sub splitindexterms {
	my $terms = shift;

	($terms,my $math) = escapeMathSimple($terms);

	$terms =~ s/,,/;/g;	# we cheat by changing ,, to ; before splitting
	my @list = split(/\s*,\s*/,$terms);
	for my $i (0..$#list) {	# then replacing ; with , afterwards
		$list[$i] =~ s/;/,/;
		$list[$i] = unescapeMathSimple($list[$i], $math);
	}
	return @list;
}

1;
