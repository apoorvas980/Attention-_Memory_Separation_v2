library(RcppSimdJson)
library(data.table)

# in the end, we want two data frames-- one for reach trials, one for probe


rad2deg <- function(rad) {(rad * 180) / (pi)}
deg2rad <- function(deg) {(deg * pi) / (180)}

# https://stackoverflow.com/a/30887154/2690232
signed_diff_angle <- function(a, b) {
  d <- abs(a - b) %% 360
  r <- ifelse(d > 180, 360 - d, d)
  sgn <- ifelse((a - b >= 0 && a - b <= 180) || (a - b <= -180 && a - b >= -360), 1, -1)
  r * sgn
}


clean_block <- function(filename) {
  raw_dat <- fload(filename, max_simplify_lvl = 'vector', single_null = NA, empty_object = NA, empty_array = NA)
  n_trials <- length(raw_dat$trials$frames)
  # TODO: check if n_trials is small?
  reach_trials <- list()
  probe_trials <- list()
  
  state_names <- raw_dat[['block']][['state_names']]
  raw_dat$trials$endpoint_angle <- rep(NA, n_trials)
  for (i in 1:n_trials) {
    # reach is 1, probe is 2
    is_reach <- raw_dat$trials$reach_or_probe[i] == 1
    if (is_reach) {
      reach_data <- raw_dat$trials$frames[[i]]
      # compute endpoint reach angle
      origin <- raw_dat$trials$center_px[[i]]
      target <- raw_dat$trials$target_px[[i]]
      raw_dat$trials$endpoint_angle[i] <- compute_reach_angle(reach_data, state_names, origin, target)
    }
  }
  raw_dat$trials$frames <- NULL
  raw_dat$trials$probe <- NULL
  raw_dat$trials$center_px <- NULL
  raw_dat$trials$target_px <- NULL
  raw_dat$trials$probe_px <- NULL
  
  block_data <- as.data.table(raw_dat$trials)
  block_data[, `:=`(id = raw_dat$block$id)]
  block_data
}

# compute the reach angle for the trial
compute_reach_angle <- function(reach_data, state_names, origin, target) {
  foo <- reach_data[['input_events']]
  for (i in 1:length(foo)) {
    foo[[i]][['state']] <- state_names[reach_data[['start_state']][i] + 1]
  }
  foo <- rbindlist(foo)
  foob <- list()
  i <- 1
  while (i <= nrow(foo) - 1) {
    if (!is.na(foo[i+1]$t) && !is.na(foo[i]$t) && foo[i+1]$t - foo[i]$t < 0.001) {
      foob[[i]] <- data.table(t = foo[i]$t, x = foo[i+1]$x, y = foo[i+1]$y, state = foo[i+1]$state)
      i <- i + 2
    } else {
      foob[[i]] <- data.table(t = foo[i]$t, x = foo[i]$x, y = foo[i]$y, state = foo[i]$state)
      i <- i + 1
    }
  }
  js_events <- rbindlist(foob)
  js_data <- js_events[state == 'REACH']
  # correct reach position and target for origin
  js_data[, `:=`(x_px = x - origin$x, y_px = y - origin$y)]
  target$x <- target$x - origin$x
  target$y <- target$y - origin$y
  
  js_data[, angle := rad2deg(atan2(x_px, y_px))]
  target_angle <- rad2deg(atan2(target$y, target$x))
  js_data$diff_angle <- sapply(js_data$angle, signed_diff_angle, b=target_angle)
  js_data$diff_angle[nrow(js_data)]
}
