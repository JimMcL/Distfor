#!Rscript

# Attempts to check that a set of distances files contain valid data, 
# i.e. shape indices are as expected for each block etc.
# Assumes that the files were created by the CalcPairwiseDistances function,
# hence follow precise file naming conventions etc.
# 
# To create a full file called distances.csv from a set of block files, run:
# On Windows: copy /b *.txt distances.csv
# On *nix: cat *.txt >distances.csv

library(data.table)
library(rgdal, quietly = TRUE, verbose = FALSE)
# Sources a file in the same directory as this script
sourceFromPkg <- function(file) {
  # Taken from stackoverflow answer https://stackoverflow.com/a/15373917
  pkgDir <- function() {
    cmdArgs <- commandArgs(trailingOnly = FALSE)
    fopt <- "--file="
    match <- grep(fopt, cmdArgs)
    if (length(match) > 0) {
      dirname(sub(fopt, "", cmdArgs[match]))
    } else {
      dirname(sys.frames()[[1]]$ofile)
    }
  }
  source(file.path(pkgDir(), file))
}

sourceFromPkg("functions.R")

blockFromName <- function(fileName) {
  ss <- strsplit(sub("\\.txt", "", fileName), "-")
  thisBlock <- strtoi(ss[[1]][2], base = 10)
  numBlocks <- strtoi(ss[[1]][3], base = 10)
  c("thisBlock" = thisBlock, "numBlocks" = numBlocks)  
}

checkBlockFile <- function(fileName, allIds, sep = "\t") {
  .check <- function(test, msg) if (!test) stop(sprintf("%s: %s", fileName, msg))
  .checkEq <- function(expect, have, msg) .check(expect == have, sprintf("%s should be %d but is %d", msg, expect, have))

  # Work out what block the file contains
  b <- blockFromName(fileName)
  thisBlock <- b["thisBlock"]
  numBlocks <- b["numBlocks"]
  rng <- BlockRange(thisBlock, numBlocks, length(allIds))
  
  # Open the file. Read node numbers as character to detect non-integral values (otherwise it is too "smart" and truncates to integers)
  distances <- read.csv(fileName, sep = sep, header = FALSE, colClasses = c("character", "character", "numeric"))
  nr <- nrow(distances)

  col1 <- as.integer(distances[[1]])
  badNodes <- which(as.numeric(distances[[1]]) != col1)
  .check(length(badNodes) == 0, sprintf("Non-integral node values, column 1, rows %s\n", paste(badNodes, collapse = ", ")))
  col2 <- as.integer(distances[[2]])
  badNodes <- which(as.numeric(distances[[2]]) != col2)
  .check(length(badNodes) == 0, sprintf("Non-integral node values, column 2, rows %s\n", paste(badNodes, collapse = ", ")))
  # Convert node ids to numbers
  distances[, 1] <- col1
  distances[, 2] <- col2
  
  # Some basic sanity checks
  # All distances should be a proper number
  .check(!any(is.na(distances[[3]])), "NA distances")
  # Check number of distances
  .nc <- function(n) (n * (n - 1)) / 2
  #Wrong .checkEq(.nc(nr - rng[1]) - .nc(nr - rng[2]), nr, "Number of distances")

  .checkEq(allIds[rng[1]], distances[[1, 1]], "First row, column 1")
  .checkEq(allIds[rng[2]], distances[[nr, 1]], "Last row, column 1")
  .checkEq(allIds[rng[1]], min(distances[[1]]), "Minimum row, column 1")
  .checkEq(allIds[rng[1]] + 1, min(distances[[2]]), "Minimum row, column 2")
  maxId <- max(allIds)
  .checkEq(maxId, distances[[nr, 2]], "Last row, column 2")
  .check(max(distances[[1]]) <= maxId, sprintf("Maximum value in column 1 should be %d but is %d", max(allIds), max(distances[[1]])))
  .check(max(distances[[2]]) <= maxId, sprintf("Maximum value in column 2 should be %d but is %d", max(allIds), max(distances[[2]])))
  
  cat(sprintf("%s matches block %d of %d\n", fileName, thisBlock, numBlocks)) 
}

CheckDistancesBlockFiles <- function(map, layer, idCol, dir, sep = "\t", fullFileName = NULL) {
  
  blockFiles <- sort(list.files(dir, sprintf("%s-\\d+-\\d+.txt", layer), full.names = TRUE))
  if (length(blockFiles) == 0)
    stop(sprintf("No block files found for layer %s in directory %s", layer, dir))
  
  # Read in the shapes file
  shp <- readOGR(dsn = map, layer = layer, verbose = FALSE)
  allIds <- shp@data[[idCol]]
  ti <- table(allIds)
  if (sum(ti > 1) > 0)
    stop(sprintf("Duplicate ID values in shape file %s", layer))
  
  # Check each block file
  numGood <- 0
  for (bf in blockFiles) {
    tryCatch({
      checkBlockFile(bf, allIds)
      numGood <- numGood + 1
    }, error = function (e) cat(paste0(conditionMessage(e), "\n"))
    )
  }

  # Are all blocks present?
  numBlocks <- blockFromName(blockFiles[1])["numBlocks"]
  for (bi in seq_len(numBlocks)) {
    bb <- blockFromName(blockFiles[bi])
    if (bb["numBlocks"] != numBlocks)
      stop(sprintf("Unexpected file %s, incorrect block count %d, expected %d\n", blockFiles[bi], bb["numBlocks"] != numBlocks))
    if (bb["thisBlock"] != bi)
      stop(sprintf("Missing file for block %d of %d\n", bi, numBlocks))
  }
  if (numGood == numBlocks)
    cat("All blocks are present and appear correct\n")
  else
    cat(sprintf("Expected %d blocks, found %d\n", numBlocks, numGood))
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
  dsn <- "map"
  layer <- "map2_conn4"
  idCol <- "ID_bis"
  dir <- "results"
  # End of section to edit
  ####

  } else {
  args <- commandArgs(TRUE)
  cat("\n")
  if (length(args) < 3 || length(args) > 4)
    stop("Usage: map layer idColumn [<results directory>]")
  dsn <- args[1]
  layer <- args[2]
  idCol <- args[3]
  dir <- "."
  if (length(args) > 3)
    dir <- args[4]
}

CheckDistancesBlockFiles(dsn, layer, idCol, dir)
