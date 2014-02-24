# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Database Interface Module                                           | #
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
package NNexus::DB;
use strict;
use warnings;
use DBI;
use NNexus::DB::API;
# Design: One database handle per NNexus::DB object
#  ideally lightweight, only store DB-specific data in the object

sub new {
  my ($class,%input)=@_;
  # White-list the options we care about:
  my %options;
  $options{dbuser} = $input{dbuser};
  $options{dbpass} = $input{dbpass};
  $options{dbname} = $input{dbname};
  $options{dbhost} = $input{dbhost};
  $options{dbms} = $input{dbms};
  $options{query_cache} = $input{query_cache} || {};
  $options{handle} = $input{handle};
  my $self = bless \%options, $class;
  if (($options{dbms} eq 'SQLite') && ((! -f $options{dbname})||(-z $options{dbname}))) {
    # Auto-vivify a new SQLite database, if not already created
    if (! -f $options{dbname}) {
      # Touch a file if it doesn't exist
      my $now = time;
      utime $now, $now, $options{dbname}; 
    }
    $self->reset_db;
  }
  return $self;
}

# Methods:

# safe - adverb for connection to the database and returning a handle for further "deeds"
sub safe {
  my ($self)=@_;
  if (defined $self->{handle} && $self->{handle}->ping) {
    return $self->{handle};
  } else {
    my $dbh = DBI->connect("DBI:". $self->{dbms} .
			   ":" . $self->{dbname},
			   $self->{dbuser},
			   $self->{dbpass},
			   {
			    host => $self->{'dbhost'},
			    RaiseError => 1,
          AutoCommit => 1
			   }) || die "Could not connect to database: $DBI::errstr";
    $dbh->do('PRAGMA cache_size=50000;') if $self->{dbms} eq 'SQLite';
    $self->{handle}=$dbh;
    $self->_recover_cache;
    return $dbh;
  }
}

# done - adverb for cleaning up. Disconnects and deletes the statement cache

sub done {
  my ($self,$dbh)=@_;
  $dbh = $self->{handle} unless defined $dbh;
  $dbh->disconnect();
  $self->{handle}=undef;
}

###  Safe interfaces for the DBI methods

sub disconnect { done(@_); } # Synonym for done
sub do {
  my ($self,@args) = @_;
  $self->safe->do(@args); }
sub execute {
  my ($self,@args) = @_;
  $self->safe->execute(@args); }
sub ping {
  my ($self,@args) = @_;
  $self->safe->ping(@args); }
sub selectrow_array {
  my ($self,@args) = @_;
  $self->safe->selectrow_array(@args); }
sub selectall_arrayref {
  my ($self,@args) = @_;
  $self->safe->selectall_arrayref(@args); }

sub prepare {
  # Performs an SQL statement prepare and returns, maintaining a cache of already
  # prepared statements for potential re-use..
  #
  # NOTE: it is only useful to use these for immutable statements, with bind
  # variables or no variables.
  my ($self,$statement) = @_;
  my $query_cache = $self->{query_cache};
  if (! exists $query_cache->{$statement}) {
    $query_cache->{$statement} = $self->safe->prepare($statement);
  }
  return $query_cache->{$statement};
}

### Internal helper routines:

sub _recover_cache {
  my ($self) = @_;
  my $query_cache = $self->{query_cache};
  foreach my $statement (keys %$query_cache) {
    $query_cache->{$statement} = $self->safe->prepare($statement); 
  }
}

1;
__END__

=pod

=head1 NAME

C<NNexus::DB> - DBI interface for NNexus, provides one DBI handle per NNexus::DB object.

=head1 SYNOPSIS

  use NNexus::DB;
  $db = NNexus::DB(dbuser=>'nnexus',dbpass=>'pass',dbname=>"nnexus",dbhost=>"localhost", dbms=>"mysql");
  $connection_alive = $db->ping;
  $statement_handle = $db->prepare('DBI sql statement');
  $db->execute('DBI sql statement');
  $disconnect_successful = $db->done;

=head1 DESCRIPTION

Interface to DBI's SQL logic. Provides an Object-oriented approach, 
  where each NNexus::DB object contains a single DBI handle, 
  together with a cache of prepared statements.

The documentation assumes basic familiarity with DBI.

=head2 METHODS

=over 4

=item C<< $db = NNexus::Job->new(%options); >>

Creates a new C<NNexus::DB> object.
  Required options are dbuser, dbpass, dbname, dbhost and dbms, so that
  the database connection can be successfully created.

=item C<< $response = $db->DBI_handle_command; >>

The C<NNexus::DB> methods are interfaces to their counterparts in L<DBI>, with the addition of a query cache and
  a safety mechanism that auto-vivifies the connection when needed.

=item C<< $sth = $db->safe; >>

The F<safe> adverb returns a L<DBI> handle, taking extra care that the handle is properly connected to
  the respective DB backend.
  While you could take the L<DBI> handle and use it directly (it is the return value of the F<safe> method),
  avoid that approach.

Instead, always invoke L<DBI> commands through the C<NNexus::DB> object or explicitly use the F<safe> adverb to get a handle,
  e.g. C<$db-<gt>execute>, C<$db-<gt>prepare> or C<$sth = $db-<gt>safe>
  The cache of prepared statements is also rejuvenated whenever a new L<DBI> handle is auto-created.

=item C<< $disconnect_successful = $db->done; >>

Disconnects from the backend and destroys the L<DBI> handle.
  Note that the cache of prepared statements will be rejuvenated
  when a new L<DBI> handle is initialized.

=item C<< $statement_handle = $db->prepare; >>

Cached preparation of SQL statements. Internally uses the F<safe> adverb, to ensure robustness.
  Each SQL query and its L<DBI> statement handle is cached, to avoid multiple prepare calls on the same query string.

=back

=head1 SEE ALSO

L<NNexus::DB::API>, L<DBI>

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by
 the KWARC group at Jacobs University Bremen.
 Released under the MIT license (MIT)

=cut
