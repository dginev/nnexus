# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Job Request Module                                                  | #
# |=====================================================================| #
# | Part of the Planetary project: http://trac.mathweb.org/planetary    | #
# |  Research software, produced as part of work done by:               | #
# |  the KWARC group at Jacobs University                               | #
# | Copyright (c) 2012                                                  | #
# | Released under the MIT License (MIT)                                | #
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

use Mojo::DOM;
use NNexus::Discover qw(mine_candidates);
use NNexus::Annotate qw(serialize_concepts);
use NNexus::Classification qw(disambiguate);
use NNexus::Morphology qw(canonicalize_url);

sub new {
  my ($class,%opts) = @_;
  $opts{format} = lc($opts{format}||'html');
  $opts{result} = {};
  $opts{url} = canonicalize_url($opts{url}) if $opts{url};
  bless \%opts, $class;
}

sub execute {
  my ($self) = @_;
  given ($self->{function}) {
    when('linkentry') {$self->_link_entry;}
    when('indexentry') {$self->_index_entry;}
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
sub result { $_[0]->{result}->{payload}; }
sub message { $_[0]->{result}->{message}; }
sub status { $_[0]->{result}->{status}; }

sub _link_entry {
  my ($self) = @_;
  # Process in 2 Steps:
  # I. Concept Discovery
  my ($concepts_mined,$text_length) =
    NNexus::Discover::mine_candidates(
      db=>$self->{db},
      body=>$self->{body},
      url=>$self->{url},
      domain=>$self->{domain},
      format=>$self->{format},
      verbosity=>$self->{verbosity});
  # II. Disambiguation
  my $concepts_refined = NNexus::Classification::disambiguate(
    $concepts_mined,
    text_length=>$text_length,
    verbosity=>$self->{verbosity});
  # III. Annotation
  $self->{annotation} //= 'html';
  $self->{embed} //= 1;
  my $serialized_result = 
    NNexus::Annotate::serialize_concepts(
      body=>$self->{body},
      concepts=>$concepts_refined,
      annotation=>$self->{annotation},
      embed=>$self->{embed},
      domain=>$self->{domain},
      verbosity=>$self->{verbosity});
  $self->{result}={payload=>$serialized_result,message=>'No obvious problems.', status=>'OK'};
  $serialized_result;
}

sub _index_entry {
  my ($self)=@_;
  my $domain = $self->{domain} || 'all';
  my $url = $self->{url}||$self->{body};
  my $dom = $self->{dom};
  if ($dom && (! ref $dom)) { # Text:
    $dom = Mojo::DOM->new($dom);
  }
  my $should_update = $self->{should_update} // 1;
  require NNexus::Index::Dispatcher;
  my $dispatcher = NNexus::Index::Dispatcher->new(db=>$self->{db},domain=>$domain,
    verbosity=>$self->{verbosity},should_update=>$should_update,
    start=>$url,dom=>$dom);
  my @invalidation_suggestions;
  while (my $payload = $dispatcher->index_step) {
    push @invalidation_suggestions, @{$payload}; }
  my $report_url = ($url ne 'default') ? "http://$url" : 'the default domain root';
  $self->_ok_with(\@invalidation_suggestions,"IndexConcepts succeeded in domain $domain, on $report_url");
}

1;

__END__

=pod 

=head1 NAME

C<NNexus::Job> - Low-level API for servicing Job Requests to NNexus

=head1 SYNOPSIS

  use NNexus::Job;
  $job = NNexus::Job->new(
    db=>$db,
    body=>$body,
    format=>$format,
    function=>$function,
    domain=>$domain);
  
  $job->execute;
  
  $response = $job->response;
  $result = $job->result;
  $message = $job->message;
  $status = $job->status;

=head1 DESCRIPTION

This class serves as an encapsulation for users' NNexus requests, driven by a minimal API.

=head2 METHODS

=over 4

=item C<< $job = NNexus::Job->new(%options); >>

Creates a new job object, customized via an options hash. Admissible options are:

=over 2

=item *

body: The textual payload to be autolinked/indexed/etc.

=item *

format: The format of the given body. Supported: tex|html

=item *

function: Operation to be performed. Currently supported: 

=over 2

=item 

linkentry: Autolinks a given body returning a result in the same format

=item 

indexentry: Indexes a given web resource (URL), given by the "url" option

=back

=item *

url

=over 2

=item

for function "indexentry": URL at which to begin an indexing job 

=item

for function "linkentry": URL to record for change management and invalidation

=back

=item *

domain: Domain to use as the reference knowledge base for autolinking/indexing

=item *

anntation: serialization format for annotation (links, JSON, RDFa)

=item *

embed: boolean for embedded or stand-off annotations

=item *

db: An initialized NNexus::DB object (typically internal)

=item *

verbosity: boolean switching verbose logging on and off

=item *

dom: (optional) overrides the L<Mojo::DOM> object for the given C<url> (C<function='indexentry'>)

=item *

should_update: boolean switching between updating all indexed objects (default) or 
     only indexing new objects instead. (C<function='indexentry'>)

=back

=item C<< $job->execute; >>

Executes the job prepared by the new method.

=item C<< $response = $job->response; >>

Retrieves the job result. Returns a hash ref with three fields:

=over 2

=item *

result: the job result (e.g. a payload for a linking job)

=item *

message: a human-readable description of the job

=item *

status: a machine-readable status report

=back

=item C<< $result = $job->result; >>

Shorthand for C<$job-E<gt>response-E<gt>{result}>

=item C<< $status = $job->status; >>

Shorthand for C<$job-E<gt>response-E<gt>{status}>

=item C<< $message = $job->message; >>

Shorthand for C<$job-E<gt>response-E<gt>{message}>

=back

=head1 SEE ALSO

L<NNexus>, L<nnexus>, L<The NNexus Manual|https://github.com/dginev/nnexus/blob/master/MANUAL.md>

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the MIT License (MIT)

=cut
