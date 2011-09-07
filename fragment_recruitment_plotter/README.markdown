#About
Visualise BLAST fragment recruitment to a reference genome. 

#Coverage plotter
Plots the read depth across the reference genome, either base-by-base or with a moving window average. Can overlay up to five queries onto a single plot. Also supports basic mapping of features e.g. genes onto the reference genome. Can produce log-scale plot.

#Percent identity plotter
Plots each HIT (not READ) on the reference genome, so make sure you pre-filter your blast output to exactly what you want to plot! Reads can be optionally be coloured by evalue, as with [CAMERA's](http://camera.calit2.net/) fragment recruitment tool.

#Requirements
Requires `perl` and `R`. Written for a linux or other unix-like environment.

#License
This software is released into the public domain. To the extent possible under law, all copyright and related or neighboring rights are waived and permission is explicitly and irrevocably granted to copy, modify, adapt, sell and distribute it in any way you choose.

Attribution to the author would be appreciated but is not required.

#Author
This tool was written by David Wilkins: david@wilkox.org
