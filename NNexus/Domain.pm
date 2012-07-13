#/usr/bin/perl

package NNexus;

use strict;

use Encode qw{is_utf8};
use Time::HiRes qw ( time alarm sleep );
use LWP::Simple;

use NNexus::Classification;
use NNexus::Concepts;
use NNexus::DB;

use vars qw( $config );

#
# Get the domainid from config hash.
#
sub getdomainid {
	my $domain = shift;

	my $ref = $config->{'domains'}->{'domain'};
	foreach my $d (@$ref) {
		if ( $d->{'name'} eq $domain ) {
			return $d->{'domainid'};
		}
	}
}

# get the domain specific blacklist
sub getdomainblacklist {
	my $domain = shift;

	my $ref = $config->{'domains'}->{'domain'};
	foreach my $d (@$ref) {
		if ( $d->{'name'} eq $domain ) {
			my $url = $d->{'link'};
			my $content = get("$url");
			if ( $content ) {
				my $ref = XMLin($content);
				my @bl = split( /\s*,\s*/, $d->{'blacklist'} );
				foreach my $b ( @bl ) {
					$b = lc($b);
				}
				return \@bl;
			}
		}
		print "using default blacklist\n";
		my @empty = ();
		return \@empty;
	}
}

#get the domain priorities as an arrayref of domain ids
sub getdomainpriorities {
	my $domain = shift;

	my @priorities = ();

	my $domains = $config->{'domains'}->{'domain'};
	foreach my $d (@$domains) {
		my $url = $d->{'link'};
		print "Getting domain priorities for $domain at $url\n";
		my $content = get("$url");
		print "We got $content from $url\n";
		if ( defined $content ) {
			my $ref = XMLin($content);
			my @prio = split( /\s*,\s*/, $ref->{'priority'} );
			foreach my $p (@prio){
				push @priorities, getdomainidfromdb($p);
			}
			return \@priorities;
		}
	}

	print "using default priorities\n";
	push @priorities, (1,2,3,4,5,6,7,8,10,11,12,13,14,15,16,17);
	return \@priorities;
}

#
# Get the domainid from the DB.
# Note: this should only be called to determine the id of a new domain from
#  the Config.pm file
#
sub getdomainidfromdb {
	my $domain = shift;

#we no longer use the db we just use the config hash

	my $sth =cachedPrepare( "select domainid FROM domain WHERE name = ?");
	$sth->execute( $domain );
	my $domid;
	$sth->bind_columns(\$domid);
	$sth->fetch();
	$sth->finish();

	return $domid;
}



#
# Get the domainname from the DB.
#

#CACHE this stuff.
my %domaincache = ();
sub getdomainhash {
	my $domid = shift;

	print "getting domain hash for domain $domid";

	if ( ! exists $domaincache{$domid} ) {
		my $sth = cachedPrepare( "select * from domain where domainid = ?" );
		$sth->execute( $domid );
		if ( my $row = $sth->fetchrow_hashref() ) {
			print "updating domaincache to\n";
			$domaincache{$domid} = $row;
			print Dumper( \%domaincache );
		} else {
			print "ERROR: tried to update domaincache\n";
		}
	}

	print "returning ";
	print Dumper( $domaincache{$domid} );
	return $domaincache{$domid};
}




1;
