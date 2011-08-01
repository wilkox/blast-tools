#!/bin/bash
#PBS -A sf-Q91
#PBS -l select=1:ncpus=4
#PBS -q workq
#PBS -l walltime=100:00:00

export PBS_O_WORKDIR=/home/dxw561/kegg_08s-working
cd ${PBS_O_WORKDIR}

module load blast
unset BLASTDB

blastall -a 4 -d /sw/db/KEGG/blast/nucleotides4genesKEGG -i INPUT -p tblastx -o OUTPUT -m 8 -v 10 -b 10 -e 1.0e-03 -G 11 -E 1 -F "m S"
