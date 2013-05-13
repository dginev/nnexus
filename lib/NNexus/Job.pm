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

sub _index {
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

C<NNexus::Job> - Class for Servicing Job Request to NNexus

=head1 SYNOPSIS

    use NNexus::Job;
    my $job = NNexus::Job->new(db=>$db,body=>$body,format=>$format,function=>$function,
   			       domain=>$domain);
    $job->execute;
    my $response = $job->response;
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
    * index: Indexes a given web resource (URL), given by the "url" option
  - url: 
    * for function "index": URL at which to begin an indexing job 
    * for function "linkentry": URL to record for change management and invalidation
  - domain: Domain to use as the reference knowledge base for autolinking/indexing
  - anntation: serialization format for annotation (links, JSON, RDFa)
  - embed: boolean for embedded or stand-off annotations
  - db: An initialized NNexus::DB object (typically internal)
  - verbosity: boolean switching verbose logging on and off
  - dom: (optional) overrides the Mojo::DOM object for the given "url" (function=index)
  - should_update: boolean switching between updating all indexed objects (default) or 
     only indexing new objects instead. (function=index)

=item C<< $job->execute; >>

Executes the job prepared by the new method.

=item C<< $job->response; >>

Retrieves the job result. Returns a hash ref with three fields:
 result: the job result (e.g. a payload for a linking job)
 message: a human-readable description of the job
 status: a machine-readable status report

=item C<< $job->result; >>

Shorthand for $job->response->{result};

=item C<< $job->status; >>

Shorthand for $job->response->{status};

=item C<< $job->message; >>

Shorthand for $job->response->{message};

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the MIT License (MIT)

=cut
