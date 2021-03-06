### This scripts illustrates that inference obtained with or without empty categories are not the same.
rm(list = ls())
library(dempsterpolytope)
library(doParallel)
library(doRNG)
registerDoParallel(cores = detectCores()-2)
graphsettings <- set_custom_theme()
set.seed(1)
theme_set(ggthemes::theme_tufte(ticks = TRUE))
theme_update(axis.text.x = element_text(size = 20), axis.text.y = element_text(size = 20), 
             axis.title.x = element_text(size = 25, margin = margin(20, 0, 0, 0), hjust = 1), 
             axis.title.y = element_text(size = 25, angle = 90, margin = margin(0, 20, 0, 0), vjust = 1), 
             legend.text = element_text(size = 20), 
             legend.title = element_text(size = 20), title = element_text(size = 30), 
             strip.text = element_text(size = 25), strip.background = element_rect(fill = "white"), 
             legend.position = "bottom")


# number of categories
K <- 3
categories <- 1:K
# data 
counts <- c(4,3,0)
cat("Data:", counts, "\n")
##

NREP <- 100
lag <- 30
meetings <- unlist(foreach(irep = 1:NREP) %dorng% {
  sample_meeting_times(counts, lag = lag)
})

ubounds <- sapply(1:(1.2*lag), function(t) tv_upper_bound(meetings, lag, t))
gtvbounds <- ggplot(data=data.frame(t = seq_along(ubounds), ubounds = ubounds), 
                    aes(x = t, y = ubounds)) + geom_line() + ylab("TV upper bounds") + xlab("iteration")
gtvbounds


niterations <- 5000
samples_gibbs_K3 <- gibbs_sampler(niterations, counts)
warmup <- 50
subiterations <- (warmup+1):niterations
etas_K3 <- samples_gibbs_K3$etas[subiterations,,]

## in order to obtain the lower CDF, we need to check if polytope is contained in [0,a) for different a 
## for which we need to max coordinate and check if less than a
## for the upper CDF we need to check intersection, so we need min coordinate and check less than a

min1st <- foreach(ieta = 1:(dim(etas_K3)[1]), .combine = c) %dopar% {
  lpsolve_over_eta(etas_K3[ieta,,], c(1, rep(0, K-1)))
}
max1st <- foreach(ieta = 1:(dim(etas_K3)[1]), .combine = c) %dopar% {
  -lpsolve_over_eta(etas_K3[ieta,,], c(-1, rep(0, K-1)))
}

ecdf_lower <- ecdf(max1st)
ecdf_upper <- ecdf(min1st)

ggplot() + xlab(expression(theta[1])) + ylab("CDF") + xlim(0,1) + ylim(0,1) +
  stat_function(fun = ecdf_lower, colour = 'black', linetype = 1) + stat_function(fun = ecdf_upper, colour = 'black', linetype = 2)

## suppose do inferene using only 2 non empty category and then manipulate
samples_gibbs_K2 <- gibbs_sampler(niterations, counts[1:2])
etas_K2 <- samples_gibbs_K2$etas[subiterations,,]
## extend from K = 2
pts_extended_from_K2 <- list()
for (category in 1:2){
  pts_extended_from_K2[[category]] <- array(NA, dim = c(niterations, counts[category], 3))
  for (iter in 1:niterations){
    for (iA in 1:counts[category]){
      oldA <- samples_gibbs_K2$Us[[category]][iter,iA,]
      s <- rgamma(1, 2, 1)
      w <- rexp(1, 1)
      pts_extended_from_K2[[category]][iter,iA,] <- c(s * oldA / (s + w), w / (s + w))
    } 
  }
}
## next compute new etas
etas_K3_alt <- array(NA, dim = c(niterations, 3, 3))
## etas[k,l] = min_u u_l/u_k
for (iter in 1:niterations){
  etas_K3_alt[iter,1:2,1:2] <- samples_gibbs_K2$etas[iter,,] 
  etas_K3_alt[iter,3,] <- Inf
  for (category in 1:2){
    etas_K3_alt[iter,category,3] <- min(pts_extended_from_K2[[category]][iter,,3]/pts_extended_from_K2[[category]][iter,,category]) 
  }
}

min1st_alt <- foreach(ieta = 1:(dim(etas_K3_alt)[1]), .combine = c) %dopar% {
  lpsolve_over_eta(etas_K3_alt[ieta,,], c(1, rep(0, K-1)))
}
max1st_alt <- foreach(ieta = 1:(dim(etas_K3_alt)[1]), .combine = c) %dopar% {
  -lpsolve_over_eta(etas_K3_alt[ieta,,], c(-1, rep(0, K-1)))
}

ecdf_lower_alt <- ecdf(max1st_alt)
ecdf_upper_alt <- ecdf(min1st_alt)
##

# lower / upper 
galt <- ggplot() + xlim(0,1) + ylim(0,1) + xlab(expression(theta[1])) + ylab("CDF") +
 stat_function(fun = ecdf_lower, colour = 'red', linetype = 1) + stat_function(fun = ecdf_upper, colour = 'red', linetype = 2) + 
  stat_function(fun = ecdf_lower_alt, colour = 'blue', linetype = 1) + stat_function(fun = ecdf_upper_alt, colour = 'blue', linetype = 2)
