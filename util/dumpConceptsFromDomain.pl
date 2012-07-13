#!/usr/bin/perl
#

#this program dumps the concept information for the specified domain.

use strict;

use DBI;
use Data::Dumper;
use XML::Writer;


my $domain = $ARGV[0];
my $dbname = $ARGV[1];
my $username = $ARGV[2];
my $pass = $ARGV[3];

my $dbh = DBI->connect("DBI:mysql" .
                         ":" . $dbname .
                       ";host=localhost",
                          $username,
                            $pass,
                       { RaiseError => 0, PrintError  => 0, AutoCommit => 1}
                     );

my $sql = "SELECT concept, domain.name, urltemplate, identifier, title, object.objectid from concepthash, domain, object where object.domainid=domain.domainid and object.objectid = concepthash.objectid and domain.name = ?";

my $sth = $dbh->prepare("$sql");

$sth->execute( $domain );

my $writer = new XML::Writer();
$writer->startTag('concepts');
while ( my $row = $sth->fetchrow_hashref() ) {
	$writer->startTag('conceptmap');
	#$VAR1 = {
	#          'identifier' => '4071',
	#                    'name' => 'planetmath.org',
	#                              'title' => 'transversality',
	#                                        'objectid' => '2160',
	#                                                  'concept' => 'transversally',
	#                                                            'urltemplate' => 'http://planetmath.org/?op=getobj&from=objects&id='
	#
	foreach my $k ( keys %{$row} ) {
		$writer->startTag($k);
		$writer->characters($row->{$k});
		$writer->endTag($k);
	}
	$writer->startTag('url');
	$writer->characters($row->{'urltemplate'} . $row->{'identifier'});
	$writer->endTag('url');

	$writer->endTag('conceptmap');
	#print Dumper( $row );
}
$writer->endTag('concepts');


