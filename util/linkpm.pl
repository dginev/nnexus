use strict;

open( IN, $ARGV[0] );
my $domain = $ARGV[1];

while( my $line = <IN> ) {
	chomp($line);

	`2html $domain/$line`;
}

