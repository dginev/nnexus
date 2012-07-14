package NNexus::API;
use NNexus::Domain qw(getdomainid);
use NNexus::Object qw(getobjectid getobjecthash);
use NNexus::Crossref qw(crossReference);

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(link_entry);

sub link_entry {
	my ($args) = @_;
	my $config = $args->{config};
	my $db=$config->get_DB;
#	print Dumper( $args );
	# all we need is the externalid, domain, and body of the document to figure out the linking.
	#  if the entry needing to be link is not yet in the db we need to call add_entry.
	
	my $domid = getdomainid( $db, $args->{'domain'} ); 
	my $objid = getobjectid( $db, $args->{'objid'} ,$domid);
	my $format = 'l2h'; #the default format is l2h will eventually be html most likely
				# or we could autodetect
	my $detail = 0; # the default detail level is 0
		# 0 - return back fully linked html
		# 1 - return back the matches hash in XML format.
	$format = $args->{'format'} if defined ( $args->{'format'} );
	$detail = $args->{'mode'} if ( defined ( $args->{'mode'} ) ); 

	print "Linking object $objid of domain $args->{'domain'} with format = $format and " .
			"detail = $detail\n";

	my $writer= '<linked>';

	#build the data structures necessary to call crossReference
	my $start = time();
	my $body="";
	my $syns;
	my $classes;
	my $title;
		
	if ($objid != -1) { #object is in the database
		my $object = getobjecthash($db, $objid );
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
						$config,
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
	# DG: TODO, refactor away from Writer
	#     try to work consistently with a complete HTML5/XHTML document
	#$writer->startTag('body');
	#$writer->raw("$linkedbody");
	#$writer->endTag('body');
	#$writer->startTag('links');
	#$writer->characters(encode_utf8($links));
	#$writer->endTag('links');
			
	#$writer->endTag('linked');
	$writer.=$linkedbody.'</linked>';
	$writer;
}

1;
