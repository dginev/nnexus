use strict;
use LWP::Simple;
use Data::Dumper;
use XML::Writer;
use Net::OAI::Harvester;

## create a harvester for the Library of Congress
my $baseURL = $ARGV[0];
my $metaDataPrefix = $ARGV[1];
my $set = $ARGV[2];
if ( $metaDataPrefix eq "" ) {
	$metaDataPrefix="oai_dc";
}

my $domain = $set;
if ( $set eq "MathResources Inc." ) {
	$domain = "MathResources";
}

my $harvester = Net::OAI::Harvester->new( 
		'baseURL' => $baseURL
		);

## list all the records in a repository
my $records = $harvester->listAllRecords( 
		'metadataPrefix'    => $metaDataPrefix,
		'set' => $set
		);

my $writer = new XML::Writer();
$writer->startTag("addentry");
$writer->startTag("batchmode");
$writer->characters("1");
$writer->endTag("batchmode");

my $count = 0;
while ( my $record = $records->next() ) {
	$count++;
	my $header = $record->header();
	my $metadata = $record->metadata();
#	print STDERR $metadata->datestamp() . "\n";
#print STDERR Dumper($metadata);
	$writer->startTag('entry');
	$writer->startTag('domain');
	$writer->characters($domain);
	$writer->endTag('domain');
	$writer->startTag('objid');
	$writer->characters($header->identifier());
	$writer->endTag('objid');
	$writer->startTag('title');
	my $title = $metadata->title();
	if ( $domain eq "MathWorld" ) {
		$title =~ s/\s+--\s+from\s+MathWorld$//;
	} elsif ( $domain eq "MathResources" ) {
		$title =~ s/^Definition:\s+//;
	}
	$writer->characters($title);
	$writer->endTag('title');
	$writer->startTag('defines');
	$writer->startTag('synonym');
	$writer->characters($title);
	$writer->endTag('synonym');
	$writer->endTag('defines');
#	print "title: ", $metadata->title(), "\n";
	my @subjects = $metadata->subject;
	foreach my $s ( @subjects ) {
		$writer->startTag('class');
		if ( $domain eq "MathWorld" ) {
			if ( $s =~ /^\d/ ) {
				$s = "msc:" . $s;
			}
		}
		$writer->characters($s);
		$writer->endTag('class');
	}
#print Dumper( \@subjects );
	$writer->endTag('entry');
	$writer->characters("\n");
#	print "subject: " . join( ", ", @{$metadata->subject} );
}

$writer->endTag("addentry");
$writer->end();

print STDERR "THERE WERE $count entries\n";


