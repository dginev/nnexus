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
use Encode;
#use Data::Dumper;

use NNexus::NNexusSAXHandler;
use NNexus::Classification;
use NNexus::Crossref;
use NNexus::Concepts;
use NNexus::Object;
use NNexus::Domain;
use NNexus::Object;
use NNexus::Indexing;

use vars qw($config $dbh $socket);

my $response = "";
my $writer = new XML::Writer(OUTPUT => \$response, NEWLINES=>1,UNSAFE => 1);

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
		} if ($start){ 
			$input .= $line;
		}
	}

#	$input = encode("utf8", $input);
	

#$input =~ s/([^[:ascii:]]|[\x00-\x09\x0B\x0C\x0E-\x1F])/?/g;
#print "INPUT is $input\n";
	
#i believe this writer part may be taking up too much memory
	my $start = time();
	$writer->startTag('response');
        $input = decode("utf8", $input);
	my $doc = $parser->parse_string( $input );
	print "DONE Parsing socket\n";
#	$writer->characters($response);	
	$writer->endTag('response');
	$writer->end();
#my $octets = encode( "utf8", $response );
#	print $socket "$octets";
#	print "BEFORE: $response\n";
	my $sendme = encode( "utf8", $response );
#	print "SENDING $sendme\n";
	print $socket $sendme;
	close ($socket);
	print "*** Took " . (time()-$start) . " seconds to fulfill all request\n";
}

sub add_entry {
	my $args = shift;
	
	my $objid;

#	my $start = time();
#print Dumper( $args );
	
#
# get the correct domainid from the db
#
	my $domid = getdomainid( $args->{'domain'} );  
		
#
# add the new object if it doesn't already exist.	
#
	my $author = $args->{'author'};
	my $objid = getobjectid( $args->{'objid'}, $domid );

	my $batchmode = $args->{'batchmode'};

	
	if ( $objid == -1 ){
		
		#TODO - fix the author stuff. for now we aren't even using this anyway
		my $authorid = 0;
#		my $authorid = getauthorid( $author, $domid );
#		if ( $authorid == -1  ){
#			addauthor( $author, $domid );
#			$authorid = getauthorid( $author, $domid );
#		}
		addobject( $args->{'objid'}, $args->{'title'}, $args->{'body'}, $domid, $authorid, $args->{'linkpolicy'}, $args->{'synonyms'} ,$args->{'classes'}, $batchmode );

	} else {
#
# The object already exists
#	
		
		print "object $objid already exists and is being updated\n";
		
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
		updateobject($objid, $args->{'title'}, $args->{'body'}, $domid, $authorid, $args->{'linkpolicy'}, $args->{'synonyms'}, $args->{'classes'}, $batchmode );
	}

#	my $end = time();
#	my $total = $end-$start;
#	print "Took $total to get here\n";
    
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
	my $body="";
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
		} 
		else {
			print "no body sent for object $objid";
			# $body = $object->{'body'};
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

	my $nolink = $args->{'nolink'};
	push @$syns, split( /'\s*,\s*'/, $nolink);
#	print "***********************************not linking " . @$syns;

	print "BODY BEFORE: $body\n";
	my $linkedbody = "";
	my $links = [];
	if ($body ne "") {
		($linkedbody, $links) = crossReference(
						$format,
						$args->{'domain'},
						$body, 
						$syns,
						$objid,
						$classes,
						$detail
					);
	} 
	print "BODY LINKED: $linkedbody\n";
	if ( $objid != -1 ) {
		validateobject($objid);	# set the object link stuff to valid
	}

	my $numlinks = $#{$links} + 1;
	my $end = time();
	my $total = $end - $start;
	print "linked\t$objid\t$numlinks\t$total sec\t$title\n";

#	print "LINKED BODY = $linkedbody\n";
	my $links = join(', ', @{$links});
	print "links= $links";
		
	$writer->startTag('body');
	$writer->raw("$linkedbody");
	$writer->endTag('body');
	$writer->startTag('links');
	$writer->characters(encode_utf8($links));
	$writer->endTag('links');
			
	$writer->endTag('linked');
}

sub delete_entry {
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

sub get_concepts {
	my $args = shift;
	my $concepts = getallconcepts();
	print Dumper( $concepts );	
# 	'identifier' => '10',
#       'nickname' => 'PlanetMath',
#       'concept' => 'Jordan\'s totient function',
#       'objectid' => '1'

	foreach my $c (@{$concepts}) {
		$writer->startTag('concept_info');
		foreach my $k ( keys %{$c} ) {
			$writer->startTag($k);
			$writer->characters($c->{$k});
			$writer->endTag($k);
		}
		$writer->endTag('concept_info');
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
sub check_valid {
    my $args = shift;
    my $domid = getdomainid( $args->{'domain'} );

	my $objid = getobjectid( $args->{'objid'}, $domid );

	my $valid = is_valid( $objid );
	$writer->startTag('valid');
	$writer->characters($valid);
	$writer->endTag('valid');
}

sub index_entries {
	my $args = shift;
	invalIndexAllEntries();
}

1;
