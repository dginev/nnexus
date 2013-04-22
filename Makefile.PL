#======================================================================
# Makefile Maker for NNexus
# d.ginev@jacobs-university.de
#======================================================================
use ExtUtils::MakeMaker;
use strict;
use FindBin;

#======================================================================
# Use "perl Makefile.PL <options>"
#======================================================================

our $MORE_MACROS = {};
our $MORE_MAKERULES=''; 

WriteMakefile(
  NAME => 'NNexus',
  AUTHOR => 'Deyan Ginev <d.ginev@jacobs-university.de>',
  ABSTRACT => "NNexus autolinker",
  PREREQ_PM => { 
    'Mojolicious::Lite'=>0,
    'Mojo::JSON'=>0,
    'Mojo::DOM'=>0,
    'DBI'=>0,
    'DBD::SQLite'=>0,
    'DBD::mysql'=>0,
    'Encode'=>0,
    'Data::Dumper'=>0,
    'HTML::Parser'=>0,
    'Lingua::EN::StopWordList'=>0,
    'Text::Unidecode'=>0,
  },
  EXE_FILES => [ 'bin/nnexus'],
);
