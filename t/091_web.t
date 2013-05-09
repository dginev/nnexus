use strict;
use warnings;
use FindBin;

use Test::More;
use Test::Mojo;

$ENV{MOJO_MODE} = 'test';
require "$FindBin::Bin/../blib/script/nnexus";

my $t = Test::Mojo->new;
# Start off with a mockup
$t->post_form_ok('/linkentry' => {format=>'text',body=>'mockup'})
  ->status_is(200)
  ->json_content_is({payload => 'mockup',status=>'OK',message=>"No obvious problems."});

# Now a bare link
$t->post_form_ok('/linkentry' => {format=>'text',domain=>'Planetmath',body=>'test banach algebra here.'})
  ->status_is(200)
  ->json_content_is({
  	payload => 'test <a class="nnexus_concept" href="http://planetmath.org/banachalgebra">banach algebra</a> here.',
  	status=>'OK',
  	message=>"No obvious problems."});

# Try indexing something empty
$t->post_form_ok('/indexentry' => {url=>'http://planetmath.org/mockup',domain=>"Planetmath",dom=>"mockup"})
  ->status_is(200)
  ->json_content_is({
  	payload => [],
  	status=>'OK',
  	message=>"IndexConcepts succeeded in domain Planetmath, on: http://planetmath.org/mockup"});

done_testing();