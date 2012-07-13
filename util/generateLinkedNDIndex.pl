use strict;

use Data::Dumper;

my $domain = $ARGV[0];


my $head = "<head><title>Auto-Linked PlanetMath Collection without Disambiguation</title></head>";
my $body = "<body>";

my $files = `ls $domain`;

my @list = split( /\n/, $files );

foreach my $line ( @list ) {
	if ( -d "$domain/$line" ) {
		my $name = $line;
		$body .= "<a href=\"$name/$name-linked-nodisambig.html\">$name</a><br/>\n";
	}
}

$body .= "</body>";

print "$body";
