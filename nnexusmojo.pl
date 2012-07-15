#!/usr/bin/perl
# ----------------------------------------------------------------
# A Mojo Web App as a NNexus entry point
# Deyan Ginev, <d.ginev@jacobs-university.de>
# GPL code
# ----------------------------------------------------------------
use File::Basename;
my $FILE_BASE;
BEGIN {
    $FILE_BASE = dirname(__FILE__);
}
use lib $FILE_BASE."/lib";
#use lib $FILE_BASE."/NNexus";

use Mojolicious::Lite;
use Mojo::JSON;
use Mojo::IOLoop;
use Mojo::ByteStream qw(b);

use Encode;
use strict;

use NNexus::Job;
use NNexus::Config;

use Data::Dumper;

our $version = '0.1';
# Configuration is server-level
our $config = NNexus::Config->new;

$ENV{MOJO_HOME} = '.' unless defined $ENV{MOJO_HOME};
$ENV{MOJO_MAX_MESSAGE_SIZE} = 10485760; # 10 MB file upload limit

# Make signed cookies secure
app->secret('NNexus auto-linking for the win!');

post '/autolink' => sub {
  my $self = shift;
  my $get_params = $self->req->url->query->params || [];
  my $post_params = $self->req->body_params->params || [];
  if (scalar(@$post_params) == 1) {
    $post_params = ['body' , $post_params->[0]];
  } elsif (scalar(@$post_params) == 2 && ($post_params->[0] ne 'body')) {
    $post_params = ['body' , $post_params->[0].$post_params->[1]];
  }
  my $parameters = { @$get_params, @$post_params };
  # Currently , we only support :
  my $payload = $parameters->{'body'};
  my $format = $parameters->{'format'}||'html';
  my $operation = $parameters->{'function'}||'linkentry';
  my $domain = $parameters->{'domain'}||'planetmath';
  my $job = NNexus::Job->new(config=>$config,payload=>$payload,format=>$format,jobtype=>$operation,
			    domain=>$domain);
  $job->execute;
  $self->render(json=>{result=>$job->result});
};


app->start;
