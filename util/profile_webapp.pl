use strict;
use warnings;
use FindBin;
use Mojolicious;

use Test::More;
use Test::Mojo;

$ENV{MOJO_MODE} = 'test';
require "$FindBin::Bin/../blib/script/nnexus";

my $t = Test::Mojo->new;

# 3. PlanetMath HTML input, embed links
# Read in the HTML test
open my $fh, "<", 't/pages/pm_gelfand_transforms.html';
my $html_content = join('',<$fh>);
close $fh;

$t->post_ok('/linkentry' => form => {format=>'html',body=>$html_content,domain=>'Planetmath'}) for 1..100;
done_testing();