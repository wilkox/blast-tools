#!/usr/bin/perl

#reconstruct the output of a blast job run on a remote server in chunks with packager

#written by david wilkins <david@wilkox.org>
#lives at https://github.com/wilkox/blast-tools

#this software is released into the public domain. To the extent 
# possible under law, all copyright and related or neighboring
# rights are waived and permission is explicitly and irrevocably
# granted to copy, modify, adapt, sell and distribute this software
# in any way you choose.

#make sure the local working copy is up to date
print STDERR "\nMaking sure your local working copy is up to date.";
print STDERR "\n[svn update]\n";
system("svn update");

#read in the index
die ("ERROR - cannot read index file index.dat") unless open(INDEX, "<index.dat");
while ($line = <INDEX>) {
	chomp $line;
	$line =~ /^([R|Q|C])\t(.+)/;
	die ("ERROR - it looks like package $2 is not yet complete. Don't run reconstruct.pl until all packages are complete!") unless $1 eq "C";
	push(@packages, $2);
}
close INDEX;

#create a directory for the reconstructed outputs
unless (-d "reconstructed") {
	print STDERR "\n[mkdir reconstructed]\n";
	system("mkdir reconstructed");
}

#go through each package and reconstruct the outputs
foreach $package (@packages) {
		
	#make sure the output files are available
	unless (-d "$package") {
		print STDERR "\nIt looks like you don't have a local copy of $package. Running svn update to retrieve it.";
		print STDERR "\n[svn update --set-depth empty $package]";
		system("svn update --set-depth empty $package");
	}
	unless (-d "$package/output") {
		print STDERR "\nIt looks like you don't have a local copy of $package/output. Running svn update to retrieve it.";
		print STDERR "\n[svn update --set-depth infinity $package/output";
		system("svn update --set-depth infinity $package/output");
	}

	#identify and go through the output files
	my $outputs = `find $package/output -type f| grep -v svn`;
	my @outputs = split(/\s+/, $outputs);
	$package =~ /^(.+)-package$/;
	my $packageID = $1;
	print "\npackage id is $1";
	foreach $output (@outputs) {
		$output =~ /^$package\/output\/$packageID-(.+)\.output$/;
		system("cat $output >> reconstructed/$1.output");
	}
}

print STDERR "\nReconstruction done.";
