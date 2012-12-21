# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Job Request Module                                                  | #
# |=====================================================================| #
# | Part of the Planetary project: http://trac.mathweb.org/planetary    | #
# |  Research software, produced as part of work done by:               | #
# |  the KWARC group at Jacobs University                               | #
# | Copyright (c) 2012                                                  | #
# | Released under the GNU Public License                               | #
# |---------------------------------------------------------------------| #
# | Adapted from the original NNexus code by                            | #
# |                                  James Gardner and Aaron Krowne     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev <d.ginev@jacobs-university.de>                  #_#     | #
# | http://kwarc.info/people/dginev                            (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package NNexus::Job;
use strict;
use warnings;
use feature qw(say switch);

use NNexus::Domain qw(get_domain_id);
use NNexus::EncyclopediaEntry qw(get_object_id get_object_hash);
use NNexus::Crossref qw(crossReference);

sub new {
  my ($class,%opts) = @_;
  $opts{format} = lc($opts{format});
  $opts{result} = {};
  bless \%opts, $class;
}

sub execute {
  my ($self) = @_;
  given ($self->{function}) {
    when('linkentry') {$self->_link_entry;}
    when('addobject') {$self->_add_object;}
    when('updateobject') {$self->_update_object;}
    when('deleteobject') {$self->_delete_object;}
    when('updatelinkpolicy') {$self->_update_link_policy;}
    when('checkvalid') {$self->_check_valid;}
    default {$self->_fail_with("Invalid action, aborting!"); }
  }
}

sub _fail_with {
  my ($self,$message)=@_;
  # TODO: Spec this out, maybe similar to LaTeXML?
  my $result = {payload=>q{},message=>$message,status=>'Failed!'};
  $self->{result} = $result;
}
sub response {
  my $response = $_[0]->{result};
  {result=>$response->{payload},message=>$response->{message},status=>$response->{status}};
}

sub _link_entry {
  my ($self) = @_;
  my $config = $self->{config};
  my $db=$config->get_DB;
  my $body = $self->{body};
  my $format = $self->{format}||'html'; # default is html, l2h is broken
  my $domain = $self->{domain};
  # 0 - return back fully linked html
  # 1 - return back the matches hash in XML format.
  my $mode = $self->{'mode'} || 0; # the default detail level is 0

  # all we need is the externalid, domain, and body of the document to figure out the linking.
  #  if the entry needing to be link is not yet in the db we need to call add_entry.

  my $domid = get_domain_id( $db, $self->{'domain'} ); 
  my $objid = get_object_id( $db, $self->{'objid'} ,$domid);

  print "Linking object $objid of domain $domain with format = $format and " .
    "detail = $mode\n";

  #build the data structures necessary to call crossReference
  my $start = time();
  my $syns;
  my $classes;
  my $title;
		
  if ($objid != -1) {		#object is in the database
    my $object = get_object_hash($db, $objid );
    $title = $object->{'title'};
    #get the concepts as a an array this object defines.
    $syns = getconcepts( $objid );
    my $class;
    ($class ,$classes) = classinfo( $objid );		
    print STDERR "no body sent for object $objid" unless defined $body;
    push @$syns, $title;
  } else {			#object is not in the database
    print STDERR "linking an arbitrary object\n";
    if (defined $self->{'title'}) {
      $title = $self->{'title'};
    }
    $syns = $self->{'synonyms'};
    push @$syns, $title;
    print STDERR "There is no body so the linking is pointless\n" unless defined $body;

    #TODO - make sure the class info passed is of form scheme:identifier 
    my @c = ();
    my $passedclasses = $self->{'classes'};
    #print Dumper( $classes );
    foreach my $class ( @$passedclasses ) {
      push @c, convertStringToClassHash( $class, $domain );
    }
    $classes = \@c;
  }

  my $nolink = $self->{'nolink'};
  push @$syns, split( /'\s*,\s*'/, $nolink) if defined $nolink;
  #	print "***********************************not linking " . @$syns;

  #print "BODY BEFORE: $body\n";
  my $linkedbody = "";
  my $links = [];
  if ($body ne "") {
    ($linkedbody, $links) = crossReference(config=>$config,
					   format=>$format,
					   domain=>$domain,
					   text=>$body,
					   nolink=>$syns,
					   fromid=>$objid,
					   class=>$classes,
					   detail=>$mode
					  );
  } 
  #print STDERR "BODY LINKED: $linkedbody\n";
  if ( $objid != -1 ) {
    validateobject($objid);	# set the object link stuff to valid
  }

  my $numlinks = $#{$links} + 1;
  my $end = time();
  my $total = $end - $start;
  print STDERR "Created $numlinks links.\n";
  #print STDERR "linked\t$objid\t$numlinks\t$total sec\t$title\n";
  #print STDERR "links=",join(', ', @{$links});

  $self->{result}={payload=>$linkedbody,message=>'No obvious problems.', status=>'OK'};
  $linkedbody;
}

sub _add_object { $_[0]->_fail_with('Not supported yet!');}
sub _update_object { $_[0]->_fail_with('Not supported yet!');}
sub _delete_object { $_[0]->_fail_with('Not supported yet!');}
sub _update_link_policy { $_[0]->_fail_with('Not supported yet!');}
sub _check_valid { $_[0]->_fail_with('Not supported yet!');}


1;

__END__

=pod 

=head1 NAME

C<NNexus::Job> - Class for Servicing Job Request to NNexus

=head1 SYNOPSIS

    use NNexus::Job;
    my $job = NNexus::Job->new(config=>$config,body=>$body,format=>$format,function=>$function,
   			       domain=>$domain);
    $job->execute;
    my $result = $job->result;
    my $message = $job->message;
    my $status = $job->status;

=head1 DESCRIPTION

This class serves as an encapsulation for users' NNexus requests, driven by a minimal API.

=head2 METHODS

=over 4

=item C<< my $job = NNexus::Job->new(%options); >>

Creates a new job object, customized via an options hash. Admissible options are:
  - body: The textual payload to be autolinked/indexed/etc.
  - format: The format of the given body. Supported: tex|html
  - function: Operation to be performed. 
      * linkentry: Autolinks a given body returning a result in the same format
      * TODO: Add more
  - domain: Domain to use as the reference knowledge base for autolinking/indexing
  - config: An initialized NNexus::Config object (typically internal)

=item C<< $job->execute; >>

Executes the job prepared by the new method.

=item C<< $job->response; >>

Retrieves the job result. Returns a hash ref with three fields:
 result: the job result (e.g. a payload for a linking job)
 message: a human-readable description of the job
 status: a machine-readable status report

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the GNU Public License

=cut
