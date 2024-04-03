library(RcppSimdJson)
library(data.table)
library(ggplot2)
rad2deg <- function(rad) {(rad * 180) / (pi)}
deg2rad <- function(deg) {(deg * pi) / (180)}

signed_diff_angle <- function(a, b) {
  d <- abs(a - b) %% 360
  if (is.na(d)) {
    return(NA)
  }
  if (d > 180) {
    r <- 360 - d
  } else {
    r <- d
  }
  if ((a - b >= 0 && a - b <= 180) || (a - b <= -180 && a - b >= -360)) {
    sgn <- 1
  } else {
    sgn <- -1
  }
  r * sgn
}

raw_dat <- fload('../data/alex_1712157875.json.gz', max_simplify_lvl='vector')

# raw_dat$block has all the block-level settings/top-level configuration

# was_restarted and press_time have one data point per trial, e.g.
press_time_trial_4 <- raw_dat$trials$press_time[4]

# moment-by-moment data for trial 3
trial_idx <- 11
trial_3 <- raw_dat$trials$frames[[trial_idx]]
state_names <- raw_dat$block$state_names

# correct for x and y events being returned independently to input machinery
raw_evts <- trial_3$input_events
for (i in 1:length(raw_evts)) {
  raw_evts[[i]]$state <- state_names[trial_3$start_state[i] + 1]
}

foo <- rbindlist(raw_evts)
#foo <- foo[!is.na(t)]
foob <- list()
i <- 1
while (i <= (nrow(foo)-1)) {
  if (!is.na(foo[i+1]$t) && !is.na(foo[i]$t) && foo[i+1]$t - foo[i]$t < 0.001) {
    foob[[i]] <- data.table(t = foo[i]$t, x = foo[i+1]$x, y = foo[i+1]$y, state = foo[i+1]$state)
    i <- i + 2
  } else {
    foob[[i]] <- data.table(t = foo[i]$t, x = foo[i]$x, y = foo[i]$y, state = foo[i]$state)
    i <- i + 1
  }
}
fixed_js <- rbindlist(foob)
center <- raw_dat$trials$center_px[[trial_idx]]
target <- raw_dat$trials$target_px[[trial_idx]]
target$x <- target$x - center$x
target$y <- target$y - center$y

fixed_js[, xc := x - center$x]
fixed_js[, yc := y - center$y]

ggplot(fixed_js, aes(x = xc, y = yc, colour = state)) + 
  geom_path() + 
  geom_point(size=10, x = target$x, y = target$y, colour='black') + 
  xlim(c(-400, 400)) + ylim(c(-600, 200))

# just pull out js events from reach
fixed_js <- fixed_js[state == 'REACH']
fixed_js[, angle := rad2deg(atan2(yc, xc))]
target_angle <- rad2deg(atan2(target$y, target$x))
fixed_js$diff_angle <- sapply(fixed_js$angle, signed_diff_angle, b=target_angle)

# eye movements (TODO: figure out units and such)
eye_mvmts <- trial_3$eye_events
foo <- rbindlist(eye_mvmts)
ggplot(foo, aes(x = t)) + 
  geom_line(aes(y = x), colour='blue') + 
  geom_line(aes(y = y), colour='red') + 
  ylim(c(0, 500))

ggplot(foo[x > 0 & y > 0], aes(x = x, y = y, colour = t)) + 
  geom_path() + 
  xlim(c(0, 1920)) + ylim(c(0, 1080))

state_times <- data.table(state = state_names[trial_3$start_state + 1], time = trial_3$vbl_time)
reach_times <- state_times[state == 'REACH']

ggplot(foo[x > 0 & y > 0 & t > min(reach_times$time) & t < max(reach_times$time)], 
       aes(x = x, y = y, colour = t)) + 
  geom_path() + 
  xlim(c(0, 1920)) + ylim(c(0, 1080))
