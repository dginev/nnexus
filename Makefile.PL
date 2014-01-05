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
our @EXCLUSIONS=();
our $MORE_MACROS = {};
our $MORE_MAKERULES=''; 

compile_snapshot_db();

WriteMakefile(
  NAME => 'NNexus',
  AUTHOR => 'Deyan Ginev <d.ginev@jacobs-university.de>',
  ABSTRACT => "NNexus autolinker",
  VERSION_FROM => 'lib/NNexus.pm',
  PREREQ_PM => { 
    'Mojolicious'=>4.6,
    'Mojolicious::Lite'=>0,
    'Mojo::JSON'=>0,
    'Mojo::DOM'=>0,
    'DBI'=>0,
    'DBD::SQLite'=>0,
    'HTML::Parser'=>0,
    'List::MoreUtils'=>0,
    'Text::Unidecode'=>0,
  },
  EXE_FILES => ['bin/nnexus'],
  macro => $MORE_MACROS,
);

#**********************************************************************
# Overriding ExtUtils::MM methods
#**********************************************************************
# Exclude the sources used to generate others from the build (See below).
sub MY::libscan {
  my($self,$path)=@_;
  if(($path =~ /~$/) || grep($path eq $_, @EXCLUSIONS)){
    return ""; }
  $self->MY::SUPER::libscan($path); }

# Append any additional Makefile rules added by the following.
sub MY::postamble {
  shift->MY::SUPER::postamble(@_) . $MORE_MAKERULES; }


sub compile_snapshot_db {
  push(@EXCLUSIONS,'blib/lib/NNexus/resources/database/snapshot-1-2014.sqlite');
  $$MORE_MACROS{SNAPSHOT_FILE} = '$(INST_LIBDIR)/NNexus/resources/database/snapshot.db';
  $$MORE_MACROS{DUMP_FILE} = 'lib/NNexus/resources/database/snapshot-1-2014.sqlite';
  $$MORE_MACROS{DBH} = '$$dbh';
  $$MORE_MACROS{IT} = '$$_';
  $$MORE_MACROS{SQLITE} = 'sqlite3';
  $MORE_MAKERULES .= <<'CompileSnapshot';

pure_all :: $(SNAPSHOT_FILE)

# Always set version if version module template is newer
$(SNAPSHOT_FILE): $(DUMP_FILE)
	$(PERLRUN) -e '$$file = shift; unlink $$file; $$now = time; utime $$now, $$now, $$file;' $(SNAPSHOT_FILE)
	$(PERLRUN) -MDBI -e 'my $(DBH) = DBI->connect( "dbi:SQLite:".shift ); open(IN,"<",shift); for (split(/;\n(?!END)/,join("",<IN>))) {$(DBH)->do($(IT));} close IN; $(DBH)->disconnect;' $(SNAPSHOT_FILE) $(DUMP_FILE)

CompileSnapshot
}
