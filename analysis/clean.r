
library(data.table)
library(ggplot2)
library(glue)
source('clean_block.r')

# TODO: have data be on a relative path to the analysis
data_files <- list.files('~/Downloads/covert_attn_data/', glob2rx('msl*.json.gz'), full.names=TRUE)

dat <- list()

# TODO: make sure extra data below is written during clean_block instead
# also include trial/reach start time 
for (i in 1:length(data_files)) {
  message(glue('File {i} out of {length(data_files)}: {data_files[i]}'))
  dat[[i]] <- clean_block(data_files[i])
}

clean_dat <- rbindlist(dat)

reach_dat <- clean_dat[reach_or_probe==1]
probe_dat <- clean_dat[reach_or_probe==2]

reach_dat[, lag_clamp_side := shift(clamp_side), by=id]
reach_dat[, delta_angle := endpoint_angle - shift(endpoint_angle), by=id]

# left should be negative delta angle?
