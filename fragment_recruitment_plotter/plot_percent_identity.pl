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
/;

#get and check options
use Getopt::Long;
GetOptions (
'r=s' => \$reference_genome,
'b=s' => \$blast_output,
'p=s' => \$output_prefix,
'i=s' => \$plot_width,
'h=s' => \$plot_height,
) or die $USAGE;
die $USAGE if !$reference_genome or !$blast_output or !$output_prefix or !$plot_height or !$plot_width;

##BODY
my $maxID = 0;
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
    $read{$blast_output}{$line[0]}{'startpos'} = $startpos; 
    $read{$blast_output}{$line[0]}{'endpos'} = $endpos;  
    $read{$blast_output}{$line[0]}{'percentidentity'} = $percentidentity;  
    $read{$blast_output}{$line[0]}{'colour'} = &colour_for($line[10]);
    
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
  foreach my $readid (keys (%{$read{$blast_output}})) {
    $script .= <<EOF;
lines(c($read{$blast_output}{$readid}{'startpos'}, $read{$blast_output}{$readid}{'endpos'}), c($read{$blast_output}{$readid}{'percentidentity'}, $read{$blast_output}{$readid}{'percentidentity'}), col=c("$read{$blast_output}{$readid}{'colour'}"))
EOF
  }

  #add a legend
  my $legendCols = q/"cadetblue1", "dodgerblue4", "blue3", "darkslateblue", "darkorchid1", "firebrick1", "red"/;
  my $legendText = q/"E-value >= 1", "E-value 0.1 - 1", "E-value 0.01 - 0.1", "E-value 0.001 - 0.01", "E-value 0.0001 - 0.001", "E-value 0.00001 - 0.0001", "E-value < 0.00001"/;
  $script .= <<EOF;
legendtext = c($legendText)
legendcols = c($legendCols)
legend(c("topright"), legend=legendtext, fill=legendcols)
EOF

  #close device
  $script .= <<EOF;
dev.off()
EOF

	#execute R script
	print R $script;
	close R;
	print STDERR "\nExecuting R script...";
	system("R --no-save < R.tmp");

}

#return the R colour for a particular evalue
sub colour_for {

  my $eval = $_[0];
  
  return "cadetblue1" if $eval >= 1;
  return "dodgerblue4" if $eval < 1 && $eval >= 0.1;
  return "blue3" if $eval < 0.1 && $eval >= 0.01;
  return "darkslateblue" if $eval < 0.01 && $eval >= 0.001;
  return "darkorchid" if $eval < 0.001 && $eval >= 0.0001;
  return "firebrick1" if $eval < 0.0001 && $eval >= 0.00001;
  return "red" if $_[0] < 0.00001;
}
