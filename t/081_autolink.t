use strict;
use warnings;

use Test::More tests => 3;
use File::Temp;
File::Temp->safe_level( File::Temp::HIGH );

use NNexus::Job;
use NNexus::Config;

# However, we really want our own test setup:
my $tmphandle = File::Temp->new( TEMPLATE => 'nnexusXXXXX',
                       SUFFIX => '.db');
my $options = {
  "database" => {
    "dbms" => "SQLite",
    "dbname" => $tmphandle->filename,
    "dbuser" => "nnexus",
    "dbpass" => "nnexus",
    "dbhost" => "localhost",
  },
  "verbosity" => 0
};

my $config=NNexus::Config->new($options);
# 1. Mock text input, stand-off JSON
my $job = NNexus::Job->new('format' => 'text', 'function' => 'linkentry', 'domain' => 'Planetmath', body=>'mock body',config=>$config,annotation=>'json',embed=>0);
$job->execute;
is_deeply($job->response,
	  {status=>'OK',payload=>[],message=>'No obvious problems.'},
	  'Mock JSON auto-link, ok.');
# 2. Mock text input, embed links
$job = NNexus::Job->new('format' => 'text', 'function' => 'linkentry', 'domain' => 'Planetmath', body=>'mock body',config=>$config,annotation=>'links',embed=>1);
$job->execute;
is_deeply($job->response,
	  {status=>'OK',payload=>'mock body',message=>'No obvious problems.'},
	  'Mock text-embed auto-link, ok.');

# 3. PlanetMath HTML input, embed links
# We link against a single concept - Banach algebra
my $db = $config->get_DB;
my $url = 'http://planetmath.org/banachalgebra';
my $objectid = $db->add_object_by(url=>$url,domain=>'Planetmath');
$db->add_concept_by(concept=>'Banach algebra',
		    category=>'46H05',
		    objectid=>$objectid,
		    domain=>'Planetmath',
		    link=>$url);
# Read in the HTML test
open my $fh, "<", 't/pages/pm_gelfand_transforms.html';
my $html_content = join('',<$fh>);
close $fh;
$job = NNexus::Job->new('format' => 'html', 'function' => 'linkentry', 'domain' => 'Planetmath', body=>$html_content,config=>$config,annotation=>'links',embed=>1);
$job->execute;
is_deeply($job->response,
	  {status=>'OK',payload=>$html_content,message=>'No obvious problems.'},
	  'Mock text-embed auto-link, ok.');

# TODO: Expand with more meaningful tests
