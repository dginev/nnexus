#!/usr/bin/perl

#this script converts all the objects in the pm databases to the form that nnexus requires for linking


use strict;

use Time::HiRes qw ( time alarm sleep );

use Data::Dumper;
use XML::Writer;
use IO::Socket;
use IO::File;
use DBI;

#connect to the pm database
my $dbh = DBI->connect("DBI:". "mysql" .
						":" . "pm" .
						";host=". "localhost" ,
						"pm" , 
  						"groupschemes",
  						{ RaiseError => 0, PrintError  => 0 }
  						);


my @objects = ();

# get the attributes for each object from the planetmath.org database

my $sth = $dbh->prepare( "select uid, data from objects order by uid" ); 
$sth->execute();
while (my $row = $sth->fetchrow_hashref()) {
	push @objects , $row;
}

open (INPUT, "linkme.xml");

my @input = <INPUT>;

my $xmlstring = join( "", @input );

my $writer = new XML::Writer(OUTPUT => $output);

$writer->startTag('request');
foreach my $obj ( @objects ) {
	$writer->startTag('linkentry');
	$writer->startTag('objid');
	$writer->characters($obj->{'uid'});
	$writer->endTag('objid');
	$writer->startTag('domain');
	$writer->characters("planetmath.org");
	$writer->endTag('domain');
	$writer->startTag('body');
	$writer->characters($obj->{'data'});
	$writer->endTag('body');
	$writer->endTag('linkentry');
}
$writer->endTag('request');

$writer->end();
$output->close();
