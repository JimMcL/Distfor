# Distfor: Distance calculations for Conefor

This package contains R scripts for calculating minimum distances between all pairs of a (possibly large) set of polygons. The distances are used as input to the `Conefor` package (http://www.conefor.org/). Other methods exist for performing these calculations, but fail when there are too many polygons. This package works by breaking the task into smaller "blocks", each of which can be executed independently, potentially even running on different computers. Each block produces its own CSV distances file. Once all blocks have been executed, the CSV files from each block should be concatenated to produce one large distances file.

Calculating large numbers of distances is a time consuming operation. If you have `n` polygons, there are `n * (n - 1) / 2` distances to be calculated. Depending on the number of polygons and the speed of your computer(s), the total calculation time might be days or even weeks! Using Distfor`, you can choose to run the process in a single block, or you can break it into multiple blocks. Multiple blocks can be run simultaneously on the same or different computers, thereby reducing the elapsed time for the total operation. 

You do not need to understand R programming to use this package, but you will have to learn how to run R scripts.

## Installation

You must have R installed (https://www.r-project.org/). R is a free software environment which runs on a variety of computer systems. Download the `Distfor` scripts and copy them to your working folder/directory. 

## Running

You can run the scripts from a terminal (using Rscript) or from a GUI such as RStudio. When running from a terminal, script parameters are specified on the command line. When running from a GUI, parameters are specified by editing the script to set variable values. The section to be edited is at the end of each script, and is marked with the comment `EDIT THIS SECTION`.
There are 3 top-level scripts.

### `calc-distances.R`

is the script used to calculate distances for a single block. Input is a shape file, parameters describing how to access polygons in the shape file, the number of the block to be processed, and the total number of blocks. Any file which can be read by the [readOGR](https://www.rdocumentation.org/packages/rgdal/versions/1.4-3/topics/readOGR) function in the [rgdal](https://cran.r-project.org/web/packages/rgdal/index.html) package may be used. It must contain a layer with all the polygons of interest. 

Distance is calculated by the [gDistance](https://www.rdocumentation.org/packages/rgeos/versions/0.4-2/topics/gDistance) function in the [rgeos](https://cran.r-project.org/web/packages/rgeos/index.html) package. This means that distances are cartesian distances between two geometries in the _units of the current projection_. In particular, you do not want your shape file coordinates to be specified as latitude and longitude values. If they are, an error will be reported and the script will exit. In this case, use your GIS system to project your shape file to a planar coordinate system, and try again.

The output file named `<layer>_<block>_<totalBlocks>.txt ` will be created in the current directory. It is a tab-separated file with 3 columns, `<node 1 ID>`, `<node 2 ID>`, and the minimum distance between node 1 and node 2. By default, the script detects if the output file already exists, and reports an error then exits. If the block is partially completed, the unfinished calculations can be performed by specifying `--continue` on the command line or setting `continue` to `TRUE` in the script. The following table details the script arguments in the order they must be specified on the command line.

| Parameter    | Required?            | Description                                              | R variable name |
|--------------|----------------------|----------------------------------------------------------|-----------------|
| `--continue` | optional             | Add to existing output file if it exists                 | `continue`      |
| DSN          | required             | Data source name, e.g. folder containing shape file      | `dsn`           |
| layer        | required             | Name of polygon layer                                    | `layer`         |
| ID column    | required             | Name of column containing polygon identifier             | `idCol`         |
| block        | optional (default 1) | Block number to be processed, between 1 and total blocks | `thisBlock`     |
| total blocks | optional (default 1) | Total number of blocks                                   | `totalBlocks`   |

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

First decide on the number of blocks you wish to break the task into. To get an idea of the total calculation time, you can start by processing a single block. After a while (seconds or minutes), a very crude estimate of the finishing time for the task is displayed. Once you know the expected finish time, you can decide whether it is worth splitting the task into multiple blocks to be run concurrently.

### Worked example

I have a shape file called `mymap`, polygons are in layer `patches`, and the ID column is named `patch_ID`. I have decided to break the job into 3 blocks, because I have access to 3 computers called A, B and C. Each computer has R installed and I have copied my shapefile and the `distfor` scripts to a working directory/folder on each computer. 

On computer A, I run:

    Rscript calc-distances.R mymap patches patch_ID 1 3

On computer B, I run:

    Rscript calc-distances.R mymap patches patch_ID 2 3
    
On computer C, I run:

    Rscript calc-distances.R mymap patches patch_ID 3 3
    
Computer C crashed part-way through the calculation. Rather than re-run the entire block 3 calculation, I continued the calculation from where it had finished, by running the command:

    Rscript --continue calc-distances.R mymap patches patch_ID 3 3

I then copied the file `patches_002_003.txt` from computer B to computer A, and file `patches_003_003.txt` from computer C, so now I have `patches_001_003.txt`, `patches_002_003.txt` and `patches_003_003.txt` on computer A. To check that the files are complete, I run (on computer A):

    Rscript check-block-files.R mymap patches patch_ID
    
and it doesn't report any errors. Computer A is a Windows PC, so to create the complete distances file I run:

    copy /b patches_*.txt distances.csv

If I was running on a Linux or MacOS computer, I would have used the command:

    cat patches_*.txt >distances.csv
    
I now have my complete distances file, `distances.csv`, ready to use as input to Conefor.
