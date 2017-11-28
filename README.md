# Introduction to parallel processing and SLURM on the BMC cluster

## 1) the basics - serial versus parallel bowtie alignment

Sequence processing by most short read aligners can be distributed over more than one processor (core). This will lead to a significant, proportional reduction of processing time. The number of parallel processes (aka threads) to be used needs to be specified when running the aligner. In bowtie, e.g, the parameter `-p` specifies this number. 

I first run an alignment job on a fastq file - test.fastq - without parallel processing (`-p 1`). On a cluster such a 'job' should be distributed to one of the computation nodes and not be run on the master. Therefore I wrap the execution code in some bash shell script file that can be delivered to the job scheduling system SLURM (Please have a look at <https://slurm.schedmd.com> for a full description)

This is the batch script file `bowtie_job.sh` that contains the commands to be executed by the computation node

	#!/bin/bash
	
	module load ngs/bowtie1
	
	bowtie_index=/work/data/genomes/human/Homo_sapiens/NCBI/GRCh38/Sequence/BowtieIndex/genome
	
	bowtie ${bowtie_index} -p 1 test.fastq > test.bowtie_out

This script is submitted to job scheduling (SLUMR) using the command `sbatch`. As I did not provide any more parameters/details to the sbatch command the job will be executed based on default SLURM job resource allocation, i.e. the job queue to be used, the number of servers (aka 'nodes'), processor cores, RAM to be used. 

	sbatch bowtie_job.sh

Successful job submission will reveal a SLURM job id on standard out. In this examples the id is 56558.

	> Submitted batch job 56558

Look at the jobs running which should include your newly submitted one using `squeue`.

Using this id one can get information of the job during (`scontrol`) and after (`sacct`) the run

	scontrol show jobid -dd 56558
	sacct -j 56558 --format="ReqMem,AllocCPUs,MaxRSS,Elapsed"

`sacct` can report many different parameters. The most interesting ones in particular when trying to find out how much resources a job needs are:
	
 Parameter | Description
---------- | ------------
`ReqMem` | requested memory, Mn:per node; Mc:per core in MB
`AllocCPUs ` | requested number of processor cores
`AllocNodes ` | requested number of Nodes
`MaxRSS ` |  maximum amount of memory used at any time by any process in that job
`Elapsed ` | execution time of the job

in the previous case the output might look like 

	   ReqMem  AllocCPUS AllocNodes     MaxRSS    Elapsed 
	---------- ---------- ---------- ---------- ---------- 
	    4025Mc          2          1              00:02:26 
	    4025Mc          2          1   2382912K   00:02:26 

The MaxRSS of about 2.4 GB indicates the maximum memory usage by the process which should be multipled with the number of parallel processed to estimate the total memory requirement of the job. In our case we just have one process so the total memory requirement equals MaxRSS. This is in excess of the requested memory (the default in our case). In the long run one should make sure that the request does not largely exceed the actual requirement.  

One can simply switch to parallel processing in bowtie by changing the parameter `-p 1` to `-p 8`. This will lead to parallel exection of the process in 8 parallel subprocesses (aka 'threads').
In order to get the resources for this parallel execution one has to specifiy for the SLURM engine if more than the defaults are needed. 

There a two ways to do so, either by providing the values as paramters when executing the `sbatch` command or as special instruction lines in the job script file.
Using the latter solution, I added `#SBATCH --ntasks-per-node=8` between line 1 and the first unix command. `#SBATCH`-lines will be parsed by SLURM before execution of the subsequent command. 

	#!/bin/bash
	
	#SBATCH --ntasks=8
	
	module load ngs/bowtie1
	
	bowtie_index=/work/data/genomes/human/Homo_sapiens/NCBI/GRCh38/Sequence/BowtieIndex/genome
	
	bowtie ${bowtie_index} -p 8 test.fastq > test.bowtie_out

most interesting paramters to set are:

 Parameter | alternative | Description
---------- | ----------- | -----------
`--partition=<partition_names>`| `-p`| the job queue to be used (check `sinfo`), defaults to slim16
`--nodes=<minnodes[-maxnodes]>`| `-N`| number of nodes (servers) required for the job, typically 1 if not using MPI applications
`--ntasks=<number>` | `-n` | number of tasks to be executed per job
`--mem-per-cpu=<MB>`| | memory required per allocated CPU (i.e.thread), or specify `--mem`
`--mem=<MB>` | | memory required per node (about -n*-mem-per-cpu), alternatively specify `--mem-per-cpu`
`--time=<time>`| `-t`| time. At present there is not default time limit on the partitions, which means your jobs will not get killed if you do not specify a time. However, in times of heavy usage scheduling your jobs will be facilitated by providing a runtime.


Considering the MaxRSS of 2.4 GB before we can now also define a suitable memory request either on per-CPU basis or the total memory (per node). I prefer the per-node version as you otherwise might miss the hardware limit of the nodes (256 GB on slim16 and slim18). So 8 parallel processes require 8*2.4 GB memory and accordingly I request a total of 20 GB.

	#!/bin/bash
	
	#SBATCH --ntasks=8
	#SBATCH --mem=20000
	
	module load ngs/bowtie1
	
	bowtie_index=/work/data/genomes/human/Homo_sapiens/NCBI/GRCh38/Sequence/BowtieIndex/genome
	
	bowtie ${bowtie_index} -p 8 test.fastq > test.bowtie_out

## 2) next step - running multiple jobs at once

Assuming we do not have just one FASTQ file but many, what are the ways to align them in an efficient way? The aim is to run the jobs parallely to save time, which requires **one job per file**. Of course we could create duplicates of the batch script file. In each of the files we type the name of a different FASTQ file. But this approach is not efficient and prone to mistakes.

One solution is based on passing parameters to job files, in the simplest case passing the file name to the job. Using the `--export` option of `sbatch` variables can be passed by name to the job script. 

Suppose we have ten FASTQ files named test_1.fastq, test_2.fastq and so on, we can dynamically change the job by passing numbers 1 to 10 it.

	--export=i=1 sbatch bowtie_job.sh
	
will pass variable i with the value 1 to the job which should then align test_1.fastq
	
	--export=i=2 sbatch bowtie_job.sh

will pass variable i with the value 2 to the job which should then align test_2.fastq

In order to have the job script considering i we slightly have to modify the code of `bowtie_job.sh`

	#!/bin/bash
	
	#SBATCH --ntasks=8
	#SBATCH --mem=20000
	
	module load ngs/bowtie1
	
	bowtie_index=/work/data/genomes/human/Homo_sapiens/NCBI/GRCh38/Sequence/BowtieIndex/genome
	
	bowtie ${bowtie_index} -p 8 test_${i}.fastq > test_${i}.bowtie_out


now we can run the jobs dynamically
	
	 --export=i=1 sbatch bowtie_job.sh
	 --export=i=2 sbatch bowtie_job.sh
	 --export=i=3 sbatch bowtie_job.sh
	 --export=i=4 sbatch bowtie_job.sh
	 --export=i=5 sbatch bowtie_job.sh
	 --export=i=6 sbatch bowtie_job.sh
	 --export=i=7 sbatch bowtie_job.sh
	 --export=i=8 sbatch bowtie_job.sh
	 --export=i=9 sbatch bowtie_job.sh
	 --export=i=10 sbatch bowtie_job.sh
	 
or, more elegantly,
	
	for i in {1..10}; do sbatch --export=i=${i} bowtie_job.sh; done	 
if only one parameter is to be passed to the job one can also consider issuing an array job

	sbatch --array=1-10 bowtie_job.sh
	
In array jobs a SLURM variable named SLURM_ARRAY_TASK_ID will contain a defined set of values (defined using the `--array` option). accordingly the job script has to be modified

	#!/bin/bash
	
	#SBATCH --ntasks=8
	#SBATCH --mem=20000
	
	module load ngs/bowtie1
	
	bowtie_index=/work/data/genomes/human/Homo_sapiens/NCBI/GRCh38/Sequence/BowtieIndex/genome
	
	bowtie ${bowtie_index} -p 8 test_${SLURM_ARRAY_TASK_ID}.fastq > test_${SLURM_ARRAY_TASK_ID}.bowtie_out


	
<!-- Highlight syntax for Mou.app, insert at the bottom of the markdown document  -->
<script src="http://yandex.st/highlightjs/7.3/highlight.min.js"></script>
<link rel="stylesheet" href="http://yandex.st/highlightjs/7.3/styles/github.min.css">
<script>
  hljs.initHighlightingOnLoad();
</script>
