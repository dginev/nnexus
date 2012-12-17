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

WriteMakefile(NAME => 'NNexus',
	      AUTHOR => 'Deyan Ginev <d.ginev@jacobs-university.de>',
	      ABSTRACT => "NNexus autolinker",
	      PREREQ_PM => { 
			    'Test::Simple'=>0,
				'XML::Simple'=>0,
				'Unicode::String'=>0,
				'Mojolicious'=>0,
				'Graph'=>0,
				'DBI'=>0,
				'DBD::mysql'=>0,
				'LWP'=>0,
				'JSON'=>0,
				'Encode'=>0
				# We also need mysql server installed,
				# Any way to mark this in the dependencies?
			   },
	      EXE_FILES => [ 'bin/nnexus','baseconf.xml'],
	      );
