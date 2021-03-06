# Distfor: Distance calculations for Conefor

This package contains R scripts for calculating minimum distances between all pairs of a (possibly large) set of spatial polygons. The distances are used as input to the `Conefor` package (http://www.conefor.org/). The polygons are the _nodes_ in the connectivity analysis, and the distances are the _edges_ or _links_. Other methods exist for performing these calculations, but fail when there are too many polygons. This package works by breaking the task into smaller "blocks", each of which can be executed independently, potentially even running on different computers. Each block produces its own CSV distances file. Once all blocks have been executed, the CSV files from each block should be concatenated to produce one large distances file.

Calculating large numbers of distances is a time consuming operation. If you have `n` polygons, there are `n * (n - 1) / 2` distances to be calculated. Depending on the number of polygons and the speed of your computer(s), the total calculation time might be days or even weeks! Using `Distfor`, you can choose to run the process in a single block, or you can break it into multiple blocks. Multiple blocks can be run simultaneously on the same or different computers, thereby reducing the elapsed time for the total operation. 

You do not need to understand R programming to use this package, but you do need to know how to run R scripts.

<!-- TODO include this once there's something to cite
If you use this package in published scientific research, please cite: Cadavid-Florez, L. et al. (2019), The role of isolated trees and small patches on landscape connectivity for birds in a neotropical rural landscape, Nature
-->

## Table of contents

* [Installation](#installation)
* [Running](#running)
* [Worked example](#workedexample)
* [Memory limits](#memorylimits)

<a name="installation"/>

## Installation

You must have R installed (https://www.r-project.org/). R is a free software environment which runs on a variety of computer systems. Download the `Distfor` package (or at least all of the `.R` scripts). Put the files in a convenient location.

<a name="running"/>

## Running

You can run the scripts from a terminal (using Rscript) or from an integrated development environment (IDE) such as RStudio. When running from a terminal, script parameters are specified on the command line. When running from an IDE, parameters are specified by editing the script to set variable values. The section to be edited is at the end of each script, and is marked with the comment `EDIT THIS SECTION`.
There are 3 top-level scripts.

### `calc-distances.R`

is the script used to calculate distances for a single block. Input is a shape file, parameters describing how to access polygons in the shape file, the number of the block to be processed, and the total number of blocks. Any file which can be read by the [readOGR](https://www.rdocumentation.org/packages/rgdal/versions/1.4-3/topics/readOGR) function in the [rgdal](https://cran.r-project.org/web/packages/rgdal/index.html) package may be used. It must contain a layer with all the polygons of interest. 

Distance is calculated by the [gDistance](https://www.rdocumentation.org/packages/rgeos/versions/0.4-2/topics/gDistance) function in the [rgeos](https://cran.r-project.org/web/packages/rgeos/index.html) package. This means that distances are cartesian distances between two geometries in the _units of the current projection_. In particular, your shape file coordinates must not be specified as latitude and longitude values. If they are, an error will be reported and the script will exit. In this case, use your GIS system to project your shape file to a planar coordinate system, and try again.

The output file named `<layer>_<block>_<totalBlocks>.txt ` will be created in the current directory. It is a tab-separated file with 3 columns, `<node 1 ID>`, `<node 2 ID>`, and `<length>`, where `<length>` is the minimum distance between node 1 and node 2. By default, the script detects if the output file already exists, and reports an error then exits without modifying the file. If the block is partially completed, the unfinished calculations can be performed by specifying `--continue` on the command line or setting `continue` to `TRUE` in the script. The following table details the script arguments in the order they must be specified on the command line.

| Parameter    | Required?            | Description                                              | R variable name |
|--------------|----------------------|----------------------------------------------------------|-----------------|
| `--continue` | optional             | Add to existing output file if it exists                 | `continue`      |
| DSN          | required             | Data source name, e.g. folder containing shape file      | `dsn`           |
| layer        | required             | Name of polygon layer                                    | `layer`         |
| ID column    | required             | Name of column containing polygon identifier             | `idCol`         |
| block        | optional (default 1) | Block number to be processed, between 1 and total blocks | `thisBlock`     |
| total blocks | optional (default 1) | Total number of blocks                                   | `totalBlocks`   |

Start by deciding on the number of blocks you wish to break the task into. To get an idea of the total calculation time, you can start by processing a single block. After a while (seconds or minutes), a very crude estimate of the finishing time for the task is displayed. Once you know the expected finish time, you can decide whether it is worth splitting the task into multiple blocks to be run concurrently.

### `check-block-files.R`

can be used to check the results of distance calculations for individual blocks. It performs some heuristic checks on the CSV files output by `calc-distances.R`. 

| Parameter    | Required?            | Description                                              | R variable name |
|--------------|----------------------|----------------------------------------------------------|-----------------|
| DSN          | required             | Data source name, e.g. folder containing shape file      | `dsn`           |
| layer        | required             | Name of polygon layer                                    | `layer`         |
| ID column    | required             | Name of column containing polygon identifier             | `idCol`         |
| directory    | optional (default `.`) | Directory/folder  to search for block files            | `dir`           |

### `check-full-results.R`

can be used to run some heuristic checks on a complete distances file. It checks that a row exists for each pair of polygons. This may be useful if you have constructed a distances file by concatenating the output of multiple blocks, and want to check that all blocks ran to completion, and all blocks were included in the final results. It can take minutes to run.

| Parameter    | Required?            | Description                                              | R variable name |
|--------------|----------------------|----------------------------------------------------------|-----------------|
| file         | required             | name of the complete distances file                      | `fileName`      |

If you see the error message:

   `Error in unique.default(distances[[2]], nmax = nmax) : hash table is full`

it probably means that the results file you are checking is not a complete distances file.

<a name="workedexample"/>

### Worked example

I have a shape file called `eg_map`, polygons are in layer `example_Distfor`, and the ID column is named `ID_bis`. I have decided to break the job into 3 blocks, because I have access to 3 computers named A, B and C. Each computer has R installed and I have copied my shapefile and the `distfor` scripts to a working directory/folder on each computer. This example demonstrates running the scripts from the command line.

The shapefile for this example is included in the GitHub repository. To simply run the provided example using the directory structure after installing `distfor`, first `cd` to the `examples` subdirectory, then prepend "../" to each of the script names in the following commands. For example, the first command would be modified to 

    Rscript ../calc-distances.R eg_map example_Distfor ID_bis 1 3

---

On computer A, I calculate the distances for the first block of edges by running:

    Rscript calc-distances.R eg_map example_Distfor ID_bis 1 3

On computer B, I calculate the second block of distances:

    Rscript calc-distances.R eg_map example_Distfor ID_bis 2 3
    
On computer C, I calculate the third block of distances:

    Rscript calc-distances.R eg_map example_Distfor ID_bis 3 3
    
Computer C crashed part-way through the calculation. Rather than re-run the entire block 3 calculation, I continued the calculation from where it had finished, by running the command:

    Rscript --continue calc-distances.R eg_map example_Distfor ID_bis 3 3

I then copied the file `example_Distfor_002_003.txt` from computer B to computer A, and file `example_Distfor_003_003.txt` from computer C, so now I have `example_Distfor_001_003.txt`, `example_Distfor_002_003.txt` and `example_Distfor_003_003.txt` on computer A. To check that the files are complete, I run (on computer A):

    Rscript check-block-files.R eg_map example_Distfor ID_bis
    
and it doesn't report any errors. Computer A is a Windows PC, so to create the complete distances file I run:

    copy /b example_Distfor-*.txt distances.csv

If I were running on a Linux or MacOS computer, I would have used the command:

    cat example_Distfor_*.txt >distances.csv
    
I now have my complete distances file, `distances.csv`, ready to use as input to Conefor. I can optionally run a final check on the coplete distances file as follows:

    Rscript check-full-results-file.R distances.csv


<a name="memorylimits"/>

## Memory limits

These scripts require enough memory to read the entire shape file and
then create a list of unique node identifiers. This means that the
memory required is proportional to the number of nodes, not the number
of edges. The memory required is the same whether distances are
calculated for all edges at once, or broken into blocks.  Very large
networks may still exceed the memory available to be used by R. If
your network does exceed the available memory, you will most likely
see an error message like `cannot allocate vector of <length>`. The
available memory depends on a variety of factors, including the
installed RAM on your computer, whether you are running a 32- or
64-bit build of R, and the underlying operating system. See [Memory
Limits in
R](https://stat.ethz.ch/R-manual/R-patched/library/base/html/Memory-limits.html)
for a detailed description.

If you do encounter this problem, there may be some simple steps you
can take. Run with 64-bit R rather than 32-bit R. Try closing other
programs which are consuming large amounts of RAM before running these
scripts. When running on Windows, you may be able to increase the R
memory limits - look at the R help for `memory.limit`. Searching a
site such as [stackoverflow](https://stackoverflow.com/) may provide
additional answers (such as [this
question](https://stackoverflow.com/q/5171593)).
