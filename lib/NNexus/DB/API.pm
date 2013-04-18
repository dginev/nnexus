# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Backend API Module                                                  | #
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

package NNexus::DB::API;
use strict;
use warnings;
use feature 'switch';
use DBI;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(add_object_by select_object_by select_concepts_by last_inserted_id
               add_concept_by delete_concept_by invalidate_by reset_db
	       select_firstword_matches clear_linkscache_by add_linkscache_by);

### API for Table: Object

sub add_object_by {
  my ($db,%options) = @_;
  my ($url, $domain) = map {$options{$_}} qw(url domain);
  my $sth = $db->prepare("INSERT into objects (url, domain) values (?, ?)");
  $sth->execute($url,$domain);
  $sth->finish();
  # Return the object id in order to update the concepts and classification
  return last_inserted_id($db);
}

sub select_object_by {
  my ($db,%options) = @_;
  my $url = $options{url};
  return unless $url;
  my $sth = $db->prepare("select objectid, domain from objects where (url = ?)");
  $sth->execute($url);
  my $object = $sth->fetchrow_hashref;
  $sth->finish();
  return $object;
}

### API for Table: Concept

sub select_concepts_by {
  my ($db,%options) = @_;
  my $objectid = $options{objectid};
  return unless $objectid;
  my $sth = $db->prepare("select conceptid,firstword,tailwords,category,link from concepts where (objectid = ?)");
  $sth->execute($objectid);
  my $concepts = [];
  while (my $row = $sth->fetchrow_hashref()) {
    push @$concepts, $row;
  }
  $sth->finish();
  return $concepts;
}

sub delete_concept_by {
  my ($db, %options) = @_;
  my ($firstword, $tailwords, $concept, $category, $objectid) = map {$options{$_}} qw(firstword tailwords concept category objectid);
  if ($concept) {
      $concept=~s/^(\w(\w|[\-\+\'])*)(\s|$)//;
      $firstword = $1;
      $tailwords = $concept;
      undef $concept;
  }
  return unless $firstword && $tailwords && $category && $objectid; # Mandatory fields. TODO: Raise error?
  $firstword = lc($firstword); # We only record lower-cased concepts, avoid oversights
  $tailwords = lc($tailwords); # ditto
  my $sth = $db->prepare("delete * from concepts where (firstword = ? AND tailwords = ? AND category = ? AND objectid = ?)");
  $sth->execute($firstword,$concept,$category,$objectid);
  $sth->finish();
}

sub add_concept_by {
  my ($db, %options) = @_;
  my ($concept, $category, $objectid, $domain, $link, $firstword, $tailwords) =
    map {$options{$_}} qw(concept category objectid domain link firstword tailwords);
  return unless $concept && $category && $objectid && $link && $domain; # Mandatory fields. TODO: Raise error?
  $concept = lc($concept); # Only record lower-cased concepts
  if ((! $firstword) && $concept=~s/^(\w(\w|[\-\+\'])*)(\s|$)//) { # Grab first word if not provided
    $firstword = $1;
    $tailwords = $concept;
    if (! $firstword) {
      print STDERR "Error: No firstword for $concept at $link!\n\n";
      return;
    }
  }
  my $sth = $db->prepare("insert into concepts (firstword, tailwords, category, objectid, domain, link) values (?, ?, ?, ?, ?, ?)");
  $sth->execute($firstword, $tailwords, $category, $objectid, $domain, $link);
  $sth->finish();
}

# get the possible matches based on the first word of a concept
# returns as an array containing a hash with newterm
sub select_firstword_matches {
  my ($db,$word) = @_;
  my @matches = ();

  my $sth = $db->prepare("SELECT conceptid, firstword, tailwords, category, scheme,
     domain, link, objectid from concepts where firstword=?");
  $sth->execute($word);
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @matches, $row;
  }
  $sth->finish();
  return @matches;
}

### API for Table: Invalidate *
# TODO:

sub invalidate_by{();}

### API for Table: Links_cache

sub clear_linkscache_by {
  my ($db,%options) = @_;
  my $objectid = $options{objectid};
  return unless $objectid;
  my $sth = $db->prepare("delete * from links_cache where objectid=?");
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
use Data::Dumper;
sub reset_db {
my ($self) = @_;
$self = $self->safe; # unsafe but faster...

# Table structure for table categories
$self->do("DROP TABLE IF EXISTS categories;");
$self->do("CREATE TABLE categories (
  categoryid integer primary key AUTOINCREMENT,
  categoryname varchar(100) NOT NULL DEFAULT '',
  externalid text,
  scheme varchar(50) NOT NULL DEFAULT ''
);");

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

# Table structure for table links_cache
$self->do("DROP TABLE IF EXISTS links_cache;");
$self->do("CREATE TABLE links_cache (
  objectid integer NOT NULL,
  conceptid integer NOT NULL,
  PRIMARY KEY (objectid, conceptid)
);");


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
$self->do("CREATE INDEX conceptidx ON concepts(firstword);");
# TODO: Do we need this one?
#$self->do("CREATE INDEX conceptidx ON concept(concept);");
$self->do("CREATE INDEX objectididx ON concepts(objectid);");

# Table structure for table candidates
$self->do("DROP TABLE IF EXISTS candidates;");
$self->do("CREATE TABLE candidates (
  candidateid integer primary key AUTOINCREMENT,
  firstword varchar(50) NOT NULL,
  candidate varchar(255) NOT NULL,
  confidence real NOT NULL DEFAULT 0
);");

# Table structure for table domain
$self->do("DROP TABLE IF EXISTS domains;");
$self->do("CREATE TABLE domains (
  domainid integer primary key AUTOINCREMENT,
  name varchar(30) NOT NULL DEFAULT '' UNIQUE,
  urltemplate varchar(100) DEFAULT NULL,
  code varchar(2) DEFAULT NULL,
  priority varchar(30) DEFAULT '',
  nickname varchar(50) DEFAULT NULL
);");

# Table structure for table ontology
$self->do("DROP TABLE IF EXISTS ontology;");
$self->do("CREATE TABLE ontology (
  child varchar(100) DEFAULT NULL,
  parent varchar(100) DEFAULT NULL,
  weight int(11) DEFAULT NULL,
  PRIMARY KEY (child, parent, weight)
);");
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

Adds a new object, identified by a URL and, for convenience, a domain.

=item C<< $db->select_objectid_by_url($url); >>

Retrieve the internal objectid of an object, identified by its URL.

=back

=head3 Generic Methods

=over 4

=item C<< $db->last_inserted_id; >>

Return the last inserted id, in an auto-generated primary key column.
  DBMS-independent, supports MySQL and SQLite so far.

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the GNU Public License

=cut

