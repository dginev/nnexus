package NNexus;
use strict;

use XML::Simple;
use Data::Dumper;
use NNexus::Concepts;
use NNexus::Classification;

use vars qw( $config $dbh $menuscript );

sub init { 
	$config = XMLin('/var/www/nnexus/baseconf.xml');
	print "Starting NNexus with configuration:\n";
	print Dumper( [$config] );

	dbConnect();	

#load up the menuing code;
	open (MENUFILE, $config->{'menufile'});
	while ( <MENUFILE> ) {
		$menuscript .= $_;
	}

#now initialize the db with domain info;
	my $sth = $dbh->prepare( "select * FROM domain WHERE name = ?");
	my $ins = $dbh->prepare( "insert into domain (name, urltemplate, code, nickname) values ( ? , ?, ?, ? )" );
	my $upd = $dbh->prepare( "update domain set urltemplate = ?, code = ?, nickname = ? where name = ?" );

	my $ref = $config->{'domains'}->{'domain'};
	print Dumper($ref);
	foreach my $k ( @$ref )
	{
		if ( defined $k->{'name'} ) {
			my $name = $k->{'name'};
			print "current domain " . $name . "\n";
			$sth->execute( "$name" );		
#print Dumper($ref);
			my @data = $sth->fetchrow_array();
			if ($#data < 0){
#we add a new row in the domain table if the domain doesn't exist
				print $name . " " . $k->{'urltemplate'} . "\n";
				$ins->execute( $k->{'name'} , 
						$k->{'urltemplate'}, 
						$k->{'code'},
						$k->{'nickname'}
					     );
				$ins->finish();
				$k->{'domainid'} = getdomainidfromdb($k); 
			} else {
				print "updating domain $name $k->{urltemplate}\n";
				$upd->execute(  $k->{'urltemplate'}, 
						$k->{'code'},
						$k->{'nickname'}, $k->{'name'} );
				$k->{'domainid'}  = $data[0];
			}
# for faster lookup of domain id we add it to the config
#fix this because if it is new we will not have the domainid
		}

	}
	initClassificationModule();
}

sub getStyleSheetLink {
	return $config->{'stylesheet'};
}

sub getDomainConfig {
	my $domain = shift;
	my $arg = shift;

	return $config->{'domains'}->{'domain'}->{$domain}->{$arg};
}

sub dbConnect {

# connect to db
#
	$dbh = DBI->connect("DBI:". $config->{'database'}->{'dbms'} .
			":" . $config->{'database'}->{'dbname'} .
			";host=". $config->{'database'}->{'dbhost'} ,
			$config->{'database'}->{'dbuser'} , 
			$config->{'database'}->{'dbpass'},
			{ RaiseError => 1 }
			) || die "Could not connect to database: $DBI::errstr";

}

1;
