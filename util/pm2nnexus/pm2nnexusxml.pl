#!/usr/bin/perl

use strict;
use DBI;
use Data::Dumper;
use XML::Writer;
use IO::File;

#
# This program dumps the db information into an xml file that is readable by nnexus.
#



#connect to the pm database
my $dbh = DBI->connect("DBI:". "mysql" .
			 ":" . "pm" .
			";host=". "localhost" ,
			"pm" , 
  			"groupschemes",
  			{ RaiseError => 0, PrintError  => 0 }
  			);


#connect to the nnexus database
my $dbnnexus = DBI->connect("DBI:". "mysql" .
			 ":" . "nnexus" .
			";host=". "localhost" ,
			"nnexus" , 
  			"nnexus",
  			{ RaiseError => 0, PrintError  => 0 }
  			);

my $domain = "planetmath";
my $sth = $dbnnexus->prepare("select domainid from domain where name=?");
$sth->execute($domain);
my $row = $sth->fetchrow_hashref();
my $domainid = $row->{'domainid'};

my @objects = ();

my $nsth = $dbnnexus->prepare( "select modified from object where identifier = ? and domainid = ?");

# get the attributes for each object from the planetmath.org database

my $sth = $dbh->prepare( "select uid, userid, title, data, name, related, synonyms, defines, linkpolicy, modified from objects order by uid" ); 
$sth->execute();
while (my $row = $sth->fetchrow_hashref()) {
	my @classes = ();
	my %object = ();
	my $addtonnexus = 1;

	$nsth->execute($row->{'uid'}, $domainid );
	if ( my $nrow = $nsth->fetchrow_hashref() ) {
		print "checking $row->{uid}, $domainid, $row->{modified} > $nrow->{modified}\n";
		if ( $row->{'modified'} > $nrow->{'modified'} ) {
		print "object $row->{uid} $row->{modified} > $nrow->{modified} has changed so updating\n";
		my $modified = $nrow->{'modified'};
		$addtonnexus = 1;
		}
	} else {
		#didn't find object in NNexus so add it.
		$addtonnexus = 1;
	}

	# get the classification information for the object;
	
	my $osth = $dbh->prepare( "select ns, msc.id as class from classification, msc where msc.uid = classification.catid and objectid = ?" );
	$osth->execute( $row->{'uid'} );
	while (my $row0 = $osth->fetchrow_hashref() ) {
		my $temp = $row0->{'ns'} . ":" . $row0->{'class'};
		push @classes, $temp;
		
	}
	
	 
	my @def = split(/,/ , $row->{'defines'});
	my @syn = split( /,/ , $row->{'synonyms'});
	
	# we need to strip whitespace from the defines and synonyms
	foreach my $d ( @def ) { $d =~ s/^\s+//; $d =~ s/\s+$//; }
	foreach my $s (@syn) { $s =~ s/^\s+//; $s =~ s/\s+$//; }
	
	$object{'defines'} = \@def;
	$object{'synonyms'} = \@syn;
	$object{'attributes'} = $row;
	$object{'classes'} = \@classes;
	
	push @objects , \%object if ($addtonnexus);
}

#the has looks something like this
#$VAR669 = {
#            'classes' => [
#                           'msc:53A04'
#                         ],
#            'defines' => [
#                           'point of inflection',
#                           ' arclength parameterization',
#                           ' reparameterization'
#                         ],
#            'synonyms' => [
#                            'oriented space curve',
#                            ' parameterized space curve'
#                          ],
#            'attributes' => {
#                              'linkpolicy' => undef,
#                              'defines' => 'point of inflection, arclength parameterization, reparameterization',
#                              'related' => 'Torsion, CurvatureOfACurve, MovingFrame, SerretFrenetFormulas',
#                              'uid' => '1633',
#                              'synonyms' => 'oriented space curve, parameterized space curve',
#                              'userid' => '146',
#                              'name' => 'SpaceCurve',
#                              'title' => 'space curve'
#                            }
#          };
#
#
# the xml needs to look like this
#<entry>
#<title>same as above</title>
#<defines>thing</defines>
#<defines>widget</defines>
#<synonym>term3</synonym> 
#<synonym>phrase of terms</synonym>
#<domain>planetmath.org</domain>
#<body>The body text</body>
#<objid>a3db</objid>
#<linkpolicy>permit 03A</linkpolicy>
#<author>1</author>
#<class>012A</class>
#<class>02ADD</class>
#</entry>

 my $output = new IO::File(">pmout.xml");

  my $writer = new XML::Writer(OUTPUT => $output);


$writer->startTag('addobject');
$writer->startTag("batchmode");
$writer->characters("1");
$writer->endTag("batchmode");
foreach my $obj (@objects) {
	$writer->startTag('entry');
	
	$writer->startTag('title');
	$writer->characters($obj->{'attributes'}->{'title'});
	$writer->endTag('title');
	
	$writer->startTag('domain');
	$writer->characters($domain);
	$writer->endTag('domain');
	
	$writer->startTag('body');
	$writer->characters($obj->{'attributes'}->{'data'});
	$writer->endTag('body');
	
	$writer->startTag('objid');
	$writer->characters($obj->{'attributes'}->{'uid'});
	$writer->endTag('objid');
	
	$writer->startTag('author');
	$writer->characters($obj->{'attributes'}->{'userid'});
	$writer->endTag('author');
	
	$writer->startTag('linkpolicy');
	$writer->characters($obj->{'attributes'}->{'linkpolicy'});
	$writer->endTag('linkpolicy');
	
	foreach my $cl ( @{$obj->{'classes'}} ){
		$writer->startTag('class');
		$writer->characters($cl);
		$writer->endTag('class');
	}
	
	$writer->startTag('defines');
	$writer->startTag('synonym');
	$writer->characters($obj->{'attributes'}->{'title'});
	$writer->endTag('synonym');
	foreach my $syn ( @{$obj->{'synonyms'}} ){
		$writer->startTag('synonym');
		$writer->characters($syn);
		$writer->endTag('synonym');
	}
	foreach my $def ( @{$obj->{'defines'}} ){
		$writer->startTag('synonym');
		$writer->characters($def);
		$writer->endTag('synonym');
	}
	$writer->endTag('defines');
	
	$writer->endTag('entry');

}

$writer->endTag('addobject');
$writer->end();

