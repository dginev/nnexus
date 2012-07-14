package NNexus::Config;
use strict;

use XML::Simple;
use Data::Dumper;
use NNexus::Concepts;
use NNexus::Classification;
use NNexus::DB;

sub new {
  my ($class,$opts) = @_;
  $opts = XMLin('/var/www/nnexus/baseconf.xml') unless defined $opts;
  print "Starting NNexus with configuration:\n";
  print Dumper( $opts );
  $opts->{nnexus_db} = NNexus::DB->new(config=>$opts);
  my $dbh = $opts->{nnexus_db}->dbConnect;
  # DG: Deprecating for now.
  #load up the menuing code;
  # open (MENUFILE, "<", $config->{'menufile'});
  # while ( <MENUFILE> ) {
  #   $menuscript .= $_;
  # }

  #now initialize the db with domain info;
  my $sth = $dbh->prepare( "select * FROM domain WHERE name = ?");
  my $ins = $dbh->prepare( "insert into domain (name, urltemplate, code, nickname) values ( ? , ?, ?, ? )" );
  my $upd = $dbh->prepare( "update domain set urltemplate = ?, code = ?, nickname = ? where name = ?" );

  my $ref = $opts->{'domains'}->{'domain'};
  print Dumper($ref);
  foreach my $k ( @$ref ) {
    if ( defined $k->{'name'} ) {
      my $name = $k->{'name'};
      print "current domain " . $name . "\n";
      $sth->execute( "$name" );		
      #print Dumper($ref);
      my @data = $sth->fetchrow_array();
      if ($#data < 0) {
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
  my $classification=NNexus::Classification->new(db=>$opts->{nnexus_db},config=>{ %$opts });
  $classification->initClassificationModule();
  $opts->{classification} = $classification;
  bless $opts, $class;
}

sub getStyleSheetLink {
  return $_[0]->{'stylesheet'};
}

sub getDomainConfig {
  my ($self,$domain,$arg) = @_;
  return $self->{'domains'}->{'domain'}->{$domain}->{$arg};
}

sub get_DB {
  $_[0]->{nnexus_db};
}

1;
