#!/usr/bin/perl

use warnings;
use Getopt::Long;

my $USAGE = q/**Usage goes here***
/;

#get options
my $oligoLength;
GetOptions( 
'n=s' => \$oligoLength,
);

#check options, set defaults
die $USAGE if @ARGV == 0;
$oligoLength = $oligoLength ? $oligoLength : 4;

#count tetranucleotide frequencies
foreach my $sequenceFile (@ARGV) {
	die ("ERROR - could not open input file at $sequenceFile") unless open(IN, "<$sequenceFile");
	my $seqName = "Unnamed Sequence";
	while (my $line = <IN>) {
		if ($line =~ /^>(.+)$/) {
			$seqName = exists $count{$seqName} ? $sequenceFile . "-" . $seqName : $1;
			next;
		}
		$line =~ s/\s//g;
		$line = lc($line);
		$line =~ s/[^a|t|c|g]//g;	
		while ($line =~ /(.{$oligoLength})/g) {
			++$count{$seqName}{$1};
		}
	}
	close IN;
}

#report
foreach my $seqName (keys(%count)) {
	print "\n\nSEQUENCE: $seqName";
	foreach my $oligo (keys(%{$count{$seqName}})) {
		print "\n$oligo\t$count{$seqName}{$oligo}";
	}
}
