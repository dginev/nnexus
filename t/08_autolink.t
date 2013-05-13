use strict;
use warnings;

use Test::More tests => 4;

use NNexus::Job;
use NNexus::DB;

# However, we really want our own test setup:
my %options = (
  "dbms" => "SQLite",
  "dbname" => ':memory:',
  "dbuser" => "nnexus",
  "dbpass" => "nnexus",
  "dbhost" => "localhost",
  "verbosity" => 0
);

my $db = NNexus::DB->new(%options);
# We link against a single concept - Banach algebra
my $url = 'http://planetmath.org/banachalgebra';
my $objectid = $db->add_object_by(url=>$url,domain=>'Planetmath');
$db->add_concept_by(
  concept=>'banach algebra',
  category=>'46H05',
  objectid=>$objectid,
  domain=>'Planetmath',
  link=>$url);

my $basic_banach = 'mock body, Banach, algebra is a failing test, so is Banach, and then Banach\'s Algebra should work.';
my $basic_banach_embedded = 'mock body, Banach, algebra is a failing test, so is Banach, and then <a class="nnexus_concept" href="http://planetmath.org/banachalgebra">Banach\'s Algebra</a> should work.';
# 1. Basic text input, stand-off Perl
use Data::Dumper;
$Data::Dumper::Sortkeys =1;
my $job = NNexus::Job->new('format' => 'text', 'function' => 'linkentry',
	'domain' => 'Planetmath', body=>$basic_banach,
  ,db=>$db,annotation=>'perl',embed=>0);
$job->execute;
is_deeply($job->response,
	{status=>'OK',payload=>Dumper([{"link"=>"http://planetmath.org/banachalgebra","offset_begin"=>69,"scheme"=>"msc","objectid"=>1,
  "firstword"=>"banach","conceptid"=>1,"domain"=>"Planetmath","offset_end"=>85,"category"=>"46H05","concept"=>"banach algebra"}]),
  message=>'No obvious problems.'},
	'Basic Perl auto-link, ok.');
# 2. Basic text input, embed links
$job = NNexus::Job->new('format' => 'text', 'function' => 'linkentry',
	'domain' => 'Planetmath', body=>$basic_banach,db=>$db,annotation=>'html',embed=>1);
$job->execute;
is_deeply($job->response,
	{status=>'OK',payload=>$basic_banach_embedded,message=>'No obvious problems.'},
	'Basic text-embed auto-link, ok.');

# 3. PlanetMath HTML input, embed links
# Read in the HTML test
open my $fh, "<", 't/pages/pm_gelfand_transforms.html';
my $html_content = join('',<$fh>);
close $fh;
$job = NNexus::Job->new('format' => 'html', 'function' => 'linkentry', url=>'http://test081.com',
	'domain' => 'Planetmath', body=>$html_content,db=>$db,annotation=>'html',embed=>1);
$job->execute;
open my $rh, "<", 't/pages/pm_gelfand_transforms_result.html';
my $html_result = join('',<$rh>);
close $rh;
is_deeply($job->response,
 	{status=>'OK',payload=>$html_result,message=>'No obvious problems.'},
  	'Mock text-embed auto-link, ok.');

# 4. UTF-8 test (seems to be the best place to include that)
# No concepts here - we just want the same thing out that we put in.
open $fh, "<", 't/pages/utf8.html';
my $utf8_content = join('',<$fh>);
close $fh;
my $utf8_saved = $utf8_content;
$job = NNexus::Job->new('format' => 'html', 'function' => 'linkentry',
  'domain' => 'Planetmath', body=>$utf8_content,db=>$db,annotation=>'html',embed=>1);
$job->execute;
is_deeply($job->response,
  {status=>'OK',payload=>$utf8_saved,message=>'No obvious problems.'},
    'Mock text-embed auto-link, ok.');
# TODO: Expand with more tests
