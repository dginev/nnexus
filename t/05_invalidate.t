use strict;
use warnings;

use Test::More tests => 1;
TODO: {
  local $TODO = "Re-index a page used to auto-link t/04, "
    . " and see that it gets invalidated.";
  ok(1,'TODO');

# Add an object O1 and its two concept definitions (C1,C2) directly to DB
# Add a linkcache between a second object O2 and one of the concepts (C1) to DB
# Add a linkcache between a third object O3 and the second concept (C2) to DB
# Trigger an index job on a new DOM of O1, adding a new concept C4.
#   Expect an empty list to be returned for invalidation.
# Trigger an index job on a new DOM of O1, renaming C1 to C3.
#   Expect O2 to be returned for invalidation
# Trigger an index job on a new DOM of O1, deleting C2. 
#   Expect O3 to be return for invalidation

# TODO: Positive invalidation, when the term-likelihood is operational
#      i.e. add possible, yet undefined, concepts to the concepts and linkcache tables.
#           and whenever their definitions are added, invalidate all objects from the linkcache
}
