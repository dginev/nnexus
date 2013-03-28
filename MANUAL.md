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
setup
 |- database
   |- schema.sql
   |- setup_nnexus_mysql.sql
 |- config.json
lib
 |- NNexus
   |- Job.pm
   |- DB.pm
   |- Config.pm
   |- Util.pm
   |- Index
       |- Dispatcher.pm
       |- Template.pm
       |- Wikipedia.pm
       |- Mathworld.pm
       |- DLMF.pm
  ...
   |
   |- Concepts.pm
   |- Crossref.pm
   |- Domain.pm
   |- EncyclopediaEntry.pm
   |- LinkPolicy.pm
   |- Morphology.pm
```

The classes under the ... separator are yet to undergo more than a shallow refactoring pass and expect a rewrite.

### Minimal Configuration
 The ```config.json``` configuration file prepackages a default configuration for the NNexus backend, mirrored in the startup SQL script.
 The only configuration really needed by the NNexus application is a specified access to an SQL backend.
 
 All NNexus initialization is automatic, with the exception of indexing which is always performed on demand and can currently only be triggered by a request to the Web service.
 Soon there will also be an admin interface that makes the indexing (and other) requests more user-friendly.
 
### Turn-key Web Service
 The main ```bin/nnexus``` executable is a ```Mojolicious::Lite``` web service, that is easily deployable independently,
 as well as with a variety of web servers such as Apache + mod_perl or CGI, PSGI and Plack, or Mojolicious' own Hypnotoad.

 The web service receives requests from the outside world and is responsible for the state of the various processing jobs.
 It speaks JSON through HTTP (soon Websockets!) and aims at simple RESTful communication interfacing with external applciations.

### On Demand Processing
 In order to make NNexus scalable, robust and responsive, we divide the work in **processing jobs**.
 
 Each job is a ```NNexus::Job``` object, which flexibly supports all flavours of NNexus operations - on demand (re-)indexing,
 auto-linking (in turn concept-discovery and annotation). 
 
### Persistence and Provenance
 Deserving no more than a passing note, the NNexus knowledge base can be stored in any SQL backend that is supported by Perl's ```DBI``` library.

### Use in your own Perl Application
 The NNexus code now complies to the guidelines for writing Perl libraries, so besides having a convenient installation via:
 ```perl Makefile.PL; make ; make test ; make install ```
 
 you can also conveniently connect to a remote backend in the cloud via ```NNexus::Config``` and use that configuration for any NNexus operation,
 executed by a ```NNexus::Job``` object. In other words, NNexus functionality is easily embeddable in arbitrary Perl code.

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

The state of the web in 2013 is one of either no metadata (e.g. Wikipedia and DLMF) or document-level metadata (e.g. PlanetMath and MathWorld) in the vast majority of web pages. From this practical foundation, NNexus can interpret resources, identified by URLs, as opaque knowledge containers, labelled with container-level (i.e. coarse-grained) metadata.

On the other end of NNexus processing, we deal with mathematical concepts. Notice, however, that a "concept" is a semantic object in the mind of a mathematician, while what NNexus really work on are natural language constructs, typically phrases, that sometimes possibly represent mathematical concepts. Phenomena such as polysemy and metonymy are frequent also in the terms representing mathematical concepts. In addition, many concepts have several synonymous names, used in different contexts or in different communities.

Now, as the web is a distributed venture, multiple math encyclopedias exist and are of indexing interest. This creates another plurality, namely that each concept is possibly defined in multiple domains. Two restrictions come to our aid to make possible the classification and cross-referencing of web domains. The first is domain-internal, the Math Subject Classification, which namespaces a concept definition into a particular mathematical domain. With it, we can place the second restriction - one of uniqueness. We require each concept definition in a given MSC class to be unique (i.e. indicated by a single object, in turn a single URL) in each domain ( as in "Web domain").

With these restrictions in place, we can distinguish between:
 - term "space", category "Euclidean geometry", defined in PlanetMath
 - term "space", category "Euclidean geometry", defined in Wikipedia
 - term "space", category "Optimization", defined in PlanetMath
 - term "space", category "Optimization", defined in MathWorld

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

 **TODO:** Describe schema when stable

## Concept Discovery
 Discuss Longest-token matching, ideas for improvements.
 
 **TODO:** The code behind this functionality is yet to be revisted, but is on the development short-list.
 
## Annotation Schemes
 Talk about adding achors to HTML, JSON for editors, etc.
 
 **TODO:** These are also features that will be ready for the June release, but are future work as of March.
 
## Release Milestone and Goals

The NNexus 2.0 (NNexus Reloaded) milestone is set to expire at the end of June 2013, which is also the intended release date of the NNexus package.
The release will consist in tagging a GitHub branch, as well as releasing the NNexus library on CPAN. 
The main focus of the 2.0 release is to reincarnate and refactor the NNexus code, into a fresher and shinier app.

The NNexus 3.0 release is scheduled for the end of 2013 and will target various extensions and improvements to the original NNexus algorithms,
such as enhancing the longest-token matching logic for concept discovery, adding new annotation schemes and supporting more diverse and more numerous indexing sources.
