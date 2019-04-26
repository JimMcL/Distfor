#!Rscript

# Calculates distances between pairs of polygons in a shape file. Results are
# written to a tab-separated file.
#
# Run this script from the command line with no arguments to see a usage
# message.

library(sp, quietly = TRUE, verbose = FALSE)
library(rgdal, quietly = TRUE, verbose = FALSE)
library(rgeos, quietly = TRUE, verbose = FALSE)
library(data.table, quietly = TRUE, verbose = FALSE)

# Sources a file in the same directory as this script.
sourceFromPkg <- function(file) {
  # Modified from stackoverflow answer https://stackoverflow.com/a/15373917
  pkgDir <- function() {
    cmdArgs <- commandArgs(trailingOnly = FALSE)
    fopt <- "--file="
    match <- grep(fopt, cmdArgs)
    if (length(match) > 0) {
      dirname(sub(fopt, "", cmdArgs[match]))
    } else if ("ofile" %in% names(sys.frames()[[1]])) {
      dirname(sys.frames()[[1]]$ofile)
    } else {
      # Run selection in RStudio
      "." # this is wrong, but at least it doesn't crash
    }
  }
  source(file.path(pkgDir(), file))
}

sourceFromPkg("functions.R")

# Writes distances between pairs of polygons to a tab-separated file
#
# Output is a CSV file (tab-separated by default) with 3 columns: ID of the 1st
# shape, ID of the 2nd shape, distance between the 2 shapes. The first shape is
# the sequence of shapes from index `firstRow` to index `lastRow` inclusive.
# Each shape is measured against all shapes which come after it in `shapes`.
#
# @param shapes The spatial objects to measure.
# @param fileName Name of the file to write to.
# @param firstRow Index of first row to measure.
# @param lastRow Index of last row to measure.
# @param idCol Name of the ID column. This is the value written to the output
#   file to identify the shapes.
# @param append If TRUE, rows will be added to the existing file. If FALSE, an
#   existing file will be overwritten.
# @param sep Separator for CSV file.
#
CalcBlockPairwiseDistances <- function(shapes, fileName, firstRow, lastRow, idCol, append = FALSE, sep = "\t", verbose = TRUE) {
  nr <- nrow(shapes)
  .workForRow <- function(n) nr - n
  .workForRows <- function(from, to) sum(.workForRow(from:to))

  pb <- function(n) NULL
  if (verbose) {
    pb <- ElapsedTimeProgressBarFn(.workForRows(firstRow, lastRow), 
                                   buildTxtReportFn(sprintf("Calculating distances to polygons %d:%d, block %d of %d\n", firstRow, lastRow, thisBlock, totalBlocks)))
  }

  # Treat warnings as errors inside the loop
  oldOpt <- options(warn = 2)
  
  workDone <- 1
  # For each polygon in the block...
  for (i in firstRow:lastRow) {
    # Calculate distance to all polygons with ID > this polygon's id
    # Save this set of results in a data frame then write them all out at once.
    # This speeds up processing and simplifies handling of incomplete output files.
    js <- (i + 1):nr
    distances <- data.frame(nrow = length(js), ncol = 3)
    idx <- 1
    pb(workDone)
    for (j in js) {
      workDone <- workDone + 1
      distances[idx, 1] <- shapes@data[i, idCol]
      distances[idx, 2] <- shapes@data[j, idCol]
      distances[idx, 3] <- gDistance(shapes[i, ], shapes[j, ])
      idx <- idx + 1
    }
    # Add the distances to the file
    fwrite(distances, fileName, sep = sep, row.names = FALSE, col.names = FALSE, append = append)
    append <- TRUE
  }
  pb(close = TRUE)
  
  # Restore warnings
  options(oldOpt)
}

