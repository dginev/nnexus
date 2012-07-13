use strict;

use Data::Dumper;

my $domain = $ARGV[0];


my $head = "<head><title>Auto-Linked PlanetMath Collection with Disambiguation and Link Policies</title></head>";
my $body = "<body>";

my $files = `ls $domain`;

my @list = split( /\n/, $files );

foreach my $line ( @list ) {
	if ( -d "$domain/$line" ) {
		my $name = $line;
		$body .= "<a href=\"$name/$name-linked-policies.html\">$name</a><br/>\n";
	}
}

$body .= "</body>";

print "$body";
