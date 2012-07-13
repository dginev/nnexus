
use strict;

open ( IN, $ARGV[0] );


my @files = <IN>;
my $numToSelect = $ARGV[1];


srand( time );

for ( my $i = 0; $i < $numToSelect; $i++ ) {
	my $val = rand(1) * @files;

	my $element = splice( @files, $val, 1 );
	chomp($element);
	$element =~ s/\.tex$//;
	print "http://mini.endofinternet.org/planetmath/$element/$element-linked.html\n";
}
