use strict;
my @sizes = ( 100, 200, 500, 1000, 2000, 3000, 4000, 5000, 6000, 7132 );

foreach my $s ( @sizes ) {
	print `mysql -u nnexus --password=nnexus planetmath < planetmath.sql`;
	print `perl createRandomSubset.pl $s`;
	print `perl linkAll.pl $s`;
	print `perl countLinks.pl $s`;

}

