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

use NNexus::Discover qw(mine_candidates);
use NNexus::Annotate qw(serialize_candidates);

sub new {
  my ($class,%opts) = @_;
  $opts{format} = lc($opts{format}||'html');
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
    when('index') {$self->_index;}
    default {$self->_fail_with("Invalid action, aborting!"); }
  }
}

sub _fail_with {
  my ($self,$message)=@_;
  # TODO: Spec this out, maybe similar to LaTeXML?
  my $result = {payload=>q{},message=>$message,status=>'Failed!'};
  $self->{result} = $result;
}
sub _ok_with {
  my ($self,$payload,$message)=@_;
  # TODO: Spec this out, maybe similar to LaTeXML?
  my $result = {payload=>$payload,message=>$message,status=>'OK'};
  $self->{result} = $result;
}
sub response { $_[0]->{result};}

sub _link_entry {
  my ($self) = @_;
  # Process in 2 Steps:
  # I. Concept Discovery
  my ($concept_locations,$optional_serialized) =
    NNexus::Discover::mine_candidates(config=>$self->{config},
     body=>$self->{body}, url=>$self->{url},domain=>$self->{domain},
     format=>$self->{format});
  # II. Annotation
  $self->{annotation} //= 'links';
  my $serialized_result = 
    NNexus::Annotate::serialize_candidates(annotation=>$self->{annotation},
					   serialized=>$optional_serialized);
  $self->{result}={payload=>$serialized_result,message=>'No obvious problems.', status=>'OK'};
  $serialized_result;
}

sub _add_object { $_[0]->_fail_with('Not supported yet!');}
sub _update_object { $_[0]->_fail_with('Not supported yet!');}
sub _delete_object { $_[0]->_fail_with('Not supported yet!');}
sub _update_link_policy { $_[0]->_fail_with('Not supported yet!');}
sub _check_valid { $_[0]->_fail_with('Not supported yet!');}
sub _index {
  my ($self)=@_;
  my $domain = $self->{domain} || 'planetmath';
  my $url = $self->{url}||$self->{body};
  my $dom = $self->{dom};
  require NNexus::Index::Dispatcher;
  my $dispatcher = NNexus::Index::Dispatcher->new(db=>$self->{db},domain=>$domain);
  my @invalidation_suggestions;
  my $payload = $dispatcher->index_step(start=>$url,dom=>$dom);
  push @invalidation_suggestions, @{$payload};
  while ($payload = $dispatcher->index_step ) {
    push @invalidation_suggestions, @{$payload};
  }
  $self->_ok_with(\@invalidation_suggestions,"IndexConcepts succeeded in domain $domain, on: ".($url||'domain_root'));
}

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
