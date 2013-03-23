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
   |- Job
   |- DB
   |- Config
   |- Util
   |- Index
       |- Dispatcher
       |- Template
       |- Wikipedia
       |- Mathworld
       |- DLMF
  ...
   |
   |- Concepts
   |- Crossref
   |- Domain
   |- EncyclopediaEntry
   |- LinkPolicy
   |- Morphology
```

The classes under the ... separator are yet to undergo more than a shallow refactoring pass and expect refactoring.

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
 Talk about the any-SQL backend.

### Use in your own Perl Application
 The NNexus code now complies to the guidelines for writing Perl libraries, so besides having a convenient installation via:
 ```perl Makefile.PL; make ; make test ; make install ```
 
 you can also conveniently connect to a remote backend in the cloud via ```NNexus::Config``` and use that configuration for any NNexus operation,
 executed by a ```NNexus::Job``` object. In other words, NNexus functionality is easily embeddable in arbitrary Perl code.

## PULL API Framework
 Discuss the indexing framework with a NNexus spider.

## Indexing Plug-ins
 Discuss a template plug-in for indexing a new web site.

## Concept Discovery
 Discuss Longest-token matching, ideas for improvements.
 
## Annotation Schemes
 Talk about adding achors to HTML, JSON for editors, etc.
 
## Release Milestone and Goals

The NNexus 2.0 (NNexus Reloaded) milestone is set to expire at the end of June 2013, which is also the intended release date of the NNexus package.
The release will consist in tagging a GitHub branch, as well as releasing the NNexus library on CPAN. 
The main focus of the 2.0 release is to reincarnate and refactor the NNexus code, into a fresher and shinier app.

The NNexus 3.0 release is schedule for the end of 2013 and will target various extensions and improvements to the original NNexus algorithms,
such as enhancing the longest-token matching logic for concept discovery, adding new annotation schemes and supporting more diverse and more numerous indexing sources.
