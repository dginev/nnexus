#!/usr/bin/perl
#
# install my favorite programs if necessary:
use strict;

use CPAN;

open( IN, 'perl-deps.txt');

while ( my $line = <IN> ) {
	chomp($line);
        my $obj = CPAN::Shell->expand('Module',$line);
	$obj->install;
}
