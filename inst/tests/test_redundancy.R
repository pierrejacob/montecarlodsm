rm(list = ls())
library(dempsterpolytope)
library(doParallel)
library(doRNG)
library(latex2exp)
registerDoParallel(cores = detectCores()-2)
graphsettings <- set_custom_theme()
set.seed(1)
attach(graphsettings)
v1 <- v_cartesian[[1]]; v2 <- v_cartesian[[2]]; v3 <- v_cartesian[[3]]
set.seed(4)

K <- 3
categories <- 1:K

## show constraints
barconstraint2cartconstraint <- function(d, j, eta, matrixT, v_cartesian){
  # ccc * (wA wB wC) = 0 with:
  ccc <- rep(0, 3)
  ccc[d] <- 1
  ccc[j] <- - eta
  # which is equivalent to ftilde * (wA wB) = gtilde with
  ftilde <- c(ccc[1] - ccc[3], ccc[2] - ccc[3])
  gtilde <- -ccc[3]
  # we can generically express that as a constraint on x,y through
  f <- solve(t(matrixT), ftilde)
  g <- gtilde + sum(f * v_cartesian[[3]])
  # f1 x + f2 y = g is equivalent to a = g/f2, b = - f1/f2
  return(c(g/f[2], -f[1]/f[2]))
}

add_L2const <- function(g, i1, i2, etas){
  A <- matrix(rep(1, K-1), ncol = K-1)
  A <- rbind(A, diag(-1, K-1, K-1))
  b <- c(1, rep(0, K-1))
  ccc <- rep(0, K)
  ccc[i1] <- 1 
  ccc[i2] <- -etas[i2,i1]
  cc <- ccc - ccc[K]
  b <- c(b, -ccc[K])
  A <- rbind(A, matrix(cc[1:(K-1)], nrow = 1))
  ccc <- rep(0, K)
  ccc[i1] <- -1 
  ccc[i2] <- etas[i1,i2]^{-1}
  cc <- ccc - ccc[K]
  b <- c(b, -ccc[K])
  A <- rbind(A, matrix(cc[1:(K-1)], nrow = 1))
  constr <- list(constr = A, rhs = b, dir = rep("<=", nrow(A)))
  vertices_barcoord <- hitandrun::findVertices(constr)
  vertices_barcoord <- cbind(vertices_barcoord, 1- apply(vertices_barcoord, 1, sum))
  vertices_cart <- t(apply(vertices_barcoord, 1, function(v) barycentric2cartesian(v, v_cartesian)))
  g <- g + geom_polygon(data=data.frame(x = vertices_cart[,1], y= vertices_cart[,2]), alpha = 0.5)
  return(g)
}
add_L3const <- function(g, i1, i2, i3, etas){
  ## constraint of the form eta_12 eta_23 eta_31 >= 1 
  # theta_1/theta_2 < eta_21 
  # theta_2/theta_3 < eta_32
  # theta_3/theta_1 < eta_13
  A <- matrix(rep(1, K-1), ncol = K-1)
  A <- rbind(A, diag(-1, K-1, K-1))
  b <- c(1, rep(0, K-1))
  ccc <- rep(0, K)
  ccc[i1] <- 1 
  ccc[i2] <- -etas[i2,i1]
  cc <- ccc - ccc[K]
  b <- c(b, -ccc[K])
  A <- rbind(A, matrix(cc[1:(K-1)], nrow = 1))
  ccc <- rep(0, K)
  ccc[i2] <- 1 
  ccc[i3] <- -etas[i3,i2]
  cc <- ccc - ccc[K]
  b <- c(b, -ccc[K])
  A <- rbind(A, matrix(cc[1:(K-1)], nrow = 1))
  ccc <- rep(0, K)
  ccc[i3] <- 1 
  ccc[i1] <- -etas[i1,i3]
  cc <- ccc - ccc[K]
  b <- c(b, -ccc[K])
  A <- rbind(A, matrix(cc[1:(K-1)], nrow = 1))
  constr <- list(constr = A, rhs = b, dir = rep("<=", nrow(A)))
  vertices_barcoord <- hitandrun::findVertices(constr)
  vertices_barcoord <- cbind(vertices_barcoord, 1- apply(vertices_barcoord, 1, sum))
  vertices_cart <- t(apply(vertices_barcoord, 1, function(v) barycentric2cartesian(v, v_cartesian)))
  g <- g + geom_polygon(data=data.frame(x = vertices_cart[,1], y= vertices_cart[,2]), alpha = 0.5)
  return(g)
}

etas <- structure(c(1, 3.97840569581908, 5.78277269927406, 0.50153243920328, 
                    1, 2.40371666744944, 0.254985206727502, 1.10872229394467, 1), .Dim = c(3L, 
                                                                                           3L))


### Constraint violations
g <- create_plot_triangle(graphsettings)
etas1 <- etas
etas1[2,3] <- 5
etas1[3,1] <- 2

for (d in categories){
  # set indices for two other components
  j1 <- setdiff(categories, d)[1]
  j2 <- setdiff(categories, d)[2]
  interslope_j1 <- barconstraint2cartconstraint(d, j1, 1/etas1[d, j1], matrixT, v_cartesian)
  interslope_j2 <- barconstraint2cartconstraint(d, j2, 1/etas1[d, j2], matrixT, v_cartesian)
  g <- g + geom_abline(intercept = interslope_j1[1], slope = interslope_j1[2], colour = contcols[d], linetype = 2)
  g <- g + geom_abline(intercept = interslope_j2[1], slope = interslope_j2[2], colour = contcols[d], linetype = 2)
  intersection_12 <- get_line_intersection(interslope_j1, interslope_j2)
}
g <- add_L3const(add_L3const(g, 1, 2, 3, etas1), 3, 2, 1, etas1)
g
# ggsave(filename = "violateconstraintsL2.pdf", plot = g, width = 5, height = 5)

g <- create_plot_triangle(graphsettings)
etas1 <- etas
etas1[1,2] <- 10 
etas1[2,1] <- 0.2 

for (d in categories){
  # set indices for two other components
  j1 <- setdiff(categories, d)[1]
  j2 <- setdiff(categories, d)[2]
  interslope_j1 <- barconstraint2cartconstraint(d, j1, 1/etas1[d, j1], matrixT, v_cartesian)
  interslope_j2 <- barconstraint2cartconstraint(d, j2, 1/etas1[d, j2], matrixT, v_cartesian)
  g <- g + geom_abline(intercept = interslope_j1[1], slope = interslope_j1[2], colour = contcols[d], linetype = 2)
  g <- g + geom_abline(intercept = interslope_j2[1], slope = interslope_j2[2], colour = contcols[d], linetype = 2)
  intersection_12 <- get_line_intersection(interslope_j1, interslope_j2)
}
# g <- add_L3const(add_L3const(g, 1, 2, 3, etas1), 3, 2, 1, etas1)
g <- add_L2const(g, 1, 2, etas1)
g <- add_L2const(g, 1, 3, etas1)
g <- add_L2const(g, 2, 3, etas1)
g

# ggsave(filename = "violateconstraintsL3.pdf", plot = g, width = 5, height = 5)
