# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Encyclopedia Entry ("Object") Manipulation for NNexus               | #
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
package NNexus::EncyclopediaEntry;

use strict;
use warnings;

#use Encode qw{is_utf8};
use Time::HiRes qw ( time alarm sleep );

# use NNexus::Classification;
# use NNexus::Latex;
# use NNexus::Morphology;
# use NNexus::Linkpolicy;
# use NNexus::Concepts;
# use NNexus::Indexing;
# use NNexus::DB;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(getobjectid getobjecthash);


# Add a new object to the db
#
sub addobject {
  my $db = shift;
  my $objid = shift;		#this is the external objectid
  my $title = shift;
  my $body = shift;
  my $domid = shift;
  my $authorid = shift;
  my $linkpolicy = shift;
  my $synonyms = shift;
  my $classes = shift;
  my $batchmode = shift;
  my @invconcepts = ();		# this is passed to invalidateConcepts

  print STDERR "adding object $objid $title\n";

  my $sth = $db->cachedPrepare("INSERT into object (identifier, title, body, domainid, authorid, linkpolicy, valid) values (?, ?, ?, ?, ?, ?, ?)");
  $sth->execute($objid, $title, $body, $domid, $authorid , $linkpolicy, 0  );
  #
  # we need the object id in order to update the concepts and classification
  #
  $objid = $db->dbConnect->{'mysql_insertid'};
  $sth->finish(); 

  # we eliminated concept labels. We now just use the concepthash table directly


  #
  # update the concepts and concept labels
  #
  # notice that the array is passed to updateconcepts multiple times
  # this allows us to use generalized synonyms
  foreach my $s ( @{$synonyms} ) {
    my @concepts = ();
    foreach my $c ( @{$s} ) {
      push @concepts, $c;
      conceptInvalidate($c); #invalidate objects that contain this concept
    }
    addconcepts( $objid, \@concepts );
  }


  #update the classification
  updateclass( $objid, $domid, $classes );

  #we need to update the linking stuff
  # index this entry (for link invalidation)
  #
  if ( ! $batchmode ) {
    invalIndexEntry($objid);
  }
}

#
# Update the information for the object
#
sub updateobject {
  #this is the internal objectid
  my $db = shift;
  my $objid = shift; 
  my $title = shift;
  my $body = shift;
  my $domid = shift;
  my $authorid = shift;
  my $linkpolicy = shift;
  my $synonyms = shift;
  my $classes = shift;
  my $batchmode = shift;

  #we need to change this so that we only update if the values are different and defined.
  my $sth;
  if ( $body ne "" ) {
    $sth = $db->cachedPrepare("UPDATE object SET title = ? , body = ?, domainid = ?, authorid = ?, linkpolicy = ?, valid = ? WHERE objectid = ?");
    $sth->execute( $title, $body, $domid, $authorid, $linkpolicy, 0, $objid); 
    $sth->finish();	
    #
    # update the concepts and concept labels
    #
    # notice that the array is passed to updateconcepts multiple times
    # this allows us to use generalized synonyms
    removeconcepts( $objid );
    foreach my $s ( @{$synonyms} ) {
      my @concepts = ();
      foreach my $c ( @{$s} ) {
	push @concepts, $c;
	conceptInvalidate($c);
      }
      addconcepts( $objid, \@concepts );
    }

    updateclass( $objid , $domid,  $classes );
  } else {
    $sth = $db->cachedPrepare("UPDATE object set linkpolicy = ?, valid = ? WHERE objectid = ?");
    $sth->execute( $linkpolicy, 0, $objid); 
    $sth->finish();	
  }
  #eval
  #{
  # for now we always invalidate the object, maybe we should change this to 
  #only do this if there really is a change due to the update
  #};



  #we need to update the linking stuff
  # index this entry (for link invalidation)
  #
  if ( ! $batchmode ) {
    invalIndexEntry($objid);
  }
}


#
# Delete an object from the db
#
sub deleteobject {
  my ($db,$objid) = @_;#this is the internal objectid

  removeconcepts( $objid );
  my $sth = $db->cachedPrepare("delete from object where objectid = ?");
  eval { 
    $sth->execute($objid );
    $sth->finish(); 
  };


  #invalidate all objects that link to this object 
  my @linkedto = getlinkedto( $objid );
  foreach my $l (@linkedto) {
    invalidateobject($l);
  }

  #remove all links from the links table related to the deleted object.
  unlink($objid);
}



#
# Get the unique internal authorid.
#  returns -1 if it doesn't exist
#
sub getauthorid {
  my ($db,$name,$domid)=@_;

  my $sth = $db->cachedPrepare( "select authorid from author where name = ? AND domainid = ?" );
  $sth->execute($name, $domid);

  my $row = $sth->fetchrow_hashref();
  sth->finish();
  if ($row) {
    return $row->{'authorid'};
  }
  return -1;
}

# Add a new author
sub addauthor {
  my ($db,$name,$domid)=@_;
  my $sth = $db->cachedPrepare( "INSERT into author ( name, domainid ) values ( ?, ? )" );
  eval {
    $sth->execute( $name, $domid );
    $sth->finish();
  };

}

# Get the object as a hashref based on the unique internal id
sub getobjecthash {
  my ($db,$objid) = @_;

  my $sth = $db->cachedPrepare("select * from object where objectid = ?");
  $sth->execute( $objid );
  my $row = $sth->fetchrow_hashref();
  $sth->finish();

  return $row
}

# Get the internal object id of the object based on the external id and domain id
sub getobjectid {
  my ($db,$extid,$domid) = @_;

  my $sth = $db->cachedPrepare("select objectid from object where identifier = ? and domainid = ?");
  $sth->execute( $extid, $domid );	 
  my $objectid = -1;
  my $row = $sth->fetchrow_hashref();
  if ( $row ) {
    $objectid = $row->{'objectid'};
  }
  $sth->finish();

  return $objectid;
}

sub getexternalid {
  my ($db,$objid) = @_;

  my $sth = $db->cachedPrepare("select identifier from object where objectid = ?");
  $sth->execute($objid);
  my $row = $sth->fetchrow_hashref();
  $sth->finish();
  return $row->{'identifier'};
}

sub is_valid {
  my ($db,$objid) = @_;
  my $sth = $db->cachedPrepare("select valid from object where objectid = ?");
  $sth->execute($objid);
  my $row = $sth->fetchrow_hashref();
  $sth->finish();
  print "$objid -> VALID : " . $row->{'valid'} . "\n";
  return 1 if ($row->{'valid'});
  return 0;
}

sub getobjectidbycid {
  my ($db,$cid) = @_;
  my $sth = $db->cachedPrepare("SELECT objectid from concepthash where conceptid = ?");
  $sth->execute($cid);
  my $row = $sth->fetchrow_hashref();
  $sth->finish();
  return $row->{'objectid'};
}

1;
