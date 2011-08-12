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
	my $prepend = "";
	while (my $line = <IN>) {
		if ($line =~ /^>(.+)$/) {
			$seqName = $1;
			next;
		}

		$line =~ s/\s//g;
		$line = lc($line);
		$line =~ s/[^a|t|c|g]//g;
		$line = $prepend . $line;

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
