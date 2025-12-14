. /opt/spack/main/env.sh


module load julia


#!/bin/bash
source ../newPysrEnv/bin/activate

for r in {0..30}
do
	for vf in "01" "02" "03" "04" "05" "06"
	do
		srun --mem=10G --partition=members --job-name="AIFL"  julia varyingRe_exp_AIFL.jl $vf 0 $r >&1 &
	done
done

for r in {11..30}
do
	for Re in 0 1 5 10 50 100 200 300 
	do
		srun --mem=10G --partition=members --job-name="AIFL"  julia varyingRe_exp_AIFL.jl "00" $Re $r >&1 &
	done
done

