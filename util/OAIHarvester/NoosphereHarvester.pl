#!/usr/bin/perl

my $baseURL = "http://mathdl.maa.org/partnerOAI";

`perl OAIHarvester.pl $baseURL oai_dc "MathWorld" > mathworld.xml`;
`perl OAIHarvester.pl $baseURL oai_dc "MathResources Inc." > mathresources.xml`;

