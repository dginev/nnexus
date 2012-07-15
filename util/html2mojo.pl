#/usr/bin/perl -w

use strict;
use warnings;
use LWP::UserAgent;
# sudo apt-get install libjson-perl
# to get the JSON module on Debian
use JSON;
use Encode;

my $html_file = shift||'pmtest.html';
my $result_file = shift||'pmresult.html';
open (HTML, "<", $html_file);
my $payload=join("",<HTML>);
close HTML;

my $uri = 'http://localhost:3000/autolink';
my $browser = LWP::UserAgent->new;
my @req = ($uri,
           {function=>'linkentry',  format => 'html', domain => 'planetmath',
	   body=>$payload});

my $response = $browser->post(@req);
open RESULT, ">", $result_file;
my $json = decode_json($response->decoded_content);
print RESULT encode('UTF-8',$json->{result});
close RESULT;
