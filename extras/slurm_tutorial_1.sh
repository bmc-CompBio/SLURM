#! /bin/bash

### run bowtie serially (one thread) ## tabkes 56 minutes
cat > bowtie1_not_parallel.sh << EOF
#!/bin/bash
#SBATCH --job-name="bowtie_serial"
#SBATCH --nodes=1
#SBATCH --output="bowtie_serial.out"

module load ngs/bowtie1
bowtie_opts="-p 1"
bowtie /work/data/genomes/human/Homo_sapiens/NCBI/GRCh38/Sequence/BowtieIndex/genome \${bowtie_opts} \$1 > \$1.bowtie_out
EOF

jid1=$(sbatch --parsable bowtie1_not_parallel.sh luci_2.fastq)
scontrol show jobid -dd $jid1
sacct -j $jid1 --format="AllocCPUs,AllocNodes,MaxRSS,Elapsed"


### run bowtie parallely (16 threads)  ## takes 4 minutes
cat > bowtie1_parallel.sh << EOF
#!/bin/bash
#SBATCH --job-name="bowtie_parallel"
#SBATCH --nodes=1
#SBATCH --output="bowtie_parallel.out"
#SBATCH --ntasks-per-node=16

module load ngs/bowtie1
bowtie_opts="-p 16"
bowtie /work/data/genomes/human/Homo_sapiens/NCBI/GRCh38/Sequence/BowtieIndex/genome \${bowtie_opts} \$1 > \$1.bowtie_out
EOF

jid2=$(sbatch --parsable bowtie1_parallel.sh luci_2.fastq)
scontrol show jobid -dd $jid2
sacct -j $jid2 --format="AllocCPUs,AllocNodes,MaxRSS,Elapsed"

### run bowtie parallely (16 threads) limit memory
cat > bowtie1_parallel_mem.sh << EOF
#!/bin/bash
#SBATCH --job-name="bowtie_parallel"
#SBATCH --nodes=1
#SBATCH --output="bowtie_parallel.out"
#SBATCH --ntasks-per-node=16
#SBATCH --ntasks-per-node=16
#SBATCH --mem 3000

module load ngs/bowtie1
bowtie_opts="-p 16"
bowtie /work/data/genomes/human/Homo_sapiens/NCBI/GRCh38/Sequence/BowtieIndex/genome \${bowtie_opts} \$1 > \$1.bowtie_out
EOF

jid3=$(sbatch --parsable bowtie1_parallel_mem.sh luci_2.fastq)
scontrol show jobid -dd $jid3
sacct -j $jid3 --format="AllocCPUs,AllocNodes,MaxRSS,Elapsed"

### run bowtie parallely (16 threads) not enough memory
## slurmstepd: error: Job 56478 exceeded memory limit (2487652 > 2048000), being killed
## slurmstepd: error: Exceeded job memory limit
## slurmstepd: error: *** JOB 56478 ON slim01 CANCELLED AT 2017-11-24T13:47:48 ***
cat > bowtie1_parallel_mem.sh << EOF
#!/bin/bash
#SBATCH --job-name="bowtie_parallel"
#SBATCH --nodes=1
#SBATCH --output="bowtie_parallel.out"
#SBATCH --ntasks-per-node=16
#SBATCH --ntasks-per-node=16
#SBATCH --mem 2000

module load ngs/bowtie1
bowtie_opts="-p 16"
bowtie /work/data/genomes/human/Homo_sapiens/NCBI/GRCh38/Sequence/BowtieIndex/genome \${bowtie_opts} \$1 > \$1.bowtie_out
EOF

jid4=$(sbatch --parsable bowtie1_parallel_mem.sh luci_2.fastq)
scontrol show jobid -dd $jid4
sacct -j $jid4 --format="AllocCPUs,AllocNodes,MaxRSS,Elapsed"
