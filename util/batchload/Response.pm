# This file contains the functions that the NNexusSAXHandler calls to get the server to do work.
# most of the functions contained in this file massage the data into another form to pass into the
# the lower level object manipulation functions.
# - James Gardner


package NNexus;

use strict;

use Switch;
use DBI;
use XML::Writer;
use XML::SAX;
use Time::HiRes qw ( time alarm sleep );
#use Data::Dumper;

use NNexus::NNexusSAXHandler;
use NNexus::Classification;
use NNexus::Crossref;
use NNexus::Concepts;
use NNexus::Object;
use NNexus::Domain;



use vars qw($config $dbh $socket);

my $response = "";
my $writer = new XML::Writer(OUTPUT => \$response);

my %invalid = ();


sub socket_handler {
	$socket = shift;

	my $parser = XML::SAX::ParserFactory->parser(
        Handler => NNexusSAXHandler->new
  	);

 	my $start = 0; 
  	my $input = "";
	#parse this baby using SAX;
	#see the NNexusSAXHandler code to view what we do.
	
  
	while ( my $line = <$socket> ) {  
		if ($line eq "<request>\n") {
			$input = "";
			$start = 1;	
		} elsif ( $line eq "</request>\n" ) {
			$input .= $line;
			$start = 0;
			last;			
		}
		if ($start){
			$input .= $line;
		}
	}

	#print "INPUT is $input\n";
	
#i believe this writer part may be taking up too much memory
	my $start = time();
	$writer->startTag('response');
	my $doc = $parser->parse_string( $input );
	#my $doc = $parser->parse_file( $socket );
	print "DONE Parsing socket\n";
	$writer->startTag('invalid');
	foreach my $k (keys %invalid) {
		$writer->characters($k . ", ");		
	}
	$writer->endTag('invalid');
#	$writer->characters($response);	
	$writer->endTag('response');
	$writer->end();
	print $socket $response;
	close ($socket);
	print "*** Took " . (time()-$start) . " seconds to fulfill all request\n";
}

sub delete_entry {
	my $args = shift;
	
	my $domid = getdomainid( $args->{'domain'} );  #get the domainid
	my $objid = getobjectid( $args->{'objid'}, $domid); #get the internal objectid for nnexus based on externalid
	
	deleteobject( $objid );

}

sub add_entry{
	my $args = shift;
	
	my $objid;
	
#
# get the correct domainid from the db
#
	my $domid = getdomainid( $args->{'domain'} );  
		
#
# add the new object if it doesn't already exist.	
#
	my $author = $args->{'author'};
	my $objid = getobjectid( $args->{'objid'}, $domid );
	
	if ( $objid == -1 ){
		
		#TODO - fix the author stuff. for now we aren't even using this anyway
		my $authorid = 0;
#		my $authorid = getauthorid( $author, $domid );
#		if ( $authorid == -1  ){
#			addauthor( $author, $domid );
#			$authorid = getauthorid( $author, $domid );
#		}
		addobject( $args->{'objid'}, $args->{'title'}, $args->{'body'}, $domid, $authorid, $args->{'linkpolicy'}, $args->{'synonyms'} ,$args->{'classes'} );

		#skip the invalidation stuff;
		return;
		
		my @invalid = getinvalidobjectsfordomain($domid); #this returns hashrefs of form objectid, identifier
		#todo - generalize this for all domains.
		foreach my $i (@invalid) {
			$invalid{$i->{'identifier'}} = 1;
		}

		
	} else {
#
# The object already exists
#	
		
		#if ( $domid == 2 ) {
		#	print "object $objid already exists and is being skipped\n";
		#} else {
	
		print "object $objid already exists and is being updated\n";
#		print "it is actually being skipped because we are loading a big db\n";
#		return;
#		print "classes: " . Dumper($args->{'classes'});
		
		#
		#objid is valid and we need to do an update if necessary
		#

		#TODO - fix the author stuff.
		my $authorid = 0;
#		my $authorid = getauthorid( $author, $domid );
#		if ( $authorid == -1  ){
#			addauthor( $author, $domid );
#			$authorid = getauthorid( $author, $domid );
#		}
#		
		updateobject($objid, $args->{'title'}, $args->{'body'}, $domid, $authorid, $args->{'linkpolicy'}, $args->{'synonyms'}, $args->{'classes'} );

		#skip the invalidation stuff becaues it does't really work at this point and
		# we want some speed for debugging
		return;

		my @invalid = getinvalidobjectsfordomain($domid); #this returns hashrefs of form objectid, identifier
		#todo - generalize this for all domains.
		foreach my $i (@invalid) {
			$invalid{$i->{'identifier'}} = 1;
		}
		#foreach my $i (@invalid) {
		#	$writer->startTag('invalid');
		#	$writer->characters($i->{'identifier'});		
		#	$writer->endTag('invalid');
		#}
		#}	

		
	}
    
}

