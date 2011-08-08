#!/usr/bin/perl

#generate a binned coverage plot for blast hits on a full genome

#version 0.2

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
plot_coverage.pl	-r <filename> Reference genome in fasta format.
			-b <filename> Blast output, in -m8 hit table format. You may plot multiple samples by using the -b flag multiple times, e.g. "-b firstsample.blast_output -b secondsample.blast_output". The coverage maps for the different samples will be displayed on the sample plot, overlayed in different colours. A maximum of 5 different samples can be displayed on the same plot.
			-p <string> Prefix for output files.
			-w <integer> Window size for binning. A window size of 0 will simply plot base-by-base coverage.
			-i <number> Plot width, in inches.
			-h <number> Plot height, in inches.

OPTIONAL:		-f <filename> Features file: a comma-separated file, one feature per line, fields [start pos] [end pos] [colour] [feature name]. If no colour is specified, default is firebrick. If no feature name is specified, default is blank.
			-d Instead of plotting coverage, plot %identity;
			-y Plot the y axis on a log scale.
/;

#get and check options
use Getopt::Long;
GetOptions (
'r=s' => \$reference_genome,
'b=s' => \@blast_output,
'p=s' => \$output_prefix,
'w=i' => \$window_size,
'i=s' => \$plot_width,
'h=s' => \$plot_height,
'f=s' => \$features_file,
'd!' => \$plot_identity,
'y!' => \$logY,
) or die $USAGE;
die $USAGE if !$reference_genome or @blast_output == 0 or !$output_prefix or !$window_size or !$plot_height or !$plot_width;
print STDERR "\nNOTE - plotting %ID, not coverage!\n" if $plot_identity == 1;
die ("ERROR - a maximum of 5 different samples can be displayed on the same plot") if @blast_output > 5;
print STDERR "IMPORANT - you have specified a log scale, but you're plotting \%identity, not coverage. Make sure this is what you want to do!" if $logY && $plot_identity;

##BODY
&get_length_of_reference_genome;
&get_coverage;
&do_moving_window_average;
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

sub get_coverage {

	#loop over multiple blast outputs
	my $coverageTotal;
	foreach $blast_output (@blast_output) {

		my $coverageTotal;

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
			my $percentidentity = @line[2] if $plot_identity == 1;
			
			#make sure the start and end positions exist and are numbers
			die ("ERROR - malformed line in blast output $blast_output at line $.\n") unless $startpos =~ /^\d+$/ && $endpos =~ /^\d+$/;

			#foreach base i in the reference genome, increment its coverage count and %id count if needed
			for ($i = $startpos; $i <= $endpos; ++$i) {
				++$coverage{$blast_output}{$i};
				++$coverageTotal;
				$percentidentity{$blast_output}{$i} += $percentidentity if $plot_identity == 1;
			}
		}

		close BLAST;

		my $coverageMean = $coverageTotal / $reference_genome_length;
		print STDERR "\nMEAN COVERAGE FOR $blast_output: $coverageMean";
	}

	my $coverageMean = $coverageTotal / $reference_genome_length;
	print STDERR "\nMEAN COVERAGE: $coverageMean";
}

sub do_moving_window_average {

	#loop over multiple blast outputs
	foreach $blast_output (@blast_output) {

		print STDERR "\nComputing moving window average for $blast_output...";

		for ($i = 1; $i <= $reference_genome_length; $i += $window_size) { 
			undef $n;
			undef $sum;
			for ($j = 1; $j <= $window_size; ++$j) {
				my $pos_to_count = $i - $j;
				if ($plot_identity == 1) {
					next unless exists $coverage{$blast_output}{$pos_to_count};
					my $pos_average = $percentidentity{$blast_output}{$pos_to_count} / $coverage{$blast_output}{$pos_to_count};
					$sum += $pos_average;
					++$n;
				} else {
					next unless exists $coverage{$blast_output}{$pos_to_count};
					$sum += $coverage{$blast_output}{$pos_to_count};
					++$n;
				}
			}
			if ($n == 0) {
				$window_average{$blast_output}{$i} = 0;
				next;
			}
			$window_average{$blast_output}{$i} = $sum / $n;
			$maxCoverage = $sum / $n unless $maxCoverage >= $sum / $n;
		}

	}
}

