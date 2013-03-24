NNexus provides an API and an engine for auto-linking of mathematical concepts.
 It supports the subtasks of concept indexing, concept discovery and flexible annotation (e.g. linking).

NNexus is free, libre, open-source software.

# Installation and Deployment

You can check out the [Manual](MANUAL.md) draft, for a technical overview of the NNexus system.

## Setting up the server

You need Mojolicious and several other standard perl
modules, which can be installed via your OS package manager or CPAN.

On Debian-based systems:
```
apt-get install libmojolicious-perl libxml-simple-perl \
  libunicode-string-perl libgraph-perl libjson-perl
```

Then, in order to quickly run the server:

```
perl Makefile.PL ; make ; make test
morbo --listen=http://*:3001 blib/script/nnexus setup/baseconf.xml
```

Note: While morbo is nice for development, deploying through Apache or Hypnotoad would be clearly the way to go for production use.
Work is underway into making NNexus into a proper service that you would be able to boot via the standard

```sh
sudo service nnexus start
```

## Connecting from a client

These two lines of PHP illustrate how NNexus can be used via curl:

```php
  $data = 'function=linkentry&body=' . urlencode($text) . '&format='.$format.'&domain=planetmath';
  $content = planetary_webglue_do_post('http://127.0.0.1:3001/autolink',$data);
```

# Future plans

## Exhaustive JSON support

JSON is already the preferred representation for NNexus requests, yet the coverage of the original NNexus request types is incomplete.
For example, sending JSON like this, as prescribed by the legaxy NNexus API:

```json
  {"function":"addobject",
   "title":"myconcept",
   "body":"a description or other message",
   "objid":123,
   "authorid":3,
   "linkpolicy":null,
   "classes":"11-XX",
   "synonyms":"ourconcept, theirconcept",
   "defines":"others",
   "batchmode":null}
```

will add the document foo to the repository.  The terms
"myconcept", "ourcocnept", and "theirconcept" will then be
autolinked in the future, if you send in JSON like this:

```json
  {"function":"linkentry",
   "body":"Some text using myconcept, ourconcept or theirconcept",
   "format":"xhtml",
   "nolink":null}
```

The exact legacy API is as follows:
 There are plans to revisit and polish the API in the future, so keep an open eye on this space.
 
```perl
  linkentry        : $objid $text $format $nolink
  addobject        : $objid $title $body $authorid $linkpolicy $classes $synonyms $defines $batchmode
  updateobject     : $objid [ $title $body $authorid $linkpolicy $classes $synonyms $defines $batchmode ]
  updatelinkpolicy : $objid $linkpolicy
  deleteobject     : $objid
  checkvalid       : $objid
```

# Status

This is a fork and rewrite of the original NNexus code by James Gardner (pebbler@gmail.com).
The current refactoring is pre-alpha and is under active development. Watch this space for frequent updates.

The scheduled release for the "NNexus Reloaded" milestone is June 2013.

# Contact

For any questions and support requests, contact the current package maintainer:
Deyan Ginev (d.ginev@jacobs-university.de)
