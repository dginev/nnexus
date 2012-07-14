package NNexus::Job;
use XML::LibXML;
use NNexus::API qw(link_entry);

sub new {
  my ($class,%opts) = @_;
  $opts{format} = lc($opts{format});
  $opts{parser} = XML::LibXML->new();
  bless \%opts, $class;
}

sub execute {
  my ($self) = @_;
  my $dom;

  if ($self->{jobtype} eq 'linkentry') {
    $self->{result} = link_entry({config=>$self->{config},body=>$self->{payload},
				  format=>$self->{format},domain=>$self->{config}->{domains}->{domain}});
    print STDERR $self->{result};
  }
}

sub result {
  $_[0]->{result};
}


1;
