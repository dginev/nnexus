use strict;
use warnings;

use Test::More tests => 1;
TODO: {
  local $TODO = "Re-index a page used to auto-link t/04, "
    . " and see that it gets invalidated.";
  ok(1,$TODO);
}
