package NNexus;

###############################################################################
#
# Routines for handling linking policies.
# 
###############################################################################

#most of this code is from the Noosphere project.
# authors: James Gardner and Aaron Krowne.

use strict;

use Time::HiRes qw ( time alarm sleep );


# decide which object to link to from the target object, given a list of 
# candidate object IDs and the concept label
# 
sub post_resolve_linkpolicy {
	my $target = shift;
	my $concept = shift;
	my $classes = shift;
	my @pool = @_;			#candidate conceptids

	my %policies;
	
	my $DEBUG = 0;
	
	my $start = time() if ($DEBUG);
	
	foreach my $pid (@pool) {
		$policies{$pid} = loadpolicy($pid);
	}
	
	# pull out link policy information and compare 
	#
	
	my %compare;

	foreach my $pid (@pool) {
		if (defined $policies{$pid}->{'priority'} &&
			(not defined $policies{$pid}->{'priority'}->{'concept'} ||
			$policies{$pid}->{'priority'}->{'concept'} eq $concept)) {
			
			$compare{$pid} = $policies{$pid}->{'priority'}->{'value'};

		} else {
			$compare{$pid} = 100; # default priority
		}
	}
	
	my @remove = ();
	my %permitted = ();

	foreach my $pid (@pool){	
		foreach my $c (@{$classes}) {
			foreach my $forbid ( @{$policies{$pid}->{'forbids'}} ) {
				#print Dumper( $forbid );
				if ( $DEBUG ) {
					print "checking forbid " . $forbid->{'value'} . " : " . 
						$forbid->{'concept'} .  " against class ";
				 	print Dumper($c);
				}
				if ( (not defined $forbid->{'concept'}) || ($forbid->{'concept'} eq $concept) ){
					# if the class is a subclass of the forbidden class we remove it
					if ( $c =~ /^$forbid->{'value'}/ ){
						push @remove, $pid;
					}
				}

#TODO - finish up this code to use the array of hashrefs rather than old stupid $forbid$i business.
			}
		
			foreach my $permit ( @{$policies{$pid}->{'permits'}} ) {
				if ( $DEBUG ) {
					print "checking permit " . $permit->{'value'} .  " against class ";
					print Dumper($c);
				}
				if ( (not defined $permit->{'concept'}) || ($permit->{'concept'} eq $concept) ){
					#if permit is defined then we exclude all that are not included
					#in the permit directive
					# if a category is not permitted then add it to the remove array
						if ( "$c" !~ /^$permit->{'value'}/ ){
							print "removing $pid based on permit directive from $target\n" if ($DEBUG);
							push @remove, $pid;
						} else {
							$permitted{$pid} = 1;
							print "re-permitting $pid based on permit directive from $target\n" if ($DEBUG);
						}
				}
				
			}
		}
	}

	#now remove those pids that are forbidden and also not permitted 
	#if a pid is permitted it will always override the forbidden directive
	foreach my $lose (@remove){
		if (not defined $permitted{$lose}){
			print "*** forbidding $target to link to $lose" if ($DEBUG);
			delete $compare{$lose};
		} 
	}

	my @winners = ();

	my $topprio = 32768;
	foreach my $pid (sort { $compare{$a} <=> $compare{$b} } keys %compare) {
		if ($compare{$pid} <= $topprio) {
			push @winners, $pid;

			$topprio = $compare{$pid};
		} else {
			last;
		}
	}
	
	print "link policies took " . (time() - $start) . " seconds\n" if ($DEBUG);


	
	return @winners;	
}

# load a link policy (read from DB and parse it to a hash structure)
# sub by Aaron Krowne and James Gardner
sub loadpolicy {
	my $objectid = shift;

	my $sth = cachedPrepare("select linkpolicy from object where objectid = ?");
	$sth->execute($objectid);

	my $row = $sth->fetchrow_arrayref();
	$sth->finish();

#	print Dumper( $row );

	if (not defined $row) {
		return {};
	}
	
	my $policytext = $row->[0];

	my %policy;
#	my $numforbids = 0;
#	my $numpermits = 0;
	
	my @permits = ();
	my @forbids = ();
	
	foreach my $line (split(/\s*\n+\s*/,$policytext)) {
		# parse out priority
		#
		if ($line =~ /^\s*priority\s+(\d+)(?:\s+("[\w\d\s]+"|[\w\d]+))?/) {
			my $prio = $1;
			my $concept = $2;
			
			$policy{'priority'} = {value => $prio};
			$policy{'priority'}->{'concept'} = $concept if defined $concept;
		}

		# parse out the permit and forbid classification directives. - James Gardner

		if (   $line =~ /^\s*permit\s+(\S+)(?:\s+("[\w\d\s]+"|[\w\d]+))?/   ) {
			my $category = $1;
			my $concept = $2;
			$concept =~ s/"//g;
			
			my %temp = ();
			$temp{'value'} = $category;
			$temp{'concept'} = $concept if defined $concept;
			push @permits, \%temp;
		}

		if (   $line =~ /^\s*forbid\s+(\S+)(?:\s+("[\w*\s]+"|[\w\d]+))?/   ) {
			my $category = $1;
			my $concept = $2;
			$concept =~ s/"//g;
			
			my %temp = ();
			$temp{'value'} = $category;
			$temp{'concept'} = $concept if defined $concept;
			push @forbids, \%temp;
		}
		#tell the policy has the correct number of forbid and permit directives
		
		$policy{'forbids'} = \@forbids;
		$policy{'permits'} = \@permits;		
	}
#	print Dumper( \%policy );

	return {%policy};
}


1;
