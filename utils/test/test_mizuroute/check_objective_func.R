library(ncdf4)
library(hydroGOF)

source("utils/test/test_regression/plot_utils.R")

# run bow_real_data first (see its README) to produce sim_file
sim_file <- "utils/test/test_mizuroute/bow_real_data/work/run1_coupled_timestep.nc"
obs_file <- "utils/test/test_mizuroute/bow_real_data/mizuroute_inputs/CAN_05BB001_daily_flow_observations.nc"

# evaluation period
start_date <- as.POSIXct("1982-10-01", tz="UTC")
end_date   <- as.POSIXct("1983-09-30 23:59:59", tz="UTC")

# ------------------------------------------------------------
# observations
# ------------------------------------------------------------

nc_obs <- nc_open(obs_file)

time_obs <- ncvar_get(nc_obs, "time")
q_obs    <- ncvar_get(nc_obs, "q_obs")

nc_close(nc_obs)

date_obs <- as.POSIXct("1950-01-01", tz="UTC") + time_obs * 60

# ------------------------------------------------------------
# simulation
# ------------------------------------------------------------

nc_sim <- nc_open(sim_file)

time_sim <- ncvar_get(nc_sim, "time")
q_reach  <- ncvar_get(nc_sim, "Q_reach")
up_area  <- ncvar_get(nc_sim, "upArea")
seg      <- ncvar_get(nc_sim, "seg")

time_units <- ncatt_get(nc_sim, "time", "units")$value

# aligned evaluation series written by write_evaluation() when the TOML's
# [objective] write_aligned = true (see build/source/objfunc/write_evaluation.f90)
has_eval <- "eval_qsim" %in% names(nc_sim$var)
if (has_eval) {
  eval_time  <- ncvar_get(nc_sim, "eval_time")
  eval_qobs  <- ncvar_get(nc_sim, "eval_qobs")
  eval_qsim  <- ncvar_get(nc_sim, "eval_qsim")
  eval_units <- ncatt_get(nc_sim, "eval_time", "units")$value
  objective  <- ncvar_get(nc_sim, "objective")
}

nc_close(nc_sim)

# outlet = segment with largest upstream drainage area
i_seg <- which.max(up_area)

q_sim <- q_reach[i_seg, ]

date_sim <- nc_time(time_sim, time_units)

# ------------------------------------------------------------
# aggregate hourly simulation to daily period-ending means
# exactly as done in Fortran:
#
#     time_obs - 1 day < time_sim <= time_obs
# ------------------------------------------------------------

sim_daily <- data.frame(
  time  = date_obs,
  q_sim = NA_real_
)

for(i in seq_along(date_obs)) {

  t_end   <- date_obs[i]
  t_start <- t_end - 86400

  ix <- date_sim > t_start & date_sim <= t_end

  if(any(ix)) {
    sim_daily$q_sim[i] <- mean(q_sim[ix], na.rm=TRUE)
  }
}

names(sim_daily)[2] <- "q_sim"

# ------------------------------------------------------------
# merge model simulations and observations 
# ------------------------------------------------------------

obs <- data.frame(
  time=date_obs,
  q_obs=q_obs
)

dat <- merge(obs, sim_daily, by="time")

# evaluation period
dat <- subset(
  dat,
  time >= start_date &
  time <= end_date
)

# remove missing values
dat <- dat[
  is.finite(dat$q_obs) &
  is.finite(dat$q_sim),
]

# ------------------------------------------------------------
# calculate performance metrics 
# ------------------------------------------------------------

kge <- KGE(dat$q_sim, dat$q_obs)
nse <- NSE(dat$q_sim, dat$q_obs)
rmse <- sqrt(mean((dat$q_obs - dat$q_sim)^2))
mae  <- mean(abs(dat$q_obs - dat$q_sim))

cat("\nR\n")
cat("KGE  =", kge, "\n")
cat("NSE  =", nse, "\n")
cat("RMSE =", rmse, "\n")
cat("MAE  =", mae, "\n")

# ------------------------------------------------------------
# plot
# ------------------------------------------------------------

if (has_eval) {

  date_eval <- nc_time(eval_time, eval_units)

  kge <- KGE(eval_qsim, eval_qobs)
  nse <- NSE(eval_qsim, eval_qobs)
  rmse <- sqrt(mean((eval_qobs - eval_qsim)^2))
  mae  <- mean(abs(eval_qobs - eval_qsim))

  cat("\nFortran (eval_qobs/eval_qsim in", sim_file, ")\n")
  cat("KGE       =", kge, "\n")
  cat("NSE       =", nse, "\n")
  cat("RMSE      =", rmse, "\n")
  cat("MAE       =", mae, "\n")
  cat("objective =", objective, "(as written by write_evaluation())\n")

} else {
  cat("\nNo eval_qobs/eval_qsim in", sim_file, "\n")
  cat("Set write_aligned = true under [objective] in the TOML config and rerun to compare.\n")
}

plot(
  dat$time,
  dat$q_obs,
  type="n",
  xlab="Date",
  ylab=expression(Streamflow~(m^3/s))
)

# R alignment
lines(dat$time, dat$q_obs, col="darkblue")
lines(dat$time, dat$q_sim, col="lightblue")

legend_labels <- c("Observed (R)", "Simulated (R)")
legend_colors <- c("darkblue", "lightblue")

if (has_eval) {
  # Fortran alignment
  lines(date_eval, eval_qobs, col="red")
  lines(date_eval, eval_qsim, col="orange")

  legend_labels <- c(legend_labels, "Observed (Fortran)", "Simulated (Fortran)")
  legend_colors <- c(legend_colors, "red", "orange")
}

legend(
  "topright",
  legend_labels,
  col=legend_colors,
  lty=1
)