sub draw_plot {
	
	print STDERR "\nWriting values to temporary file plotfile.tmp for plotting...";

	#each of multiple blast outputs gets a seperate plotfile
	my $j = 0;
	foreach $blast_output (@blast_output) {

		die ("ERROR - could not create temporary plotfile plotfile.tmp\n") unless open(PLOT, ">$j-plotfile.tmp");
		print PLOT "\"pos\",\"value\"";

		for ($i = 1; $i <= $reference_genome_length; $i += $window_size) { 
			if ($logY && ! $window_average{$blast_output}{$i} == 0) {
				my $log = log($window_average{$blast_output}{$i});
				print PLOT "\n$i,$log";
			} else {
				print PLOT "\n$i,$window_average{$blast_output}{$i}";
			}
		}

		close PLOT;
		++$j;
	}

	#generate R script
	print STDERR "\nWriting R script to R.tmp...";
	my $script;
	die ("ERROR - cannot create R script at R.tmp\n") unless open(R, ">R.tmp");

	#R: read in plotfiles for each blast output
	my $j = 0;
	foreach $blast_output (@blast_output) {
		$script .= <<EOF;
coverage$j = read.csv("$j-plotfile.tmp", head=TRUE)
EOF
		++$j;
	}

	#R: initialise the pdf output
	$script .= <<EOF;
pdf("$output_prefix.pdf", width = $plot_width, height = $plot_height)
EOF

	#R: set up seperate par row for features if needed
	unless (!$features_file) { #unless no features file has been specified
		$script .= <<EOF;
par(mfrow = c(2,1))
EOF
	}
	
	#R: set plot title and initialise plot area
	if ($plot_identity == 1) {
		$plot_title = "% ID";
	} else {
		if ($logY) {
			$plot_title = "ln(Coverage)";
		} else {
			$plot_title = "Coverage";
		}
	}
	my $ylim = $maxCoverage * 1.4;
	if ($logY) {
		$ylim = log($ylim);
	}
	my $yAxis;
	$script .= <<EOF;
par(xpd=TRUE)
plot(coverage0\$pos, coverage0\$value, type="n", ylab = c("$plot_title"), xlab = c(""), xlim=c(0, $reference_genome_length), ylim=c(0, $ylim)$yAxis)
EOF

	#R: draw a polygon representing coverage for each blast output
	my @rcolours = qw(#104E8B70 #B2222270 #228B2270 #8B0A5070 #CDAD0070);
	my $j = 0;
	foreach $blast_output (@blast_output) {
		$script .= <<EOF;
polygon_coords = rbind(coverage$j, c($reference_genome_length, 0), c(0,0))
polygon(polygon_coords, col=c("@rcolours[$j]"), lty=0)
EOF
	++$j;
	}

	#R: add a legend to the coverage plot
	my $legendText;
	my $legendCols;
	my $j = 0;
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
EOF

	#R: draw on the features
	if (!$features_file) {
		$script .= <<EOF;
dev.off()
EOF
	} else {

		$script .= <<EOF;
plot(1, type="n", axes=F, xlim = c(0, $reference_genome_length), ylim = c(0, 10), ylab = "", xlab = "")
EOF

		print STDERR "\nAdding features...";
		die ("ERROR - could not open features in $features_file\n") unless open(FEATURES, "<$features_file");
			while ($line = <FEATURES>) {
				chomp $line;
				my @fields = split(/,/, $line);
				die ("ERROR - malformed features line on line $. of $features_file - all lines should have four fields - if you want to leave a field empty, you still have to put in commas to show it's there\n") unless @fields == 4;
				if (@fields[0] < @fields[1]) {
					&draw_arrow_f(@fields);
				} else {
					&draw_arrow_r(@fields);
				}
			}
		close FEATURES;
		$script .= <<EOF;
dev.off()
EOF

	}
	print R $script;
	close R;

	#execute R script
	print STDERR "\nExecuting R script...";
	system("R --no-save < R.tmp");

}

sub draw_arrow_f {
	@fields = @_;

	$start_pos = @fields[0];
	$end_pos = @fields[1];
	$gene_label = @fields[3];
	
	$arrow_pos = ($end_pos - $start_pos) * 0.8 + $start_pos;
	$text_pos = ($end_pos - $start_pos) * 0.5 + $start_pos;
	if (@fields[2] eq "") {
		$arrow_colour = "firebrick";
	} else {
		$arrow_colour = @fields[2];
	}

	$script .= <<EOF;
draw_me = rbind(
c($start_pos,7),
c($arrow_pos,7),
c($arrow_pos,10),
c($end_pos,5),
c($arrow_pos,0),
c($arrow_pos,3),
c($start_pos,3),
c($start_pos,7)
)

polygon(draw_me, col=c("$arrow_colour"), lty=1, xpd=NA)
text($text_pos, 0, pos=1, labels=c("$gene_label"), xpd=NA)
EOF

}

sub draw_arrow_r {

	@fields = @_;

	$start_pos = @fields[0];
	$end_pos = @fields[1];
	$gene_label = @fields[3];
	
	$arrow_pos = ($start_pos - $end_pos) * 0.2 + $end_pos;
	$text_pos = ($start_pos - $end_pos) * 0.5 + $end_pos;
	if (@fields[2] eq "") {
		$arrow_colour = "firebrick";
	} else {
		$arrow_colour = @fields[2];
	}

	$script .= <<EOF;
draw_me = rbind(
c($end_pos,5),
c($arrow_pos, 10),
c($arrow_pos, 7),
c($start_pos, 7),
c($start_pos, 3),
c($arrow_pos, 3),
c($arrow_pos, 0),
c($end_pos,5)
)

polygon(draw_me, col=c("$arrow_colour"), lty=1, xpd=NA)
text($text_pos, 0, pos=1, labels=c("$gene_label"), xpd=NA)
EOF
}
