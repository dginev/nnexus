package NNexus;
use strict;

# 
# modified by Aaron Krowne on 2002-02-21: de-objectified; plugged into PM.
#  again on 2005-02-24: load stopwords from external file
#
#  ----------------------------------------------------------------------
# | Trivial Information Retrieval System                                 |
# | Hussein Suleman                                                      |
# | May 2001                                                             |
#  ----------------------------------------------------------------------
# |  Virginia Polytechnic Institute and State University                 |
# |  Department of Computer Science                                      |
# |  Digital Libraries Research Laboratory                               |
#  ----------------------------------------------------------------------
#

use vars qw{%stopwords};

# load stopwords from external file
#
BEGIN {

	my $swfile = "/var/www/nnexus/stopwords.txt"; 
	open INFILE, $swfile or die "couldn't open stopwords file '$swfile'!";

	my @swarray = <INFILE>;
	chomp(@swarray);

	close INFILE;
	
	%stopwords = map { $_ => 1 } @swarray;
}

# run the stopper on a list, returning a new (possibly smaller) list
# (added by APK)
#
sub stopList {
  
  my @inlist = @_;
 
  my @outlist = ();

  foreach my $word (@inlist) {
    push @outlist, $word if (stop($word));
  }

  return @outlist;
}

# stop an individual word
#
sub stop {

   my $aword = shift; 

   if (exists $stopwords{$aword}) { 
     return ''; 
   } else { 
     return $aword; 
   }
}
   
sub testStopper
{
   my @words = qw (in hmmmm out and finalize i a wordlist and the);

   foreach my $word (@words)
   {
      print stop ($word)." ";
   }
   print "\n";
}

1;

