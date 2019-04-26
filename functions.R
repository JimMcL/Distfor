# Some functions used by other scripts

# Returns the range of starting nodes for distance calculations in a single
# block.
#
# @param thisBlock Number of the block being calculated. The first block is 1,
#   and the last block is \code{numBlocks}.
# @param numBlocks Total number of blocks that the calculation has been broken
#   into.
# @param numNodes The number of nodes in the network.
#
# @value A vector with two values, the indices of the first and last starting
#   nodes in the block.
BlockRange <- function(thisBlock, numBlocks, numNodes){
  # Exact number of nodes required per block - may not be an integer
  compBlock <- (numNodes * (numNodes-1) / 2) / numBlocks
  
  nComp <- (numNodes-1) : 1
  c(
    ## the start column of this block = one more than the end column of the previous block
    if (thisBlock == 1)
      1
    else
      which(cumsum(nComp) >= (thisBlock - 1) * compBlock)[1] + 1,
    ## the end column of this block
    which (cumsum(nComp) >= thisBlock * compBlock)[1] 
  )
}

# Returns TRUE if running inside RStudio
isRStudio <- function() Sys.getenv("RSTUDIO") == "1"


#### Progress bar functions ####

# Converts a time duration in seconds to a human readable string
durationToS <- function(duration) {
  if (is.na(duration))
    return(NA)
  if (duration >= 3600) {
    duration <- duration / 3600
    units <- "hours"
  } else if (duration >= 60) {
    duration <- duration / 60
    units <- "mins"
  } else {
    duration <- ceiling(duration)
    units <- "secs"
  }
  sprintf("%g %s", signif(duration, 2), units)
}

.formatProgressMsg <- function(n, total, secsElapsed, secsRemaining, sd, finished) {
  # # Be pessimistic on the assumption it's better to present bad news early.
  # # Obviously this is just an arbitrary heuristic
  # if (!is.na(sd))
  #   secsRemaining <- secsRemaining + var / 2
  # If it's not going to finish for a long time...
  if (secsRemaining > 45 * 60) {
    # Report finish time
    fmt <- if (julian(Sys.Date()) != julian(Sys.time() + secsRemaining))
      "%Y-%m-%d %H:%M:%S"
    else
      "%H:%M:%S"
    #sprintf("Est. finish at %s +-%g hours", format(Sys.time() + secsRemaining, fmt), signif(sd / 60 / 60, 2))
    sprintf("Est. finish at %s", format(Sys.time() + secsRemaining, fmt))
  } else {
    #sprintf("Est. time remaining %s +-%g secs", durationToS(secsRemaining), signif(sd, 2))
    sprintf("Est. time remaining %s", durationToS(secsRemaining))
  }
}

buildTxtReportFn <- function(title, newline = "\r") {
  if (!missing(title) && !is.null(title)) {
    cat(paste0(title, "\n"))
    flush.console()
  }
  
  function(n, total, secsElapsed, secsRemaining, sd, finished) {
    if (finished)
      cat(sprintf("\nComplete\n"))
    else {
      cat(paste0(.formatProgressMsg(n, total, secsElapsed, secsRemaining, sd, finished),
                 "                                    ", newline))
      flush.console()
    }
  }
}

buildWinReportFn <- function(title) {
  pb <- winProgressBar(title, "Estimated completion time", min = 0, max = 100)
  function(n, total, secsElapsed, secsRemaining, sd, finished) {
    if (!missing(finished) && finished)
      close(pb)
    else {
      label <- .formatProgressMsg(n, total, secsElapsed, secsRemaining, sd, finished)
      setWinProgressBar(pb, 100 * secsElapsed / (secsElapsed + secsRemaining), label = label)
    }
  }
}

buildTkReportFn <- function(title) {
  pb <- tcltk::tkProgressBar(title, "Estimated completion time", min = 0, max = 100)
  function(n, total, secsElapsed, secsRemaining, sd, finished) {
    if (!missing(finished) && finished)
      close(pb)
    else {
      label <- .formatProgressMsg(n, total, secsElapsed, secsRemaining, sd, finished)
      tcltk::setTkProgressBar(pb, 100 * secsElapsed / (secsElapsed + secsRemaining), label = label)
    }
  }
}

#' A general purpose progress bar that reports elapsed time rather than number of items
#'
#' @param numItems Number of items to be processed
#' @param reportFn A function used to report changing progress
#'
#' @return A function which should be called for each item as it is processed.
ElapsedTimeProgressBarFn <- function(numItems, reportFn) {
  # Function state
  durations <- numeric(numItems)
  index <- 1
  startTime <- proc.time()
  itemStartTime <- proc.time()
  ignoreShortFirstTime <- TRUE
  closed <- FALSE
  
  function(itemNumber, newNumItems, close) {
    # Already closed?
    if (closed)
      # Do nothing
      return(invisible(NULL))
    
    # Force close?
    if (!missing(close) && close) {
      reportFn(finished = TRUE)
      closed <<- TRUE
      return(invisible(NULL))
    }
    
    # Allow caller to override current item index or total number of items
    if (!missing(itemNumber)) {
      index <<- as.numeric(itemNumber)
    }
    if (!missing(newNumItems)) {
      numItems <<- as.numeric(newNumItems)
    }
    
    # Calculate elapsed time from last item to this
    now <- proc.time()
    duration <- (now - itemStartTime)[3]
    # Save this duration
    durations[index] <<- duration
    # Time remaining
    nRemaining <- numItems - index
    secsRemaining <- nRemaining * (now - startTime)[3] / index
    
    closed <<- nRemaining == 0
    # To get sd, sum the variances (= sd ^ 2) and take square root
    reportFn(index, numItems, (now - startTime)[3], secsRemaining, sqrt(sd(durations) ^ 2 * nRemaining), finished = closed)
    
    # Move on - ignore very quick first entry, assume function was called before
    # the work was performed
    if (ignoreShortFirstTime && index == 1 && duration < .03) {
      ignoreShortFirstTime <<- FALSE
    } else {
      index <<- index + 1
      itemStartTime <<- now
    }
  }
}

# n <- 20
# #pb <- ElapsedTimeProgressBarFn(n, buildTxtReportFn("Progress"))
# pb <- ElapsedTimeProgressBarFn(n, buildWinReportFn("Test progress bar"))
# #pb <- ElapsedTimeProgressBarFn(n, buildTkReportFn("Test progress bar"))
# for (i in 1:(n - 1)) {
#   pb()
#   Sys.sleep(runif(1, max = 1))
# }
# pb(close = TRUE)
# pb()
# print(Sys.time())
