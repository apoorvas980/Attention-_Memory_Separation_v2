
library(data.table)
library(ggplot2)
source('clean_block.r')

# TODO: have data be on a relative path to the analysis
data_files <- list.files('~/Downloads/covert_attn_data/', glob2rx('msl*.json.gz'), full.names=TRUE)

dat <- list()

for (i in 1:length(data_files)) {
  dat[[i]] <- clean_block(data_files[i])
}

dat <- rbindlist(dat)
