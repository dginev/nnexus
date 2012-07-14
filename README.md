NNexus provides an API and an engine for autolinking.

For example, sending JSON like this:

```json
  {"function":"addobject",
   "title":"foo",
   "body":"bla blarg foo blab",
   "objid":123,
   "authorid":3,
   "linkpolicy":null,
   "classes":"11-XX",
   "synonyms":"bla bla",
   "defines":"bla bla bla",
   "batchmode":null}
```

will add the document foo to the repository.  The terms
"foo", "bla bla", and "bla bla bla" will then be
autolinked in the future, if you send in JSON like this:

```json
  {"function":"linkentry",
   "text":"bla bla bar agh garble blorg",
   "format":"xhtml",
   "nolink":null}
```

The exact API functionality and their arguments are as follows:

```perl
  linkentry        : $objid $text $format $nolink
  addobject        : $objid $title $body $authorid $linkpolicy $classes $synonyms $defines $batchmode
  updateobject     : $objid [ $title $body $authorid $linkpolicy $classes $synonyms $defines $batchmode ]
  updatelinkpolicy : $objid $linkpolicy
  deleteobject     : $objid
  checkvalid       : $objid
```
