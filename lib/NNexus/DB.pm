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

package NNexus::DB;
use strict;
use warnings;
use DBI;
# Design: One database handle per NNexus::DB object
#  ideally lightweight, only store DB-specific data in the object

sub new {
  my ($class,%input)=@_;
  my %options;
  if (my $config = $input{config}) {
    my $database = $config->{database};
    $options{dbuser} = $database->{dbuser};
    $options{dbpass} = $database->{dbpass};
    $options{dbname} = $database->{dbname};
    $options{dbhost} = $database->{dbhost};
    $options{dbms} = $database->{dbms};
  }
  $options{'query_cache'} = $input{'query_cache'} || {};
  $options{'handle'} = $input{'handle'};
  bless \%options, $class;
}

# Methods: 

# do - adverb for connection to the database and returning a handle for further "deeds"
sub do {
  my ($self)=@_;
  # TODO: Kind of assuming the $config is the same throughout, maybe customize more?
  if (defined $self->{handle} && $self->{handle}->ping) {
    return $self->{handle};
  } else {
    my $dbh = DBI->connect("DBI:". $self->{'dbms'} .
			 ":" . $self->{'dbname'} .
			 ";host=". $self->{'dbhost'} ,
			 $self->{'dbuser'} , 
			 $self->{'dbpass'},
			 { RaiseError => 1 }
			) || die "Could not connect to database: $DBI::errstr";
    $self->{handle}=$dbh;
    return $dbh;
  }
}

 
# done - adverb for cleaning up. Disconnects and deletes the statement cache
sub done {
  my ($self,$dbh)=@_;
  $dbh = $self->{dbh} unless defined $dbh;
  $dbh->disconnect();
  $self->{dbh}=undef;
  $self->{query_cache} = undef;
}

# Performs an SQL statement prepare and returns, maintaining a cache of already
# prepared statements for potential re-use..
#
# NOTE: it is only useful to use these for immutable statements, with bind
# variables or no variables.
sub prepare {
	my ($self,$statement) = @_;
	my $query_cache = $self->{query_cache};
	if (! exists $query_cache->{$statement}) {
		$query_cache->{$statement} = $self->do->prepare($statement);
	}
	return $query_cache->{$statement};
}

1;

__END__