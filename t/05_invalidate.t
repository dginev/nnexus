use strict;
use warnings;

use NNexus::DB;
use NNexus::Index::Dispatcher;
use Mojo::DOM;

use Test::More tests => 3;

# Prepare a DB object:
my %options = (
 "dbms" => "SQLite",
 "dbname" => ':memory:',
 "dbuser" => "nnexus",
 "dbpass" => "nnexus",
 "dbhost" => "localhost",
 "verbosity" => 0 );
my $db = NNexus::DB->new(%options);

# Add an object O1 and its two concept definitions (C1,C2) directly to DB
my $url = 'planetmath.org/O1';
my $O1_id = $db->add_object_by(url=>$url,domain=>'Planetmath'); #01
my $C1_id = $db->add_concept_by(
  concept=>'banach algebra', # C1
  category=>'46H05',
  objectid=>$O1_id,
  domain=>'Planetmath',
  link=>$url); 
my $C2_id = $db->add_concept_by(
  concept=>'dirichlet problem', # C2
  category=>'46H05',
  objectid=>$O1_id,
  domain=>'Planetmath',
  link=>$url); 

my $O2_id =  $db->add_object_by(url=>'planetmath.org/O2',domain=>'Planetmath'); #02
my $O3_id =  $db->add_object_by(url=>'planetmath.org/O3',domain=>'Planetmath'); #03
# Add a linkcache between a second object O2 and one of the concepts (C1) to DB
$db->add_linkscache_by(objectid=>$O2_id,conceptid=>$C1_id);
# Add a linkcache between a third object O3 and the second concept (C2) to DB
$db->add_linkscache_by(objectid=>$O3_id,conceptid=>$C2_id);
# Trigger an index job on a new DOM of O1, adding a new concept C3.
my $modified_entry_1 = <<'PM';
<html><section class="ltx_document">
<div class="ltx_rdf" property="dct:title" content="Banach algebra"/>
<div class="ltx_rdf" resource="msc:46H05" property="dct:subject"/>
<div class="ltx_rdf" property="pm:defines" content="pmconcept:Dirichlet problem"/>
<div class="ltx_rdf" property="pm:defines" content="pmconcept:Third concept"/>
</section></html>
PM
my $dom = Mojo::DOM->new($modified_entry_1);
my $dispatcher = NNexus::Index::Dispatcher->new(db=>$db,domain=>'Planetmath',verbosity=>0,
  start=>$url,dom=>$dom);
#   Expect an empty list to be returned for invalidation.
my $payload = $dispatcher->index_step();
is_deeply($payload,[],'Nothing to invalidate, new concept was added.');
# Trigger an index job on a new DOM of O1, renaming C1 to some new C4.
my $modified_entry_2 = <<'PM';
<html><section class="ltx_document">
<div class="ltx_rdf" property="dct:title" content="Banach theorem"/>
<div class="ltx_rdf" resource="msc:46H05" property="dct:subject"/>
<div class="ltx_rdf" property="pm:defines" content="pmconcept:Dirichlet problem"/>
<div class="ltx_rdf" property="pm:defines" content="pmconcept:Third concept"/>
</section></html>
PM
$dom = Mojo::DOM->new($modified_entry_2);
$dispatcher = NNexus::Index::Dispatcher->new(db=>$db,domain=>'Planetmath',verbosity=>0,
  start=>$url,dom=>$dom);
$payload = $dispatcher->index_step();
#   Expect O2 to be returned for invalidation
is_deeply($payload,['http://planetmath.org/O2'],'O2 returned for invalidation');
# Trigger an index job on a new DOM of O1, deleting C2. 
my $modified_entry_3 = <<'PM';
<html><section class="ltx_document">
<div class="ltx_rdf" property="dct:title" content="Banach theorem"/>
<div class="ltx_rdf" resource="msc:46H05" property="dct:subject"/>
<div class="ltx_rdf" property="pm:defines" content="pmconcept:Third concept"/>
</section></html>
PM
$dom = Mojo::DOM->new($modified_entry_3);
$dispatcher = NNexus::Index::Dispatcher->new(db=>$db,domain=>'Planetmath',verbosity=>0,
  start=>$url,dom=>$dom);
$payload = $dispatcher->index_step();
#   Expect O3 to be return for invalidation
is_deeply($payload,['http://planetmath.org/O3'],'O3 returned for invalidation');

# TODO: Positive invalidation, when the term-likelihood is operational
#      i.e. add possible, yet undefined, concepts to the concepts and linkcache tables.
#           and whenever their definitions are added, invalidate all objects from the linkcache
1;
