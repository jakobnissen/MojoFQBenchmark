# JuliaFQBenchmark

This is the git repo for the Julia implementation mentioned in the blog post https://viralinstruction.com/posts/mojo/

### How to run:
* Download and install [Julia](https://julialang.org/downloads/)
* Download the FASTQ file `M_abscessus_HiSeq.fq` from [the biofast benchmark page](https://github.com/lh3/biofast/releases/tag/biofast-data-v1)
* In the shell, navigate to the directory of this repo
* Launch Julia in the current project: `julia --startup-file=no --project=.`
* Load the package: `using FQ`
* Time with `@time FQ.benchmark("/path/to/M_abscessus_HiSeq.fq")`
* Run a few times and get the mean result

The timings in the blog post were obtained with:
* Julia version: 1.10.0
* Manjaro Linux with Linux version 5.15.146
* CPU: AMD Ryzen 7 4700U
* Disk: Intel SSDPEKNW010T8
