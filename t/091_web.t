use strict;
use warnings;
use FindBin;
use Mojolicious;

use Test::More;
use Test::Mojo;

$ENV{MOJO_MODE} = 'test';
require "$FindBin::Bin/../blib/script/nnexus";

is($Mojolicious::VERSION >= 3.9, 1, "New enough Mojolicious installed, at least 3.9.");
if ($Mojolicious::VERSION < 4) {
  my $t = Test::Mojo->new;
  # Start off with a mockup
  $t->post_ok('/linkentry' => form => {format=>'text',body=>'mockup'})
    ->status_is(200)
    ->json_content_is({payload => 'mockup',status=>'OK',message=>"No obvious problems."});

  # Now a bare link
  $t->post_ok('/linkentry' => form => {format=>'text',domain=>'Planetmath',body=>'test banach algebra here.'})
    ->status_is(200)
    ->json_content_is({
    	payload => 'test <a class="nnexus_concept" href="http://planetmath.org/banachalgebra">banach algebra</a> here.',
    	status=>'OK',
    	message=>"No obvious problems."});

  # Try indexing something empty
  $t->post_ok('/indexentry' => form => {url=>'http://planetmath.org/mockup',domain=>"Planetmath",dom=>"mockup"})
    ->status_is(200)
    ->json_content_is({
    	payload => [],
    	status=>'OK',
    	message=>"IndexConcepts succeeded in domain Planetmath, on http://planetmath.org/mockup"});
} else {
  my $t = Test::Mojo->new;
  # Start off with a mockup
  $t->post_ok('/linkentry' => form => {format=>'text',body=>'mockup'})
    ->status_is(200)
    ->json_is({payload => 'mockup',status=>'OK',message=>"No obvious problems."});

  # Now a bare link
  $t->post_ok('/linkentry' => form => {format=>'text',domain=>'Planetmath',body=>'test banach algebra here.'})
    ->status_is(200)
    ->json_is({
      payload => 'test <a class="nnexus_concept" href="http://planetmath.org/banachalgebra">banach algebra</a> here.',
      status=>'OK',
      message=>"No obvious problems."});
    
  # Try indexing something empty
  $t->post_ok('/indexentry' => form => {url=>'http://planetmath.org/mockup',domain=>"Planetmath",dom=>"mockup"})
    ->status_is(200)
    ->json_is({
      payload => [],
      status=>'OK',
      message=>"IndexConcepts succeeded in domain Planetmath, on http://planetmath.org/mockup"});
}
done_testing();