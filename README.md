NNexus provides an API and an engine for auto-linking of mathematical concepts.
 It supports the subtasks of concept indexing, concept discovery and flexible annotation (e.g. linking).
 
NNexus is free, libre, open-source software.

The library comes with a pre-packaged snapshot of over 10,000 concepts from PlanetMath,
 Wikipedia, Wolfram Mathworld and DLMF. You can jump right in with a perl one-liner:
 
```shell
perl -MNNexus -e 'print linkentry(join("",<>))' < example.html > linked_example.html
```

... or read the rest of this README for installation instructions and further use cases.

Feel free to check out the [Manual](MANUAL.md) draft, for a technical overview of the NNexus system.

# Installation and Deployment

## Setting up the server

Standard Perl installation from source:
```
perl Makefile.PL ; make ; make test
```
**NOTE:** Running perl over Makefile.PL will warn you of any missing packages you need to install, 
either via CPAN or your OS package manager.

Installing prerequisites on Debian-based systems (TODO: incomplete):
```
apt-get install libmojolicious-perl libxml-simple-perl \
  libunicode-string-perl libgraph-perl libjson-perl \
  ...
```

Then, in order to quickly run the server:
```
morbo --listen=http://*:3001 blib/script/nnexus setup/config.json
```

Note: While morbo is nice for development, deploying through Apache or Hypnotoad would be clearly the way to go for production use.
TODO: Add Apache deployment instructions in [the INSTALL file](INSTALL.md)

## Connecting from a client

These two lines of PHP illustrate how NNexus can be used via [Planetary](https://github.com/KWARC/planetary)'s curl:
```php
  $data = 'function=linkentry&body=' . urlencode($text) . '&format='.$format.'&domain=planetmath';
  $content = planetary_webglue_do_post('http://127.0.0.1:3001/autolink',$data);
```

# Future plans

## Exhaustive JSON support

JSON is already the preferred representation for NNexus requests,
yet the coverage of the original NNexus request types is incomplete.

Auto-linking example:
```json
  {"function":"linkentry",
   "body":"Some text using myconcept, ourconcept or theirconcept",
   "format":"xhtml",
   "embed":1,
   "nolink":null}
```

The NNexus legacy API is being redesigned at the moment, into a simple pair of indexing and linking workflows.
TODO: Describe the new API when finalized.

# Status

This is a fork and rewrite of the original NNexus code by James Gardner (pebbler@gmail.com).
The current refactoring is pre-alpha and is under active development. Watch this space for frequent updates.

The scheduled release for the "NNexus Reloaded" milestone is June 2013.
The release will target introducing a new CPAN library and production deployment at [PlanetMath.org](http://www.planetmath.org)

# Contact

For any questions and support requests, contact the current package maintainer:
Deyan Ginev (d.ginev@jacobs-university.de)
