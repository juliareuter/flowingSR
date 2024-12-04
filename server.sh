. /opt/spack/main/env.sh


module load julia


#!/bin/bash
source ../newPysrEnv/bin/activate

for r in {0..30}
do
	for phi in "005" "01" "02" "03" "04"
	do
		srun --mem=20G --partition=ci --job-name="Stokes_final"  julia finalStokes_exp.jl $phi $r >&1 &
	done
done
