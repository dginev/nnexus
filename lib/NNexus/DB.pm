package NNexus::DB;

use DBI;
use strict;
use warnings;

sub new {
  my ($class,%opts)=@_;
  $opts{'config'}={} unless defined $opts{'config'};
  $opts{'query_cache'}={} unless defined $opts{'query_cache'};
  $opts{'dbh'}=undef unless defined $opts{'dbh'};
  bless \%opts, $class;
}

# Methods: 
# M1. Getters, setters, OO Perl
sub get_config {
  $_[0]->{config};
}

sub set_config {
  $_[0]->{config} = $_[1];
}

sub query_cache {
  $_[0]->{query_cache};
}

# M2. DBConnect - connect to the database
sub dbConnect {
  my ($self,$config)=@_;
  # TODO: Kind of assuming the $config is the same throughout, maybe customize more?
  if (defined $self->{dbh}) {
    return $self->{dbh};
  } else {
    $config = $self->get_config unless defined $config;
    my $dbh = DBI->connect("DBI:". $config->{'database'}->{'dbms'} .
			 ":" . $config->{'database'}->{'dbname'} .
			 ";host=". $config->{'database'}->{'dbhost'} ,
			 $config->{'database'}->{'dbuser'} , 
			 $config->{'database'}->{'dbpass'},
			 { RaiseError => 1 }
			) || die "Could not connect to database: $DBI::errstr";
    $self->{dbh}=$dbh;
    return $dbh;
  }
}

 
# disconnect (incl. freeing up cached statements)
#
sub dbDisconnect {
  my ($self,$dbh)=@_;
  $dbh = $self->{dbh} unless defined $dbh;
  $dbh->disconnect();
  $self->{dbh}=undef;
  $self->{query_cache} = undef;
}

# do a SQL statement prepare and return, maintaining a cache of already
# prepared statements for potential re-use.
#
# NOTE: it is only useful to use these for immutable statements, with bind
# variables or no variables.
#
sub cachedPrepare {
	my ($self,$statement) = @_;
	my $query_cache = $self->{query_cache};
	my $dbh = $self->dbConnect; # Should really be called dbMaybeConnect
	if (not exists $query_cache->{$statement}) {
		$query_cache->{$statement} = $dbh->prepare($statement);
	}

	return $query_cache->{$statement};
}

1;
