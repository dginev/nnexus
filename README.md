[![Build Status](https://secure.travis-ci.org/dginev/nnexus.png?branch=master)](http://travis-ci.org/dginev/nnexus)

* * *
NNexus is published on [CPAN](https://metacpan.org/release/NNexus).

Just execute ```cpan NNexus``` (or ```cpanm``` if you're a cpanminus lover) to obtain the full distribution.
* * *

NNexus provides an API and an engine for auto-linking of mathematical concepts.
 It supports the subtasks of concept indexing, concept discovery and flexible annotation (e.g. linking).
 
NNexus is free, libre, open-source software.

The library comes with a pre-packaged snapshot of over 10,000 concepts from PlanetMath,
 Wikipedia, Wolfram Mathworld and DLMF. You can jump right in with a perl one-liner:
 
```shell
perl -MNNexus -e 'print linkentry(join("",<>))' < example.html > linked_example.html
```

... or read the rest of this README for installation instructions and further use cases.

The [Manual](pod/Manual.pod) draft contains a **technical overview** of the NNexus system.

For **installation and deployment**, consult [the INSTALL file](INSTALL.md).

## Demos

[nnexusglasses.user.js](util/nnexusglasses.user.js) is a
[Userscript](http://userscripts.org/about/installing) that you can use
to add links to math terms in any web page!

NNexus deployed on [PlanetMath.org](http://planetmath.org).

## Using NNexus as a Web Service

`curl -d "An abelian group example." nnexus.mathweb.org`

Returns:

```
{"status":"OK","payload":"An <a class=\"nnexus_concepts\" href=\"javascript:void(0)\" onclick=\"this.nextSibling.style.display='inline'\">abelian group<\/a><sup style=\"display: none;\"><a class=\"nnexus_concept\" href=\"http:\/\/mathworld.wolfram.com\/AbelianGroup.html\"><img src=\"http:\/\/mathworld.wolfram.com\/favicon_mathworld.png\" alt=\"Mathworld\"><\/img><\/a><a class=\"nnexus_concept\" href=\"http:\/\/planetmath.org\/abeliangroup\"><img src=\"http:\/\/planetmath.org\/sites\/default\/files\/fab-favicon.ico\" alt=\"Planetmath\"><\/img><\/a><\/sup> example.","message":"No obvious problems."}
```

These two lines of PHP illustrate how NNexus can be used within a program;
see [Planetary](https://github.com/KWARC/planetary) for more details.
```php
  $data = 'body=' . urlencode($text) . '&format='.$format.'&domain=Planetmath';
  $content = planetary_webglue_do_post('http://127.0.0.1:3000/linkentry',$data);
```
## NNexus API

The NNexus legacy API has been redesigned, into a simple pair of indexing and linking workflows,
 detailed in the "[Indexing Framework](pod/Manual.pod#indexing-framework)" and "[Annotation Schemes](pod/Manual.pod#annotation-schemes)" chapters in the manual.

# Status

This is a fork and rewrite of the original NNexus code by James Gardner (pebbler@gmail.com).  Watch this space for frequent updates.

The current development emphasis falls on improving linking accuracy as well as maintenance patches.

# Contact

For any questions and support requests, contact the current package maintainer:
Deyan Ginev (d.ginev@jacobs-university.de)
