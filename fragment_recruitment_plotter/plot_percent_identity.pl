#!/usr/bin/perl

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
        -b <filename> Blast output, in -m8 hit table format.
        -p <string> Prefix for output files.
        -i <number> Plot width, in pixels
        -h <number> Plot height, in pixels

OPTIONAL:
        -e <E-value> To colour reads by E-value, specify up to 6 evalue thresholds with -e. For example, if you run plot_percent_identity.pl with "-e 1 -e 1e-3", reads will be binned into three differently coloured groups: E-value >= 1; 1 > E-value >= 1e-3; 1e-3 > E-value.
/;

#get and check options
use Getopt::Long;
GetOptions (
'r=s' => \$reference_genome,
'b=s' => \$blast_output,
'p=s' => \$output_prefix,
'i=s' => \$plot_width,
'h=s' => \$plot_height,
'e=s' => \@evalues,
) or die $USAGE;
die $USAGE if !$reference_genome or !$blast_output or !$output_prefix or !$plot_height or !$plot_width;
die $USAGE if @evalues > 6;

#set palette for point colouring
my @Rcolours = qw(cadetblue1 dodgerblue4 blue3 darkslateblue darkorchid firebrick1 red);

##BODY
my $maxID = 0;
my @sortedEvalues;
&get_length_of_reference_genome;
&get_percent_identity;
&colourise_reads if @evalues > 0;
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

  die ("ERROR - could not open blast output $blast_output\n") unless open(BLAST, "<$blast_output");
  print STDERR "\n";

  while ($line = <BLAST>) {
    print STDERR "\nProcessed $. lines of $blast_output..." if $. % 10000 == 0;

    #get the start and end positions of the hit
    chomp $line;
    my @line = split(/\s+/, $line);
    my @positions = ($line[8], $line[9]);
    my @sorted = sort {$a <=> $b} (@positions);
    my $startpos = $sorted[0];
    my $endpos = $sorted[1];
    my $percentidentity = $line[2];
    $maxID = $maxID > $percentidentity ? $percentidentity : $maxID;
    $read{$line[0]}{'startpos'} = $startpos; 
    $read{$line[0]}{'endpos'} = $endpos;  
    $read{$line[0]}{'percentidentity'} = $percentidentity;  
    $read{$line[0]}{'evalue'} = @line[10];
    $read{$line[0]}{'colour'} = @Rcolours[0];
    
    #make sure the start and end positions exist and are numbers
    die ("ERROR - malformed line in blast output $blast_output at line $.\n") unless $startpos =~ /^\d+$/ && $endpos =~ /^\d+$/;
  }

  close BLAST;
}

sub draw_plot {

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

  #R: add a second plot cell to put the 
  #legend in, if there is one
  if (@evalues) {
    $script .= <<EOF;
layout(matrix(c(1,2), nrow = 1), widths = c(0.7, 0.3))
EOF
  }

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
	$j = 0;
  my $k = 1;
  foreach my $readid (keys (%read)) {
    $script .= <<EOF;
lines(c($read{$readid}{'startpos'}, $read{$readid}{'endpos'}), c($read{$readid}{'percentidentity'}, $read{$readid}{'percentidentity'}), col=c("$read{$readid}{'colour'}"))
EOF
  }

  #R: add a legend if reads are colourised by E-value
  &add_evalue_legend if @evalues > 0;

  #R: close device
  $script .= <<EOF;
dev.off()
EOF

	#execute R script
	print R $script;
	close R;
	print STDERR "\nExecuting R script...";
	system("R --no-save < R.tmp");

}

#colourise the reads if an evalue threshold has been set
sub colourise_reads {

  #sort the evalues
  @sortedEvalues = sort(@evalues);
  
  #for each evalue, colour all reads below that value
  my $colourIndex = 1;
  foreach my $evalue (@sortedEvalues) {
    foreach my $readid (keys(%read)) {
      $read{$readid}{'colour'} = @Rcolours[$colourIndex] if $read{$readid}{'evalue'} < $evalue;
    }
    ++$colourIndex;
  }
}

#add a legend for e-value thresholds
sub add_evalue_legend {

  my $legendCols = "\"@Rcolours[0]\"";
  my $legendText = "\"E-value >= @sortedEvalues[0]\"";

  my $i = 0;
  foreach my $evalue (@sortedEvalues) {
    next if $evalue eq @sortedEvalues[0];
    ++$i;
    $legendCols .= ", \"@Rcolours[$i]\"";
    my $j = $i - 1;
    $legendText .= ", \"@sortedEvalues[$j] > E-value >= $evalue\"";
  }

  $script .= <<EOF;
par(mar = c(5, 0, 4, 2) + 0.1)
plot(1:3, rnorm(3), pch = 1, lty = 1, ylim=c(-2,2), type = "n", axes = FALSE, ann = FALSE)
legendtext = c($legendText)
legendcols = c($legendCols)
legend(c("topright"), legend=legendtext, fill=legendcols)
EOF
}
