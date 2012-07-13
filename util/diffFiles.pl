use strict;

use Data::Dumper;

open( IN, $ARGV[0] );
my @files = <IN>;


my @difffiles = ();
foreach my $f ( @files ) {
	my ($num, $link) = split( /\s/, $f);
	
	chomp( $link );
	$link =~ /.*\/(planetmath.*)/;
	my $filepath = $1;
	my $disambig = $filepath;
	$disambig =~ s/-policies//;
	
	print "comparing $filepath to $disambig\n";
	my $diff =  `diff $filepath $disambig`;
	print $diff;
	if ( $diff ne "" ) {
		push @difffiles, $filepath;	
	}
}

print join( "\n", @difffiles );
