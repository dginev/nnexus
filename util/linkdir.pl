use strict;

open( IN, $ARGV[0] );
my $domain = $ARGV[1];

while( my $line = <IN> ) {
	chomp($line);

	$line =~ s/\.tex$//;

	print `perl html2nnexus.pl $domain/$line/$line.html $domain/$line/$line-linked-policies.html`;
}