sub link_entry {
	my $args = shift;

#	print Dumper( $args );
	# all we need is the externalid, domain, and body of the document to figure out the linking.
	#  if the entry needing to be link is not yet in the db we need to call add_entry.
	
	my $domid = getdomainid( $args->{'domain'} ); 
	my $objid = getobjectid( $args->{'objid'} ,$domid);
	my $format = 'l2h'; #the default format is l2h will eventually be html most likely
				# or we could autodetect
	my $detail = 0; # the default detail level is 0
		# 0 - return back fully linked html
		# 1 - return back the matches hash in XML format.
	$format = $args->{'format'} if defined ( $args->{'format'} );
	$detail = $args->{'mode'} if ( defined ( $args->{'mode'} ) ); 

	print "Linking object $objid of domain $args->{'domain'} with format = $format and " .
			"detail = $detail\n";

	$writer->startTag('linked');

	#build the data structures necessary to call crossReference
	my $start = time();
	my $body;
	my $syns;
	my $classes;
	my $title;
		
	if ($objid != -1) { #object is in the database
		my $object = getobjecthash( $objid );
		$title = $object->{'title'};
		#get the concepts as a an array this object defines.
		$syns = getconcepts( $objid );
		my $class;
		($class ,$classes) = classinfo( $objid );		
		if (defined $args->{'body'} ){
			$body = $args->{'body'};
		} else {
			$body = $object->{'body'};
		}
		push @$syns, $title;
	} else { #object is not in the database
		print "linking an arbitrary object\n";
		if (defined $args->{'title'}){
			$title = $args->{'title'};
		}
		$syns = $args->{'synonyms'};
		push @$syns, $title;
		if (defined $args->{'body'} ){
			$body = $args->{'body'};
		} else {
			print "There is no body so the linking is pointless\n";
		}

		#TODO - make sure the class info passed is of form scheme:identifier 
		my @c = ();
		my $passedclasses = $args->{'classes'};
		#print Dumper( $classes );
		foreach my $class ( @$passedclasses ) {
			push @c, convertStringToClassHash( $class, $args->{'domain'} );
		}
		$classes = \@c;
	}

	my ($linkedbody, $links) = crossReference(
						$format,
						$args->{'domain'},
						$body, 
						$syns,
						$objid,
						$classes,
						$detail
					);
	if ( $objid != -1 ) {
		validateobject($objid);	# set the object link stuff to valid
	}

	my $numlinks = $#{$links} + 1;
	my $end = time();
	my $total = $end - $start;
	print "linked\t$objid\t$numlinks\t$total sec\t$title\n";
		
	$writer->startTag('body');
	$writer->characters("$linkedbody");
	$writer->endTag('body');
	$writer->startTag('links');
	$writer->characters(join(' ,',@{$links}));
	$writer->endTag('links');
			
	$writer->endTag('linked');
}

sub delete_entry{
	my $args = shift;
	my $extid = $args->{'objid'};

	print "deleting entry $extid";
	my $domid = getdomainid( $args->{'domain'} );  
	my $objid = getobjectid( $args->{'objid'}, $domid );
	deleteobject($objid);
	my @invobjects = getinvalidobjects();
		
	foreach my $inv (@invobjects){
		#check to see that the invalid object is of the same domain
		#todo - generalize this so planetmath can link to other domains.
		if ( $inv->{'domainid'} == $domid ) {
			$writer->startTag('invalid');
			$writer->characters($inv->{'identifier'});
			$writer->endTag('invalid');
		}
	}


}

sub get_invalid {
	my $args = shift;
	my $domid = getdomainid( $args->{'domain'} );  

	print "returning invalid";
	my @invobjects = getinvalidobjects();
		
	foreach my $inv (@invobjects){
		#check to see that the invalid object is of the same domain
		#todo - generalize this so planetmath can link to other domains.
		if ( $inv->{'domainid'} == $domid ) {
			$writer->startTag('invalid');
			$writer->characters($inv->{'identifier'});
			$writer->endTag('invalid');
		}
	}

}

1;
