NNexus Reloaded Documentation
===

This document intends to be a high level technical overview of the redesign and refactoring behind the NNexus Reloaded effort.

## Software Architecture
 The NNexus software stack is now evolved into an Object-oriented Perl 5 application (classic, can't Moo!)
 
 The class hierarchy is as follows:
```
  NNexus
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
