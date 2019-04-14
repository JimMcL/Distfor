#!Rscript

# Checks whether a complete distances file seems to be valid

library(data.table, quietly = TRUE, verbose = FALSE)

# Sources a file in the same directory as this script
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



CheckDistancesFile <- function(fileName, sep = "\t") {
  .check <- function(test, msg) if (!test) stop(sprintf("%s: %s", fileName, msg))
  .checkEq <- function(expect, have, msg) .check(expect == have, sprintf("%s should be %d but is %d", msg, expect, have))
  
  # fread is fast but has some problems, hopefully not an issue in this context
  cat(sprintf("Reading %s...\n", fileName))
  distances <- fread(file = fileName, sep = sep, header = FALSE)
  .checkEq(3, ncol(distances), "No. of columns in file")
  .checkEq("numeric", class(distances[[3]]), "Type of column 3 (i.e. distances)")
  
  # Estimate maximum number of nodes, round it up just to be safe
  nmax <- round((2 + sqrt(4 - 4 * 2 * -nrow(distances))) / 2 * 1.4)
  
  n1 <- unique(distances[[1]], nmax = nmax)
  n2 <- unique(distances[[2]], nmax = nmax)
  nodeIds <- unique(c(n1, n2), nmax = nmax)
  numNodes <- length(nodeIds)

  # Check number of distances
  expectedNumPairs <- numNodes * (numNodes - 1) / 2
  .checkEq(expectedNumPairs, nrow(distances), "Number of distances")
  
  # Every node should occur in numNodes -1 pairs
  # This method is slow and complicated but doesn't exceed memory limits
  blockSize <- 2000
  numBlocks <- (numNodes + blockSize - 1) %/% blockSize
  pb <- ElapsedTimeProgressBarFn(numBlocks, buildTxtReportFn("Checking all nodes are in expected numbers of pairs..."))
  for (block in seq_len(numBlocks)) {
    
    upper <- block * blockSize
    lower <- upper - blockSize + 1
    upper <- min(upper, numNodes)
    # Don't assume node ids
    lowerId <- nodeIds[lower]
    upperId <- nodeIds[upper]
    t <- table(c(distances[[1]][distances[[1]] >= lowerId & distances[[1]] <= upperId], 
                 distances[[2]][distances[[2]] >= lowerId & distances[[2]] <= upperId]))
  
    .check(all(t == numNodes - 1), sprintf("Not all nodes are in expected number of pairs (%d, failure was somewhere in nodes %d-%d)", numNodes - 1, lowerId, upperId))
    
    pb(block)
  }
  
  cat(sprintf("File %s passed all checks\n", fileName))
  cat(sprintf("It contains %d nodes and %d distances\n", numNodes, nrow(distances)))
}

###############################################################################

if (!isRStudio()) {
  args <- commandArgs(TRUE)
  if (length(args) != 1)
    stop("Usage: file")
  fileName <- args[1]
} else {
  
  ####
  # EDIT THIS SECTION if you are running in a GUI
  # This is just an example
  fileName <- "map2_conn4-full.txt"
  # End of section to edit
  ####

}

CheckDistancesFile(fileName)
