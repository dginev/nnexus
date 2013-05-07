NNexus Reloaded Documentation
===

This document intends to be a high level technical overview of the redesign and refactoring behind the NNexus Reloaded effort.

## Software Architecture
 The NNexus software stack is now evolved into an Object-oriented Perl 5 application (classic, can't Moo!)

### Class Hierarchy
 The class hierarchy is as follows:
```
bin
 |- nnexus
lib
 |- NNexus.pm
 |- NNexus
   |- Job.pm
   |- DB.pm
   |- DB
       |- API.pm
   |- Index
       |- Dispatcher.pm
       |- Template.pm
       |- Planetmath.pm
       |- Wikipedia.pm
       |- Mathworld.pm
       |- Dlmf.pm
   |- Concepts.pm
   |- Morphology.pm
   |- Discover.pm
   |- Classification.pm
   |- Annotate.pm
   |- resources
     |- database
       |- schema.sqlite
       |- snapshot.sqlite
```

The classes under the ... separator are yet to undergo more than a shallow refactoring pass and expect a rewrite.

### Minimal Configuration
 
 All NNexus initialization is automatic, with the exception of indexing which is always performed on demand and can currently only be triggered by a request to the Web service.
 If there is demand, there might also be an admin interface that makes the indexing (and other) requests more user-friendly.
 
 The default backend assumed by NNexus resides in ```lib/NNexus/resources/database/snapshot.db```, which contains a pre-packaged
 snapshot from all recognized indexing plug-ins. A custom backend can be requested by directly specifying it in a ```NNexus::DB``` object,
 or by providing its pathname as the first argument to the ```nnexus``` executable.
 
### Turn-key Web Service
 The main ```bin/nnexus``` executable is a ```Mojolicious::Lite``` web service, that is easily deployable independently,
 as well as with a variety of web servers such as Apache + mod_perl or CGI, PSGI and Plack, or Mojolicious' own Hypnotoad.

 The web service receives requests from the outside world and is responsible for the state of the various processing jobs.
 It speaks JSON through HTTP (soon Websockets!) and aims at simple RESTful communication interfacing with external applciations.

### On Demand Processing
 In order to make NNexus scalable, robust and responsive, we divide the work in **processing jobs**.
 
 Each job is a ```NNexus::Job``` object, which flexibly supports all flavours of NNexus operations - on demand (re-)indexing,
 auto-linking (in turn concept-discovery and annotation). 
 
### Use in your own Perl Application
 The NNexus code now complies to the guidelines for writing Perl libraries, following the standard installation via:
 ```perl Makefile.PL; make ; make test ; make install ```

You can embed NNexus processing in any Perl application by using the high-level ```NNexus``` class, or the mid-level
```NNexus::Job``` class. The library expects a CPAN release in mid-June 2013.

### NNexus Scripting

As NNexus is now a well-packaged Perl library you can use it in Perl applications
and script one-liners. For example, you could directly auto-link an HTML file with the following perl one-liner:

```shell
perl -MNNexus -e 'print linkentry(join("",<>))' < example.html > linked_example.html
```
 
### Persistence and Provenance
 Deserving no more than a passing note, the NNexus knowledge base can be stored in any SQL backend that is supported by Perl's ```DBI``` library.

## Indexing Framework
 The original NNexus application was tightly coupled with the framework behind PlanetMath.org, **Noosphere**.
 As NNexus 2.0 aims to be an independent general-purpose library for interlinking mathematical concepts, the
 coupling to both its sources of indexed terms and its target auto-link recepients has been loosened.
 
 On the indexing side, NNexus now takes initiative, as it crawls through web sites of interests and (re-)indexes their pages for defined math concepts.
 As there is no all-pervasive convention for annotating math concepts and their definitions at the time of writing (March 2013),
 every separate web site (or **domain**) requires a slightly (or completely) different indexing logic.
 
 The PULL API provides a one-size-fits-all logic for traversing web sites, parametrized in three key aspects:
 - The domain root to be the traversal start by default
 - The logic mining candidate links of interest from the currently visited page
 - The logic mining math concepts to be indexed from the currently visited page

With this framework in place, each domain indexer can be implemented in ~50 lines of Perl code. 

### Indexer Plug-ins
 Currently, NNexus sports four indexers - one for each of [PlanetMath](https://github.com/dginev/nnexus/blob/master/lib/NNexus/Index/Planetmath.pm), [Wikipedia](https://github.com/dginev/nnexus/blob/master/lib/NNexus/Index/Wikipedia.pm),
 [MathWorld](https://github.com/dginev/nnexus/blob/master/lib/NNexus/Index/Mathworld.pm) and [DLMF](https://github.com/dginev/nnexus/blob/master/lib/NNexus/Index/Dlmf.pm).
 
 Each domain provides a single Perl class ```NNexus::Index::Domain``` inheriting from the template class ```NNexus::Index::Template```.
 As each domain has different markup and arrangement for its concepts, the indexing logic varies in the different classes.
 
 However, the common API behind the plug-ins, as well as their common location at ```NNexus/Index/``` is quite powerful.
 NNexus is able to automatically discover every domain for which a indexing plug-in is available, initialize the correct backend tables,
 and automatically recognize and support jobs that request services for these domains.

### Just-in-time Indexing
 PlanetMath.org has offered its users just-in-time (re-)indexing for quite some time now, which is a feature
 we intend to keep supported. The new framework meets this need in two steps:
 - It allows for "on-demand" indexing jobs, through the web service API.
  
   Whenever the host application (e.g. PlanetMath) recognizes that a page of its content has changed, it is then requested for re-indexing by NNexus.

 - The second aspect is **change management** or re-linking of any PlanetMath page that had already used a newly indexed concept.

   This is harder to realize, as NNexus needs to be aware of all concept occurances before they are recognized as concepts. 
   The old NNexus implementation kept all of PlanetMath's articles in its index, which was a very heavy integration committment and ceratinly would not scale as the content grows in size.
   Reconceptualizing change management is still [work in progress](https://github.com/dginev/nnexus/issues/12) for the NNexus 2.0 implementation.

## The NNexus Knowledge Base

### Philosophy: Concepts, Resources and Signs

The state of the web in 2013, with respect to semantic annotations, is one of either no metadata (e.g. Wikipedia and DLMF) or document-level metadata (e.g. PlanetMath and MathWorld). From this practical foundation, NNexus views web resources, identified by URLs, as opaque knowledge containers, labelled with container-level, coarse-grained metadata.

On the other end of NNexus processing, we deal with mathematical concepts. Notice, however, that a "concept" is a semantic object in the mind of a mathematician, while what NNexus really operates on are natural language constructs, typically phrases, that sometimes possibly represent mathematical concepts. Phenomena such as polysemy and metonymy are frequent also in the terms representing mathematical concepts. In addition, many concepts have several synonymous names, used in different contexts or in different communities.

Now, as the web is a distributed venture, multiple math encyclopedias exist and are of indexing interest. This creates another plurality, namely that each concept is possibly defined in multiple domains. Two restrictions come to our aid to make possible the classification and cross-referencing of web domains. The first is domain-internal, the Math Subject Classification, which namespaces a concept definition into a particular mathematical domain. With it, we can place the second restriction - one of uniqueness. We require each concept definition in a given MSC class to be unique (i.e. indicated by a single object, in turn a single URL) in each domain ( as in "Web domain").

With these restrictions in place, we can distinguish between:
 - term "space", category "Euclidean geometry", defined in PlanetMath
 - term "space", category "Euclidean geometry", defined in Wikipedia
 - term "space", category "Optimization", defined in PlanetMath
 - term "space", category "Optimization", defined in MathWorld

 as different (by category or domain) concept definitions, all represented by the word "space".
 From an application stand-point, definitions from different domains but the same category are (ideally) semantically equivalent
 definitions of the same concept. On the other hand, definitions from the same domain but different categories are a
 sign of ambiguity in natural language, and need to be explicitly disambiguated in the concept discovery task. 

### Implementation
To summarize:
 - NNexus indexes and auto-links opaques objects, namely web resources, identified by URLs.
 - Web resources are seen as namespaced inside their top-level "domain"
 - Each relevantly indexed object defines concepts and their natural language names and synonyms, via top-level metadata.
 - Each concept is additionally namespaced inside a category, provided by the Math Subject Classification (also object metadata).
 - Concepts are only indirectly referenced by NNexus, via their natural language terms.
 - NNexus uniquely captures a concept definition by the tuple of:
  - its resource locator **URL** and **domain**
  - the concept's **MSC category**
  - the concept's representations as **natural language terms**

### Database Schema
The different NNexus tasks (indexing, concept discovery, annotation and invalidation) approach the knowledge base from different sides. For example, (re-)indexing needs to lookup if the object being processed is new or has been previously processed, and update it as necessary. On the other hand, invalidation and concept-discovery work on natural language fragments and are interested in doing efficient lookup for the terms already indexed. To make these processes efficient, NNexus creates a number of database indices for the fields of interest.

Currently NNexus uses a SQLite RDBMS with the following tables: 
 * ```Concepts``` - contains all concepts known to NNexus. Optimized for efficient lookup, via a split between ```firstword``` and ```tailwords``` of each concept.
 * ```Objects``` - Resource(URL)-centric, connects URLs with efficient DB identifiers and their domains. Makes change management for re-indexing simple (delete all existing concepts and their synonyms that had been defined at the resource, add the newly indexed ones, if any).
 * ```Links_cache``` - Change management map, between an objectid (of a linked URL) and one or more conceptid's (of the discovered concepts in that URL).
     It is now possible to do fine-grained change management on a concept level, as the cache can be invalidated on a per-concept basis, instead of per-object.
 * ```Dangling_cache``` - new table, similar to Links_cache but for concept **candidates** only.
 * ```Candidates``` - new table, similar to Concepts, but contains concept candidates, identified by their first word and natural language term ('firstword' and 'tailwords' columns).

**NOTE:** The ```Dangling_cache``` and ```Candidates``` tables are yet to be utilized, as we would require an implementation of term-likelihood analysis.

Initially, NNexus also supported MySQL as a backend, but the modest size of the concept snapshot motivated simplifying the setup and using an SQLite database.
On any modern machine that allows to have an in-memory database for NNexus processing, while still having persistence and provenance to the file system.
The typical NNexus snapshot database is under 10MB in size.

## Concept Discovery
 Discuss Longest-token matching, ideas for improvements.
 
 **TODO:** The code behind this functionality has now been revisted, add text here.
 
## Annotation Schemes
 Talk about adding achors to HTML, JSON for editors, etc.
 
 **TODO:** These are also features that will be ready for the June release, but are future work as of March.
 
## Release Milestone and Goals

The NNexus 2.0 (NNexus Reloaded) milestone is set to expire at the end of June 2013, which is also the intended release date of the NNexus package.
The release will consist in tagging a GitHub branch, as well as releasing the NNexus library on CPAN. 
The main focus of the 2.0 release is to reincarnate and refactor the NNexus code, into a fresher and shinier app.

The NNexus 3.0 release is scheduled for the end of 2013 and will target various extensions and improvements to the original NNexus algorithms,
such as enhancing the longest-token matching logic for concept discovery, adding new annotation schemes and supporting more diverse and more numerous indexing sources.
