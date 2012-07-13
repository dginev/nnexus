
use strict;

my %hash = ();

while ( my $line = <STDIN> ) {
	
	chomp($line);

	$line =~ /use\s+(.*)/;
	my $mod = $1;

	$hash{$mod} = 1;
}

foreach my $k ( sort keys %hash ) {
	if ( $k !~ /\s/ && $k !~ /nnexus/i && $k !~ /strict/ ) {
		print $k . "\n";
	}
}