galt
## agreement

## compare CDF obtained with only 2 categories
min1st_K2 <- foreach(ieta = 1:(dim(etas_K2)[1]), .combine = c) %dopar% {
  lpsolve_over_eta(etas_K2[ieta,,], c(1, 0))
}
max1st_K2 <- foreach(ieta = 1:(dim(etas_K2)[1]), .combine = c) %dopar% {
  -lpsolve_over_eta(etas_K2[ieta,,], c(-1, 0))
}

ecdf_lower_K2 <- ecdf(max1st_K2)
ecdf_upper_K2 <- ecdf(min1st_K2)

galt <- ggplot() + xlim(0,1) + ylim(0,1) + xlab(expression(theta[1])) + ylab("CDF") +
  stat_function(fun = ecdf_lower, colour = 'red', linetype = 1) + stat_function(fun = ecdf_upper, colour = 'red', linetype = 2) + 
  stat_function(fun = ecdf_lower_K2, colour = 'blue', linetype = 1) + stat_function(fun = ecdf_upper_K2, colour = 'blue', linetype = 2)
galt

### 'r' don't know proba increases
### clean graph
xgrid <- seq(from = 0, to = 1, length.out = 500)
ylower <- ecdf_lower(xgrid)
yupper <- ecdf_upper(xgrid)
gtheta1 <- ggplot() + xlim(0,1) + ylim(0,1) + xlab(expression(theta[1])) + ylab("cdf") + 
  geom_ribbon(data = data.frame(x = xgrid, ymin = ylower, ymax = yupper), aes(x = x, ymin = ymin, ymax = ymax, y = NULL, fill = '3',
                                                                              colour = '3'), alpha = 0.5)
ylowerK2 <- ecdf_lower_K2(xgrid)
yupperK2 <- ecdf_upper_K2(xgrid)
gtheta1 <- gtheta1 + geom_ribbon(data = data.frame(x = xgrid, ymin = ylowerK2, ymax = yupperK2), 
                      aes(x = x, ymin = ymin, ymax = ymax, y = NULL, fill = '2', colour = '2'), alpha = 0.5) 
gtheta1 <- gtheta1  + theme(legend.position = 'bottom') + scale_fill_manual(name = "K: ", values = c("black", "grey")) +
  scale_colour_manual(name = "K: ", values = c("black", "grey"))
gtheta1

ggsave(plot = gtheta1, filename = "emptycategory1.pdf", width = 6, height = 4)

## however if we look at theta1/theta2 
min1st_K2 <- foreach(ieta = 1:(dim(etas_K2)[1]), .combine = c) %dopar% {
  lpsolve_over_eta_log(etas_K2[ieta,,], c(1, -1))
}
max1st_K2 <- foreach(ieta = 1:(dim(etas_K2)[1]), .combine = c) %dopar% {
  -lpsolve_over_eta_log(etas_K2[ieta,,], c(-1, +1))
}
ecdf_lower_ratio_K2 <- ecdf(max1st_K2)
ecdf_upper_ratio_K2 <- ecdf(min1st_K2)
min1st_K3 <- foreach(ieta = 1:(dim(etas_K3)[1]), .combine = c) %dopar% {
  lpsolve_over_eta_log(etas_K3[ieta,,], c(1, -1, 0))
}
max1st_K3 <- foreach(ieta = 1:(dim(etas_K3)[1]), .combine = c) %dopar% {
  -lpsolve_over_eta_log(etas_K3[ieta,,], c(-1, +1, 0))
}
ecdf_lower_ratio_K3 <- ecdf(max1st_K3)
ecdf_upper_ratio_K3 <- ecdf(min1st_K3)


ggplot() + xlim(-3,+3) + ylim(0,1) + xlab(expression(log(theta[1]/theta[2]))) + ylab("CDF") +
  stat_function(fun = ecdf_lower_ratio_K2, colour = 'red', linetype = 1) + stat_function(fun = ecdf_upper_ratio_K2, colour = 'red', linetype = 1) +
  stat_function(fun = ecdf_lower_ratio_K3, colour = 'blue', linetype = 2) + stat_function(fun = ecdf_upper_ratio_K3, colour = 'blue', linetype = 2)
### 

### clean graph
xgrid <- seq(from = -4, to = 4, length.out = 500)
ylower = ecdf_lower_ratio_K3(xgrid)
yupper = ecdf_upper_ratio_K3(xgrid)
ylowerK2 = ecdf_lower_ratio_K2(xgrid)
yupperK2 = ecdf_upper_ratio_K2(xgrid)

gratio <- ggplot() + xlim(-4,4) + ylim(0,1) + xlab(expression(log(theta[1]/theta[2]))) + ylab("cdf") + 
  geom_ribbon(data = data.frame(x = xgrid, ymin = ylower, ymax = yupper), aes(x = x, ymin = ymin, ymax = ymax, y = NULL, fill = '2 or 3',
                                                                              colour = '2 or 3'), alpha = 0.5)
gratio <- gratio  + theme(legend.position = 'bottom') + scale_fill_manual(name = "K: ", values = c("black")) +
  scale_colour_manual(name = "K: ", values = c("black", "grey"))
gratio

ggsave(plot = gratio, filename = "emptycategory2.pdf", width = 6, height = 4)



