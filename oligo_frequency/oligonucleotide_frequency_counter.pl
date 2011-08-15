#!/usr/bin/perl

#count oligonucleotide frequencies

#written by david wilkins <david@wilkox.org>
#lives at https://github.com/wilkox/blast-tools

#this software is released into the public domain. To the extent 
# possible under law, all copyright and related or neighboring
# rights are waived and permission is explicitly and irrevocably
# granted to copy, modify, adapt, sell and distribute this software
# in any way you choose.

use warnings;
use Getopt::Long;

my $USAGE = q/USAGE:

oligonucleotide_frequency_counter [files...]
OPTIONAL:                         -n <oligonucleotide length>

Oligonucleotide length defaults to 4.
/;

#get options
my $oligoLength;
GetOptions( 
'n=s' => \$oligoLength,
);

#check options, set defaults
die $USAGE if @ARGV == 0;
$oligoLength = $oligoLength ? $oligoLength : 4;

#count oligonucleotide frequencies
foreach my $sequenceFile (@ARGV) {
	die ("ERROR - could not open input file at $sequenceFile") unless open(IN, "<$sequenceFile");
	my $seqName = "Unnamed Sequence ($sequenceFile)"; #tracks the current sequence name
	my $prepend = ""; #adds any leftover from the previous line onto the current line
	while (my $line = <IN>) {
		if ($line =~ /^>(.+)$/) {
			$prepend = ""; #wipe the prepend for new sequence
			$seqName = $1;
			next;
		}

		#remove crud from line and add prepend
		$line =~ s/\s//g;
		$line = lc($line);
		$line =~ s/[^a|t|c|g]//g;
		$line = $prepend . $line;

		#walk over sequence and pull all oligos of specified length
		my $i;
		for ($i = 0; $i <= length($line); ++$i) {
			my $oligo = substr($line, $i, $oligoLength);
			$prepend = $oligo if length($oligo) < $oligoLength;
			next if length($oligo) < $oligoLength;	
			++$count{$seqName}{$oligo};
			$allOligos{$oligo} = "";
		}
	}
	close IN;
}

#report
print "sequence";
foreach my $oligo (keys(%allOligos)) {
	print ",$oligo";
}

foreach my $seqName (keys(%count)) {
	print "\n$seqName";
	foreach my $oligo (keys(%allOligos)) {
		print exists $count{$seqName}{$oligo} ? ",$count{$seqName}{$oligo}" : ",0";
	}
}
