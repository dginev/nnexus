# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Backend API Module                                                  | #
# |=====================================================================| #
# | Part of the Planetary project: http://trac.mathweb.org/planetary    | #
# |  Research software, produced as part of work done by:               | #
# |  the KWARC group at Jacobs University                               | #
# | Copyright (c) 2012                                                  | #
# | Released under the MIT License (MIT)                                | #
# |---------------------------------------------------------------------| #
# | Adapted from the original NNexus code by                            | #
# |                                  James Gardner and Aaron Krowne     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev <d.ginev@jacobs-university.de>                  #_#     | #
# | http://kwarc.info/people/dginev                            (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package NNexus::DB::API;
use strict;
use warnings;
use feature 'switch';
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(add_object_by select_object_by select_concepts_by last_inserted_id
         add_concept_by delete_concept_by invalidate_by reset_db
	       select_firstword_matches
         select_linkscache_by delete_linkscache_by add_linkscache_by);

use NNexus::Morphology qw(firstword_split);

### API for Table: Objects

sub add_object_by {
  my ($db,%options) = @_;
  my ($url, $domain) = map {$options{$_}} qw(url domain);
  return unless $url && $domain;
  my $sth = $db->prepare("INSERT into objects (url, domain) values (?, ?)");
  $sth->execute($url,$domain);
  $sth->finish();
  # Return the object id in order to update the concepts and classification
  return $db->last_inserted_id();
}

sub select_object_by {
  my ($db,%options) = @_;
  my ($url,$objectid) = map {$options{$_}} qw/url objectid/;
  my $sth;
  if ($url) {
    $sth = $db->prepare("select objectid, domain from objects where (url = ?)");
    $sth->execute($url); }
  elsif ($objectid) {
    $sth = $db->prepare("select url from objects where (objectid = ?)");
    $sth->execute($objectid); }

  my $object = $sth->fetchrow_hashref;
  $sth->finish();
  return $object;
}

### API for Table: Concept

sub select_concepts_by {
  my ($db,%options) = @_;
  my ($concept,$category,$scheme,$objectid,$firstword,$tailwords) = 
    map {$options{$_}} qw/concept category scheme objectid firstword tailwords/;
  if ($concept && (!$firstword)) {
      ($firstword,$tailwords) = firstword_split($concept);
  }
  my $concepts = [];
  my $sth;
  if ($firstword && $category && $scheme && $objectid) {
    # Selector for invalidation
    $sth = $db->prepare("select * from concepts where (objectid = ? AND firstword = ? AND tailwords = ? AND scheme = ? AND category = ? )");
    $sth->execute($objectid,$firstword,$tailwords,$scheme,$category);
  } elsif ($objectid) {
    $sth = $db->prepare("select * from concepts where (objectid = ?)");
    $sth->execute($objectid);
  } else { return []; } # Garbage in - garbage out. TODO: Error message?

  while (my $row = $sth->fetchrow_hashref()) {
    $row->{tailwords} //= '';
    $row->{concept} = $row->{firstword}.($row->{tailwords} ? " ".$row->{tailwords} : '');
    push @$concepts, $row;
  }
  $sth->finish();
  
  return $concepts;
}

sub delete_concept_by {
  my ($db, %options) = @_;
  my ($firstword, $tailwords, $concept, $category, $objectid) = map {$options{$_}} qw(firstword tailwords concept category objectid);
  if ($concept && (!$firstword)) {
      ($firstword,$tailwords) = firstword_split($concept);
  }
  return unless $firstword && $category && $objectid; # Mandatory fields. TODO: Raise error?
  $firstword = lc($firstword); # We only record lower-cased concepts, avoid oversights
  $tailwords = lc($tailwords)||''; # ditto
  my $sth = $db->prepare("delete from concepts where (firstword = ? AND tailwords = ? AND category = ? AND objectid = ?)");
  $sth->execute($firstword,$tailwords,$category,$objectid);
  $sth->finish();
}

