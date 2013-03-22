# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Runtime Configuration Module                                        | #
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

package NNexus::Config;
use strict;

use XML::Simple;
use Data::Dumper;
use NNexus::Concepts;
use NNexus::Classification;
use NNexus::Domain;
use NNexus::DB;

sub new {
  my ($class,$opts) = @_;
  $opts = XMLin('./baseconf.xml') unless defined $opts;
  if ($opts->{verbosity} && $opts->{verbosity} > 0) {
    print STDERR "Starting NNexus with configuration:\n";
    print STDERR Dumper( $opts );
  }
  my $db = NNexus::DB->new(config=>$opts);
  $opts->{db} = $db;
  # DG: Deprecating for now.
  #load up the menuing code;
  # open (MENUFILE, "<", $config->{'menufile'});
  # while ( <MENUFILE> ) {
  #   $menuscript .= $_;
  # }

  #now initialize the db with domain info;
  my $sth = $db->prepare( "select * FROM domain WHERE name = ?");
  my $ins = $db->prepare( "insert into domain (name, urltemplate, code, nickname) values ( ? , ?, ?, ? )" );
  my $upd = $db->prepare( "update domain set urltemplate = ?, code = ?, nickname = ? where name = ?" );

  my $ref = $opts->{'domains'}->{'domain'};
  print STDERR Dumper($ref) if $opts->{verbosity}>0;
  foreach my $k ( @$ref ) {
    if ( defined $k->{'name'} ) {
      my $name = $k->{'name'};
      print STDERR "current domain " . $name . "\n";
      $sth->execute( "$name" );		
      #print Dumper($ref);
      my @data = $sth->fetchrow_array();
      if ($#data < 0) {
        #we add a new row in the domain table if the domain doesn't exist
        print STDERR $name . " " . $k->{'urltemplate'} . "\n";
        $ins->execute( $k->{'name'} , 
		       $k->{'urltemplate'}, 
		       $k->{'code'},
		       $k->{'nickname'}
		    );
        $ins->finish();
	      $k->{'domainid'} = getdb_domain_id($k); 
      } else {
        print STDERR "updating domain $name $k->{urltemplate}\n";
        $upd->execute(  $k->{'urltemplate'}, 
        $k->{'code'},
        $k->{'nickname'}, $k->{'name'} );
        $k->{'domainid'}  = $data[0];
      }
      # for faster lookup of domain id we add it to the config
      #fix this because if it is new we will not have the domainid
    }
  }
  my $classification = NNexus::Classification->new(db=>$db,config=>{ %$opts });
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
  $_[0]->{db};
}

1;

__END__

=pod 

=head1 NAME

C<NNexus::Config> - Configuration class for NNexus startup

=head1 SYNOPSIS

    use NNexus::Config;
    my $config = NNexus::Config->new($opts);

=head1 DESCRIPTION

Refactored from the old NNexus approach to startup, creates a configuration object for a NNexus server.

NOTE: A huge refactoring job is still ahead of this class...

=head2 METHODS

=over 4

=item C<< my $config = NNexus::Config->new($opts); >>

Initialize a new configuration object.
Options are given via an optional XML::Simple object $opts, or in an XML syntax in "baseconf.xml" in the current directory.
TODO: Add XML syntax docs somewhere here

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>
(Based on code from James Gardner and Aaron Krowne)

=head1 COPYRIGHT

GPLv3

=cut
