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

### Turn-key web service
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

## PULL API framework
 Discuss the indexing framework with a NNexus spider.

## Plug-in based Indexing
 Discuss a template plug-in for indexing a new web site.

## Concept Discovery
 Discuss Longest-token matching, ideas for improvements.
 
## Annotation Schemes
 Talk about adding achors to HTML, JSON for editors, etc.
 
