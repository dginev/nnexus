package NNexus;

use DBI;
use strict;

use vars qw( $config $dbh %cached_prepares );

# DBConnect - connect to the database
# 

sub dbConnect {
	#print Dumper ( $config );
	
	$dbh = DBI->connect("DBI:". $config->{'database'}->{'dbms'} .
						":" . $config->{'database'}->{'db_name'} .
						";host=". $config->{'database'}->{'db_host'} ,
						$config->{'database'}->{'db_user'} , 
  						$config->{'database'}->{'db_pass'},
  						{ RaiseError => 0, PrintError  => 0, AutoCommit => 1}
  						);
	return $dbh;  								
}
 
# disconnect (incl. freeing up cached statements)
#
sub dbDisconnect {

	$dbh->disconnect();
}

# do a SQL statement prepare and return, maintaining a cache of already
# prepared statements for potential re-use.
#
# NOTE: it is only useful to use these for immutable statements, with bind
# variables or no variables.
#
sub cachedPrepare {
	my $statement = shift;

	if (not exists $cached_prepares{$statement}) {
		$cached_prepares{$statement} = $dbh->prepare($statement);
	}

	return $cached_prepares{$statement};
}



1;
