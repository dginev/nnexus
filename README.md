NNexus provides an API and an engine for auto-linking of mathematical concepts.
 It supports the subtasks of concept indexing, concept discovery and flexible annotation (e.g. linking).
 
NNexus is free, libre, open-source software.

The library comes with a pre-packaged snapshot of over 10,000 concepts from PlanetMath,
 Wikipedia, Wolfram Mathworld and DLMF. You can jump right in with a perl one-liner:
 
```shell
perl -MNNexus -e 'print linkentry(join("",<>))' < example.html > linked_example.html
```

... or read the rest of this README for installation instructions and further use cases.

The [Manual](MANUAL.md) draft contains a **technical overview** of the NNexus system.

For **installation and deployment**, consult [the INSTALL file](INSTALL.md).

## Connecting from a client

These two lines of PHP illustrate how NNexus can be used via [Planetary](https://github.com/KWARC/planetary)'s curl:
```php
  $data = 'function=linkentry&body=' . urlencode($text) . '&format='.$format.'&domain=Planetmath';
  $content = planetary_webglue_do_post('http://127.0.0.1:3000/linkentry',$data);
```
## NNexus API

JSON is already the preferred representation for NNexus requests,
yet the coverage of the original NNexus request types is incomplete.

An auto-linking example:
```json
  {"function":"linkentry",
   "body":"<html><body><p>Some text using myconcept, ourconcept or theirconcept</p></body></html>",
   "format":"html",
   "embed":1,
   "nolink":null}
```
**TIP:** The above JSON parameters are the defaults, so simply sending a HTTP POST request with the body field to
```localhost:3000/linkentry``` would yield the same result.

The NNexus legacy API is being redesigned at the moment, into a simple pair of indexing and linking workflows.
**TODO:** Describe the new API when finalized.

# Status

This is a fork and rewrite of the original NNexus code by James Gardner (pebbler@gmail.com).
The current refactoring is pre-alpha and is under active development. Watch this space for frequent updates.

The scheduled release for the "NNexus Reloaded" milestone is June 2013.
The release will target introducing a new CPAN library and production deployment at [PlanetMath.org](http://www.planetmath.org)

# Contact

For any questions and support requests, contact the current package maintainer:
Deyan Ginev (d.ginev@jacobs-university.de)
