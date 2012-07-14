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
use vars qw($config $dbh $new_sock);

use NNexus::Job;
use NNexus::Util;
use NNexus::Config;

use Data::Dumper;

our $version = '0.1';
our $config = NNexus::Config->new;

$ENV{MOJO_HOME} = '.' unless defined $ENV{MOJO_HOME};
$ENV{MOJO_MAX_MESSAGE_SIZE} = 10485760; # 10 MB file upload limit

# Make signed cookies secure
app->secret('NNexus auto-linking for the win!');

post '/autolink' => sub {
  my $self = shift;
  my $parameters = $self->req->body_params;
  my $payload = $parameters->param('body');
  my $format = $parameters->param('format');
  my $operation = $parameters->param('function');

  my $job = NNexus::Job->new(config=>$config,payload=>$payload,format=>$format,jobtype=>$operation);
  $job->execute;
  $self->render(json=>{result=>$job->result});
};


app->start;
