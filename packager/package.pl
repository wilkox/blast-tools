#!/usr/bin/perl

#takes a list of sample files and packages them for 
# blasting on a remote server, generating scripts on the fly

#written by david wilkins <david@wilkox.org>
#lives at https://github.com/wilkox/blast-tools

#this software is released into the public domain. To the extent 
# possible under law, all copyright and related or neighboring
# rights are waived and permission is explicitly and irrevocably
# granted to copy, modify, adapt, sell and distribute this software
# in any way you choose.

$USAGE = q/package.pl

Call package.pl with a desired number of reads per package, and a list of sample files. For example:

package.pl 2500 mySample1.fasta mySample2.fasta

Make sure a submission script template called template.sh is in the working directory.

/;

#print warning
print STDERR "\nIMPORTANT - paths to samples and outputs will be set relative to the root directory of the packager, i.e. the one containing a-package, b-package etc. Make sure your submission script template reflects this.\n";

#read in the template
die $USAGE unless -e "template.sh";
$template = `cat template.sh`;

#get sample files
@sampleFiles = @ARGV;
$readsPerPackage = shift(@sampleFiles); #set this to the desired value
die $USAGE unless $readsPerPackage =~ /^\d+$/;
die $USAGE if @sampleFiles == 0;

#go through each sample in order, splitting into sample packages and creating scripts
foreach $sampleFile (@sampleFiles) {

	#get name of sample
	$sampleFile =~ /\/*([^\/]+)$/;
	my $sampleName = $1;
	$sampleName =~ s/\..+//g;
	print STDERR "\nprocessing $sampleName...";

	#go through sample and create packages
	die ("\nERROR - could not open sample at $sampleFile") unless open(SAMPLE, "<$sampleFile");

	#create the dir for the first package
	my $i = "a";
	push(@packageMade, $i);
	unless (-d "$i-package") {
		system("mkdir $i-package");
	}
	unless (-d "$i-package/fastas") {
		system("mkdir $i-package/fastas");
	}
	unless (-d "$i-package/scripts") {
		system("mkdir $i-package/scripts");
	}
	unless (-d "$i-package/output") {
		system("mkdir $i-package/output");
	}

	#begin writing package
	die ("ERROR - could not create sample package file at $i-package/fastas/$i-$sampleName.fasta") unless open(OUT, ">$i-package/fastas/$i-$sampleName.fasta");
	my $readCount;
	while (my $line = <SAMPLE>) {
		++$readCount if $line =~ /^>/;
		if ($readCount == $readsPerPackage) {

			#close the old package
			close OUT;
			$readCount = 0;
			
			#using the template, create a submission script for the package
			my $script = $template;
			$script =~ s/INPUT/$i-package\/fastas\/$i-$sampleName.fasta/;
			$script =~ s/OUTPUT/$i-package\/output\/$i-$sampleName.output/;
			die ("ERROR - could not write script for package $i, sample $sampleName at $i-package/scripts/$i-$sampleName.sh") unless open(SC, ">$i-package/scripts/$i-$sampleName.sh");
			print SC $script;
			close SC;

			#start a new package
			++$i;
			push(@packageMade, $i);
			unless (-d "$i-package") {
				system("mkdir $i-package");
			}
			unless (-d "$i-package/fastas") {
				system("mkdir $i-package/fastas");
			}
			unless (-d "$i-package/scripts") {
				system("mkdir $i-package/scripts");
			}
			unless (-d "$i-package/output") {
				system("mkdir $i-package/output");
			}
			die ("ERROR - could not create sample package file at $i-package/fastas/$i-$sampleName.fasta") unless open(OUT, ">$i-package/fastas/$i-$sampleName.fasta");
		}
		print OUT $line;
	}

	#close the last package
	close OUT;
	
	#using the template, create a submission script for the last package
	my $script = $template;
	$script =~ s/INPUT/$i-package\/fastas\/$i-$sampleName.fasta/;
	$script =~ s/OUTPUT/$i-package\/output\/$i-$sampleName.output/;
	die ("ERROR - could not write script for package $i, sample $sampleName at $i-package/scripts/$i-$sampleName.sh") unless open(SC, ">$i-package/scripts/$i-$sampleName.sh");
	print SC $script;
	close SC;

	#close out the sample
	close SAMPLE;
}

#build an index
print STDERR "\nBuilding a package index...";
die ("ERROR - could not create index file index.dat") unless open(INDEX, ">index.dat");
foreach (@packageMade) {
	next if exists $indexed{$_};
	$indexed{$_} = "";
	print INDEX "Q\t$_-package\n";
}
close INDEX;

#commit changes
print STDERR "\nCommitting all changes to the repository.";
print STDERR "\n[svn add * --force; svn commit -m 'packaging completed']\n";
system("svn add * --force; svn commit -m 'packaging completed'");
