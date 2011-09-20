#!/usr/bin/perl

#read in blast output
while (my $line = <STDIN>) {
  my @line = split(/\t/, $line);
  $feature{@line[0]}{@line[1]}{'start'} = @line[6];
  $feature{@line[0]}{@line[1]}{'end'} = @line[7];
  print "\nin scaff @line[0], feature @line[1] starts at @line[6] and ends at @line[7]";
}