# Calculates the rows remaining to be measured from an incomplete file.
CalcRemainingRange <- function(block, nPolygons, outFile, sep = "\t") {
  # Read the file
  old <- fread(file = outFile, sep = sep, header = FALSE)
  
  # Sanity check
  if (ncol(old) != 3 || class(old[[1]]) != "integer" || class(old[[2]]) != "integer" || class(old[[3]]) != "numeric")
    stop(sprintf("Invalid data file, unexpected format: %s", outFile))
  # Check the first line
  if (old[[1, 1]] != block[1])
    stop(sprintf("Invalid data file, expected row 1 column 1 to be %d, was %d: %s", block[1], old[[1, 1]], outFile))
  if (old[[1, 2]] != block[1] + 1)
    stop(sprintf("Invalid data file, expected row 1 column 2 to be %d, was %d: %s", block[1] + 1, old[[1, 2]], outFile))
  # Check the last line
  old <- old[nrow(old), ]
  if (old[[2]] != nPolygons || old[[1]] >= old[[2]])
    stop(sprintf("Data file '%s' doesn't seem to match input or is corrupt,\n  expected the last row to look like \"<n> %d <distance>\"", outFile, nPolygons))
  
  firstRow <- old[[1]] + 1
  lastRow <- block[2]
  if (firstRow == nPolygons)
    stop(sprintf("Data file '%s' appears to be complete already", outFile))

  # Return the new range
  c(firstRow = firstRow, lastRow = lastRow)
}

CalcPairwiseDistances <- function(dsn, layer, idCol, outFile, thisBlock, totalBlocks, continue = FALSE) {

  shp <- readOGR(dsn = dsn, layer = layer, verbose = FALSE)
  
  if (!idCol %in% names(shp@data))
    stop(sprintf("'%s' is not a valid column name\n", idCol))
  # Check for duplicate IDs
  ti <- table(shp@data[[idCol]])
  if (sum(ti > 1) > 0)
    stop(sprintf("Shape file contains duplicate %s values", idCol))
  nPolygons <- nrow(shp)
  block <- BlockRange(thisBlock, totalBlocks, nPolygons)
  
  if (continue && file.exists(outFile)) {
    newblock <- CalcRemainingRange(block, nPolygons, outFile)
    cat(sprintf("Adding to existing file, skipping polygons %d to %d\n", block[1], newblock[1] - 1))
    block <- newblock
  } else if (file.exists(outFile)) {
    stop(sprintf("File %s already exists, skipping", outFile))
  }
  cat(sprintf("Writing %s, id column '%s'\n", outFile, idCol))
  CalcBlockPairwiseDistances(shp, outFile, block[1], block[2], idCol, append = continue)
}


####################################################################################
# Test whether running under a GUI such as RStudio 

# Automatically detect if running inside RStudio
isGUI <- isRStudio()
# Uncomment this line if you are running in another GUI
#isGUI <- TRUE

if (isGUI) {
  
  ####
  # EDIT THIS SECTION if you are running in a GUI
  # This is just an example
  continue <- FALSE
  dsn <- "example/gadm36_KEN_shp"
  layer <- "gadm36_KEN_1"
  idCol <- "NAME_1"
  thisBlock <- 1
  totalBlocks <- 1
  # End of section to edit
  ####
  
} else {
  
  # Not running in a GUI, so no need for this file to be edited.
  # Parameters are passed in on the command line
  # Process command line arguments
  args <- commandArgs(TRUE)
  cat("\n")
  continue <- length(args) >= 1 && args[1] == "--continue"
  if (continue)
    args <- tail(args, -1)
  if (!(length(args) == 3 || length(args) == 5))
    stop("Usage: [-continue] map layer idColumn [thisBlock totalBlocks]")
  dsn <- args[1]
  layer <- args[2]
  idCol <- args[3]
  thisBlock <- 1
  totalBlocks <- 1
  if (length(args) == 5) {
    thisBlock <- as.integer(args[4])
    totalBlocks <- as.integer(args[5])
  }
}


st <- proc.time()

outFile <- sprintf("%s-%03d-%03d.txt", layer, thisBlock, totalBlocks)

CalcPairwiseDistances(dsn, layer, idCol, outFile, thisBlock, totalBlocks, continue)

cat(sprintf("Elapsed time %g secs\n", (proc.time() - st)[3]))
