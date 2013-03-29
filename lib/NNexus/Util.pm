# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Various Utilities                                                   | #
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

package NNexus::Util;
use strict;
use warnings;
use Carp;
# [16/12/2012] DG: Most of this code is horribly deprecated (e.g. the Unicode support) and should be updated...

# This code is verbatim from the Noosphere project except package names.
#use Unicode::String qw(latin1 utf8 utf16);
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(url_canonical protectURL protectAnchor octify inset htmlescape qhtmlescape nb
		    objectExistsById sq sqa sqq lookupfield readFile writeField uniquify);

# Canonicalize absolute URLs, borrowed from LaTeXML::Util::Pathname
our $PROTOCOL_RE = '(?:https?)(?=:)';
sub url_canonical {
  my ($pathname) = @_;
  my $urlprefix= undef;
  if($pathname =~ s|^($PROTOCOL_RE//[^/]*)/?|/|){
    $urlprefix = $1; }

  if($pathname =~ m|//+/|){
    Carp::cluck "Recursive pathname? : $pathname\n"; }
##  $pathname =~ s|//+|/|g;
  $pathname =~ s|/\./|/|g;
  # Collapse any foo/.. patterns, but not ../..
  while($pathname =~ s|/(?!\.\./)[^/]+/\.\.(/\|$)|$1|){}
  $pathname =~ s|^\./||;
  (defined $urlprefix ? $urlprefix . $pathname : $pathname); }

# translate ampersands for URLs in PlanetMath entry bodies
sub protectURL {  s/&(?!amp;)/&amp;/og; $_; }

# same as above but for anchor text; replace tildes with \~{}
#
sub protectAnchor {
  s/~/\\~{}/og;
  s/_/\\_/og;
  s/&(?!amp;)/&amp;/og;
  $_;
}

# turn a string of binary data to octal
#
sub octify {
  my $string = shift;
  return join('',(map {sprintf('\%03O',ord($_))} (split(//,$string))));
}

# # convert latin1 strings to utf8 strings
# sub latin1ToUTF8 { latin1($_)->utf8; }

# # convert utf8 strings to latin1 strings
# sub UTF8ToLatin1 { utf8($_)->latin1; }

# return 1 if a given item is in a list (set) (really should use hashes instead)
sub inset {
  my ($search_target,@list) = @_;
  return 0 unless (defined $search_target) && length($search_target)>0;
  foreach my $item (@list) {
    return 1 if (($item||'') eq $search_target);
  }
  return 0;
}

# prepare text to be displayed within html (basically escape lt,gt)
#	also useful for XML.
sub htmlescape {
  s/&/&amp;/g;
  s/</\&lt\;/g;
  s/>/\&gt\;/g;
  $_;
}
sub qhtmlescape {
  my $text = htmlescape(shift);
  $text =~ s/"/\&quot;/g;
  return $text;
}

# nb - (not blank) , make sure a variable is both defined and contains
#					something other than whitespace
sub nb {  (defined $_) && ($_=~/^\s+$/);  }

# Check if an object exists in the DB, by its identifier and domain id
sub objectExistsById {
  my ($dbh,$uid,$domid) = @_;
  my $sth = $dbh->prepare("SELECT objectid from object where identifier = ? AND domainid = ?"); 
  my $count=$sth->rows();
  $sth->finish();
  return ($count==0)?0:1;
}

# sq - sql quote (replaces ' with '', \ with \\)
sub sq {
  my $word = shift;
  return 'null' if (! defined($word));
  $word =~ s/'/''/g;
  $word =~ s/\\/\\\\/g;
  return $word;
}

# sq - sql quote on a list of words
sub sqa { map {sq($_)} @_; }

# go one step further and actually put in the '' around the text
sub sqq { "'".sq($_)."'"; }

# look up a single field
sub lookupfield {
  my ($dbh,$table,$field,$where) = @_;

  my ($rv,$sth) = dbSelect($dbh,{WHAT=>$field,FROM=>$table,WHERE=>$where,LIMIT=>1});

  $sth->execute();
  my $row = $sth->fetchrow_hashref();
  $sth->finish();

  return $row->{$field};
}

# read in a file to a string
sub readFile {
  #BB: when pipe is opened, it is always successful
  #    so, we need to check whether program really exists
  if ($_[0] =~ /(\S+).*\|/) {
    unless (-e $1) {
      warn "Program $1 cannot be found.";
    }
  }

  unless (open(FILE,'<',$_[0])) {
    warn "file $_[0] does not exist"; 
    return '';
  }
  my $data = join('',<FILE>);
  close FILE;
  $data;
}

# write a string out to a file
sub writeFile {
  my ($filename,$data) = @_;
  unless (open(OUTFILE, ">",$filename)) {
    warn "failed to open file $filename for writing!";
    return;
  }
  print OUTFILE $data;
  close OUTFILE;
}

# Reduces a given list to unique elements (i.e. throws out redundant ones)
sub uniquify {
  my %seen = ();
  grep { ! $seen{$_} ++ } @_;
}

1;

__END__