sub add_concept_by {
  my ($db, %options) = @_;
  my ($concept, $category, $objectid, $domain, $link, $scheme, $firstword, $tailwords) =
    map {$options{$_}} qw(concept category objectid domain link scheme firstword tailwords);
  return unless ($firstword || $concept) && $category && $objectid && $link && $domain; # Mandatory fields. TODO: Raise error?
  $scheme = 'msc' unless $scheme;
  if (! $firstword) {
    $concept = lc($concept); # Only record lower-cased concepts
    ($firstword,$tailwords) = firstword_split($concept); 
  }
  if (! $firstword) {
    print STDERR "Error: No firstword for $concept at $link!\n\n";
    return;
  }
  my $sth = $db->prepare("insert into concepts (firstword, tailwords, category, scheme, objectid, domain, link) values (?, ?, ?, ?, ?, ?, ?)");
  $sth->execute($firstword, $tailwords, $category, $scheme, $objectid, $domain, $link);
  $sth->finish();
  return last_inserted_id($db);
}

# get the possible matches based on the first word of a concept
# returns as an array containing a hash with newterm
sub select_firstword_matches {
  my ($db,$word,%options) = @_;
  my @matches = ();
  my $domain = $options{domain};
  my $sth;
  if ($domain && ($domain ne 'all')) {
    $sth = $db->prepare("SELECT conceptid, firstword, tailwords, category, scheme,
      domain, link, objectid from concepts where firstword=? AND domain=?");
    $sth->execute($word,$domain);
  } else {
    $sth = $db->prepare("SELECT conceptid, firstword, tailwords, category, scheme,
      domain, link, objectid from concepts where firstword=?");
    $sth->execute($word);
  }

  my %row;
  $sth->bind_columns( \( @row{ @{$sth->{NAME_lc} } } ));
  while ($sth->fetch) {
    $row{concept} = $row{firstword}.($row{tailwords} ? " ".$row{tailwords} : '');
    push @matches, {%row};
  }
  $sth->finish();
  return @matches;
}

### API for Table: Links_cache

sub delete_linkscache_by {
  my ($db,%options) = @_;
  my $objectid = $options{objectid};
  return unless $objectid;
  my $sth = $db->prepare("delete from links_cache where objectid=?");
  $sth->execute($objectid);
  $sth->finish();
}

sub add_linkscache_by{
  my ($db,%options) = @_;
  my $objectid = $options{objectid};
  my $conceptid = $options{conceptid};
  return unless $objectid && $conceptid;
  my $sth = $db->prepare("insert into links_cache (conceptid,objectid) values (?,?) ");
  $sth->execute($conceptid,$objectid);
  $sth->finish();
}

sub select_linkscache_by {
  my ($db,%options)=@_;
  my $conceptid = $options{conceptid};
  my $objectid = $options{objectid};
  my $sth;
  if ($conceptid) {
    $sth = $db->prepare("SELECT objectid from links_cache WHERE conceptid=?");
    $sth->execute($conceptid); }
  elsif ($objectid) {
    $sth = $db->prepare("SELECT conceptid from links_cache WHERE objectid=?");
    $sth->execute($objectid); }
  else {return []; }
  my $results = [];
  while (my @row = $sth->fetchrow_array()) {
    push @$results, @row;
  }
  $sth->finish();
  return $results;
}

# Alias, more semantic
sub invalidate_by { 
  my ($db,%options)=@_;
  my $objectids = $db->select_linkscache_by(%options); 
  my @urls = ();
  foreach my $objectid(@$objectids) {
    push @urls, $db->select_object_by(objectid=>$objectid)->{url};
  }
  return @urls; }

### Generic DB API

sub last_inserted_id {
  my ($db) = @_;
  my $objid;
  given ($db->{dbms}) {
    when ('mysql') {
      $objid = $db->{handle}->{'mysql_insertid'};
    }
    when ('SQLite') {
      $objid = $db->{handle}->sqlite_last_insert_rowid();
    }
    default { die 'No DBMS information provided! Failing...'; }
  };
  return $objid;
}

### API for Initializing a SQLite Database:
sub reset_db {
my ($self) = @_;
$self = $self->safe; # unsafe but faster...
# Request a 20 MB cache size, reasonable on all modern systems:
$self->do("PRAGMA cache_size = 20000; ");
# Table structure for table object
$self->do("DROP TABLE IF EXISTS objects;");
$self->do("CREATE TABLE objects (
  objectid integer primary key AUTOINCREMENT,
  url varchar(2083) NOT NULL UNIQUE,
  domain varchar(50),
 -- TODO: Do we really care about modified?
  modified timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);");
# TODO: Rethink this trigger, do we need modified?
$self->do("CREATE TRIGGER ObjectModified
AFTER UPDATE ON objects
BEGIN
 UPDATE objects SET modified = CURRENT_TIMESTAMP WHERE objectid = old.objectid;
END;");

# Table structure for table concept
# A 'concept' has a 'firstword', belongs to a 'category' (e.g. 10-XX) with a certain 'scheme' (e.g. MSC) and is defined at a 'link', obtained while traversing an object known via 'objectid'. The concept inherits the 'domain' of the object (e.g. PlanetMath).
# The distinction between link and objectid allows for a level of indirection, e.g. in DLMF, where we would obtain the 'link's that define concepts while at a higher (e.g. index) webpage, only which we would register in the object table. The reindexing should be driven by the traversal process, while the linking should use the actual obtained URL for the concept definition.
$self->do("DROP TABLE IF EXISTS concepts;");
$self->do("CREATE TABLE concepts (
  conceptid integer primary key AUTOINCREMENT,
  firstword varchar(50) NOT NULL,
  tailwords varchar(255),
  category varchar(10) NOT NULL,
  scheme varchar(10) NOT NULL DEFAULT 'msc',
  domain varchar(50) NOT NULL,
  link varchar(2053) NOT NULL,
  objectid int(11) NOT NULL
);");
# TODO: Do we need this one?
#$self->do("CREATE INDEX conceptidx ON concept(concept);");
$self->do("CREATE INDEX conceptidx ON concepts(firstword);");
$self->do("CREATE INDEX objectididx ON concepts(objectid);");

# Table structure for table candidates
$self->do("DROP TABLE IF EXISTS candidates;");
$self->do("CREATE TABLE candidates (
  candidateid integer primary key AUTOINCREMENT,
  firstword varchar(50) NOT NULL,
  tailwords varchar(255) NOT NULL,
  confidence real NOT NULL DEFAULT 0
);");

# Table structure for table links_cache
$self->do("DROP TABLE IF EXISTS links_cache;");
$self->do("CREATE TABLE links_cache (
  objectid integer NOT NULL,
  conceptid integer NOT NULL,
  PRIMARY KEY (objectid, conceptid)
);");
$self->do("CREATE INDEX linkscache_objectid_idx ON links_cache(objectid);");
$self->do("CREATE INDEX linkscache_conceptid_idx ON links_cache(conceptid);");

# Table structure for table dangling_cache
$self->do("DROP TABLE IF EXISTS dangling_cache;");
$self->do("CREATE TABLE dangling_cache (
  objectid integer NOT NULL,
  candidateid integer NOT NULL,
  PRIMARY KEY (objectid, candidateid)
);");
$self->do("CREATE INDEX danglingcache_objectid_idx ON links_cache(objectid);");
$self->do("CREATE INDEX danglingcache_concept_idx ON links_cache(conceptid);");

}

1;
__END__

=pod 

=head1 NAME

C<NNexus::DB::API> - API routines for commonly used NNexus queries

=head1 SYNOPSIS

    use NNexus::DB;
    my $db = NNexus::DB->new(%options);
    $db->method(@arguments);

=head1 DESCRIPTION

This class provides API methods for specific SQL queries commonly needed by NNexus.

=head2 METHODS

=head3 Table: Objects

=over 4

=item C<< $db->add_object_by(url=>$url,domain=>$domain); >>

Adds a new object, identified by its $url and $domain.
The $domain should match the name of the NNexus::Index::$domain
plug-in class.

=item C<< $db->select_object_by(url=>$url,objectid=>$objectid); >>

Retrieve the DB row of an object, identified by its $url,
OR $objectid.
Returns a Perl hashref, each key being a DB column name.

=back

=head3 Table: Concepts

=over 4

=item C<< $db->add_concept_by(%options); >>

=item C<< $db->select_concept_by(%options); >>

=item C<< $db->delete_concept_by(%options); >>

=item C<< $db->select_firstword_matches($word); >>

=back

=head3 Table: Links_cache

=over 4

=item C<< $db->add_linkscache_by(%options); >>

=item C<< $db->select_linkscache_by(%options); >>

=item C<< $db->delete_linkscache_by(%options); >>

=item C<< $db->invalidate_by(%options); >>

=back

=head3 Generic Methods

=over 4

=item C<< $db->last_inserted_id; >>

Return the last inserted id, in an auto-generated primary key column.
  DBMS-independent, supports MySQL and SQLite so far.

=item C<< $db->reset_db; >>

Reset, and if necessary initialize, a SQLite database.
This routine holds the reference code, defining the NNexus database schema.
NOTE: Only works for a SQLite backend.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the MIT license (MIT)

=cut

