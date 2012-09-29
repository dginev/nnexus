#!/usr/bin/perl
package NNexus::Concepts;
use strict;
use warnings;

use NNexus::Morphology qw(ispossessive isplural getnonpossessive depluralize);
use Encode qw( is_utf8 );

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(getpossiblematches);

# this is a function that is called recursively to insure that all different encodings 
# of a concept are inserted into the concepthash
#
# This funtion updates the concepthash tables 
#
sub addterm {
  my ($db,$objectid,$terms,$encoding) = @_;
  $encoding = '' unless defined $encoding;

  #	print "ENTERING addterm\n";

  # pull out first word of term 
  $terms =~ s/^\s+//;
  $terms =~ /^(\S+)/o;
  my $firstword = $1;
  if ($firstword eq "") {
    #		print "no firstword for $terms\n";
    return;
  }

  # do the actual adding and update

  # we may have a lot of duplicate strings in the concepthash, but we don't care because we want speed on lookup
  my $sth = $db->cachedPrepare("INSERT into concepthash (firstword, concept, objectid ) VALUES (?,?,?)");

  $sth->execute($firstword, $terms, $objectid);
  $sth->finish();

  # add extra nonmathy terms for mathy terms (both levels of translation)
  if (ismathy($terms)) {
    addterm($objectid,getnonmathy($terms,1), $encoding);
  }

  # add extra nonpossessive entry for possessives, linking to same obj
  if (ispossessive($firstword)) {
    addterm($objectid,getnonpossessive($terms), $encoding) 
  }

  # add extra nonplural entry for plurals, linking to same obj
  if (isplural($terms)) {
    addterm($objectid,depluralize($terms), $encoding) 
  }

  # handle aliases for internationalizations

  # figure out encoding (TeX or UTF8) and make aliases
  if (!$encoding) {
    my $ascii = ""; UTF8ToAscii($terms);
    if ( is_utf8( $terms ) ) {
      #			print "Converting $terms into ASCII\n";
      my $terms = encode( "utf8", $terms );
      $ascii = encode( "ascii", decode( "utf8", $terms ) );
      #			print "Before = $terms - After = $ascii\n";
    }
    if ($ascii ne $terms) { 
      addterm($objectid, $ascii, 'utf8');
      my $tex = UTF8toTeX($terms);
      if ( $tex ne $ascii && $tex ne $terms ) {
	addterm($objectid, $tex, 'tex');
      }
    } else { 
      my $utf8 = TeXtoUTF8($terms);
      if ($utf8 ne $terms) {
	addterm($objectid, $utf8, 'tex');
	my $ascii = UTF8ToAscii($utf8);
	if ( $ascii ne $utf8 ) {
	  addterm($objectid, $ascii, 'tex');
	}
      }
    }
  } 
  #	print "LEAVING addterm\n";
}

# Remove the concepts from the db based on internal objid
sub removeconcepts {
  my ($db,$objid) = @_;
  my $delc = $db->cachedPrepare("DELETE from concepthash where objectid = ?");
  $delc->execute($objid);
}

#get a hasharray of concepts (and synonyms) from all objects in the concepthash
sub getallconcepts {
  my ($db) = @_;
  #get the concepts
  my $sth = $db->cachedPrepare("SELECT urltemplate, identifier, title, object.objectid, concept from concepthash, domain, object where object.domainid=domain.domainid and object.objectid = concepthash.objectid");
  $sth->execute();

  my %concepts = ();

  #mark the concept as active
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @{$concepts{$row->{'objectid'}}}, $row->{'concept'};
  }

  return \%concepts;
}


#get a hasharray of concepts (and synonyms) this object defines from the concepthash
sub getconcepts {
  my ($db,$objid) = @_;

  #get the concepts
  my $sth = $db->cachedPrepare("SELECT concept from concepthash where objectid = ?");
  $sth->execute( $objid );

  my @concepts = ();

  #mark the concept as active
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @concepts, $row->{'concept'};
  }

  return \@concepts;
}


#
# get the possible matches based on the first word of a concept
# returns as an array containing a hash with newterm
#
sub getpossiblematches {
  my ($db,$word) = @_;
  my @matches = ();

  my ($start, $finish, $DEBUG);
  $DEBUG = 0;

  if ($DEBUG) {
    $start = time();
  }

  #print "Started with $word\n";
  if (ispossessive($word) ) {
    $word = getnonpossessive($word);
  }
  if ( isplural( $word ) ) {
    $word = depluralize($word);
  }

  my $sth = $db->cachedPrepare("SELECT firstword, concept, objectid from concepthash where firstword=?");
  $sth->execute($word);
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @matches, $row;
  }

  if ($DEBUG) {
    $finish = time();
    my $total = $finish - $start;
    print "getpossiblematches: $total seconds\n";
  }
  return @matches;
}

# Update the concepts for object based on internal objid.
sub addconcepts {
  my $objid = shift;
  my $concepts = shift;

  foreach my $c (@{$concepts}) {
    addterm( $objid, $c );
  }
}

1;
