#!/usr/bin/perl

use warnings;

#generate a percent identity scatterplot for blast hits on a full genome
#written by david wilkins <david@wilkox.org>
#lives at https://github.com/wilkox/blast-tools

#this software is released into the public domain. To the extent 
# possible under law, all copyright and related or neighboring
# rights are waived and permission is explicitly and irrevocably
# granted to copy, modify, adapt, sell and distribute this software
# in any way you choose.

#test that the user has R installed and available
my $Rversion = `R --version`;
unless ($Rversion =~ /R\sversion/) {
	print "\nYou must have R installed and available to use this program.";
	exit;
}

$USAGE = q/USAGE:
plot_percent_identity.pl 
        -r <filename> Reference genome in fasta format.
        -b <filename> Blast output, in -m8 hit table format. You may plot multiple samples by using the -b flag multiple times, e.g. "-b firstsample.blast_output -b secondsample.blast_output". The percent identity maps for the different samples will be displayed on the sample plot, overlayed in different colours. A maximum of 5 different samples can be displayed on the same plot.
        -p <string> Prefix for output files.
        -i <number> Plot width, in pixels
        -h <number> Plot height, in pixels
/;

#get and check options
use Getopt::Long;
GetOptions (
'r=s' => \$reference_genome,
'b=s' => \@blast_output,
'p=s' => \$output_prefix,
'i=s' => \$plot_width,
'h=s' => \$plot_height,
) or die $USAGE;
die $USAGE if !$reference_genome or @blast_output == 0 or !$output_prefix or !$plot_height or !$plot_width;
die ("ERROR - a maximum of 5 different samples can be displayed on the same plot") if @blast_output > 5;

##BODY
&get_length_of_reference_genome;
&get_percent_identity;
&draw_plot;
exit;
##END BODY

##SUBS

#get the length of the reference genome
sub get_length_of_reference_genome {

	print STDERR "\nCalculating length of reference genome...";

	die ("ERROR - could not open reference genome $reference_genome\n") unless open(REFERENCE, "<$reference_genome");
	while ($line = <REFERENCE>) {
		chomp $line;
		next if $line =~ /^>/;
		$reference_genome_length += length($line);
	}
	
	print STDERR "\nReference genome has length: $reference_genome_length";
	close REFERENCE;
}

sub get_percent_identity {

	#loop over multiple blast outputs
	foreach $blast_output (@blast_output) {

		die ("ERROR - could not open blast output $blast_output\n") unless open(BLAST, "<$blast_output");
		print STDERR "\n";

		while ($line = <BLAST>) {

			print STDERR "\nProcessed $. lines of $blast_output..." if $. % 10000 == 0;

			#get the start and end positions of the hit
			chomp $line;
			my @line = split(/\s+/, $line);
			my @positions = (@line[8], @line[9]);
			my @sorted = sort {$a <=> $b} (@positions);
			my $startpos = @sorted[0];
			my $endpos = @sorted[1];
			my $percentidentity = @line[2];
      $maxID = $percentidentity unless $maxid >= $percentidentity;
      $read{$blast_output}{$.}{'startpos'} = $startpos; 
      $read{$blast_output}{$.}{'endpos'} = $endpos;  
      $read{$blast_output}{$.}{'percentidentity'} = $percentidentity;  
			
			#make sure the start and end positions exist and are numbers
			die ("ERROR - malformed line in blast output $blast_output at line $.\n") unless $startpos =~ /^\d+$/ && $endpos =~ /^\d+$/;

		}

		close BLAST;
	}
}

sub draw_plot {
	
	print STDERR "\nWriting values to temporary file plotfile.tmp for plotting...";

	#each of multiple blast outputs gets a seperate plotfile
	my $j = 0;
	foreach $blast_output (@blast_output) {

		die ("ERROR - could not create temporary plotfile plotfile.tmp\n") unless open(PLOT, ">$j-plotfile.tmp");
		print PLOT "\"pos\",\"value\"";

		for ($i = 1; $i <= $reference_genome_length; ++$i) { 
      print PLOT "\n$i,$window_average{$blast_output}{$i}";
		}

		close PLOT;
		++$j;
	}

	#generate R script
	print STDERR "\nWriting R script to R.tmp...";
	die ("ERROR - cannot create R script at R.tmp\n") unless open(R, ">R.tmp");
	our $script;
	$script .= <<EOF;
library("maptools")
EOF

	#R: initialise the png output
  $script .= <<EOF;
png("$output_prefix.png", width = $plot_width, height = $plot_height)
EOF

	#R: set plot title and initialise plot area
  $plot_title = "% ID";
  my $ylim = 100;
	my $yAxis;
	$script .= <<EOF;
par(xpd=TRUE)
myx=c(1,2)
myy=c(3,4)
plot(myx, myy, type="n", ylab = c("$plot_title"), xlab = c(""), xlim=c(0, $reference_genome_length), ylim=c(0, $ylim)$yAxis)
EOF

	#R: draw a line for each read
	my @rcolours = qw(#104E8B70 #B2222270 #228B2270 #8B0A5070 #CDAD0070);
	$j = 0;
  foreach my $blast_output (@blast_output) {
    my $k = 1;
    foreach my $readid (keys (%{$read{$blast_output}})) {
      $script .= <<EOF;
lines(c($read{$blast_output}{$readid}{'startpos'}, $read{$blast_output}{$readid}{'endpos'}), c($read{$blast_output}{$readid}{'percentidentity'}, $read{$blast_output}{$readid}{'percentidentity'}), col=c("@rcolours[$j]"))
EOF
    }
  ++$j;
  }
#R: add a legend to the coverage plot my $legendText;
	my $legendCols;
	$j = 0;
	foreach $blast_output (@blast_output) {
		$legendText .= "\"$blast_output\",";
		$legendCols .= "\"@rcolours[$j]\",";
		++$j;
	}
	chop $legendText;
	chop $legendCols;
	$script .= <<EOF;
legendtext = c($legendText)
legendcols = c($legendCols)
legend(c("topright"), legend=legendtext, fill=legendcols)
dev.off()
EOF

	#execute R script
	print R $script;
	close R;
	print STDERR "\nExecuting R script...";
	system("R --no-save < R.tmp");

}
