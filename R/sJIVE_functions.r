##################################################
# By: Ellie Palzer
# Project: sJIVE 
# Goal: Cleaned functions
# Date: October 1, 2020
##################################################

#Note: Must have r.jive R package installed to run this

sJIVE.converge <- function(X, Y, eta=NULL, max.iter=1000, threshold = 0.001,
                  show.error =F, rankJ=NULL, rankA=NULL, 
                  show.message=T, reduce.dim=T, center.scale=T){
  #X = list(X_1  X_2  ... X_k) with each row centered and scaled
  #Y is continuous vector centered and scaled
  #eta is between 0 and 1, when eta=NULL, no weighting is done
  #rank is prespecified rank of svd approximation
  
  
  optim.error <- function(X.tilde, U, theta1, Sj, W, Si, theta2, k, obs){
    WS <- NULL; thetaS <- 0
    for(i in 1:k){
      temp <- W[[i]] %*% Si[[i]]
      WS <- rbind(WS, temp)
      thetaS <- thetaS + theta2[[i]] %*% Si[[i]]
    }
    WS.new <- rbind(WS, thetaS)
    error  <- norm(X.tilde - rbind(U, theta1) %*% Sj - WS.new, type = "F")^2
    return(error)
  }
  
  
  #Set Ranks 
  if(is.null(rankJ) | is.null(rankA)){
    temp <- sJIVE.ranks(X,Y, eta=eta, max.iter = max.iter)
    rankJ <- temp$rankJ
    rankA <- temp$rankA
    cat(paste0("Using rankJ= ", rankJ, " and rankA= ", paste(rankA, collapse = " "), "\n"))
  }
  k <- length(X)
  
  
  if(center.scale){
    Y <- as.numeric(scale(as.numeric(Y)))
    for(i in 1:k){
      for(j in 1:nrow(X[[i]])){
        X[[i]][j,] <- as.numeric(scale(as.numeric(X[[i]][j,])))
      }
    }
  }
  
  k <- length(X)
  n <- ncol(X[[1]])
  svd.bigX <- list()
  for(i in 1:k){
    if(ncol(X[[i]]) != n){
      stop("Number of columns differ between datasets")
    }
    if(nrow(X[[i]])>n & reduce.dim){
      svd.bigX[[i]]<- svd(X[[i]], nu=n)
      if(svd.bigX[[i]]$u[1,1]<0){
        svd.bigX[[i]]$u <- svd.bigX[[i]]$u *-1
        svd.bigX[[i]]$v <- svd.bigX[[i]]$v *-1
      }
      X[[i]] <- diag(svd.bigX[[i]]$d) %*% t(svd.bigX[[i]]$v)
    }else{
      svd.bigX[[i]]<-NULL
    }
  }
  svd.bigX[[k+1]] <- 1
  
  #Step 1: Initialize values
  k <- length(X)
  obs <- list(); temp <- 0
  for(i in 1:k){  
    max.obs <- max(temp)
    temp <- (max.obs+1):(max.obs+nrow(X[[i]]))
    obs[[i]] <- temp
  }
  X.tilde <- NULL
  if(is.null(eta)==T){
    for(i in 1:k){X.tilde <- rbind(X.tilde, X[[i]]) }
    X.tilde <- rbind(X.tilde, Y)
  }else{
    for(i in 1:k){X.tilde <- rbind(X.tilde, sqrt(eta) * X[[i]])}
    X.tilde <- rbind(X.tilde, sqrt(1-eta)* Y)
  }
  y <- nrow(X.tilde)
  n <- ncol(X.tilde)
  
  #Initialize U, theta1, and Sj 
  if(rankJ == 0){
    X.svd <- svd(X.tilde, nu=1, nv=1)
    U.new <- U.old <- as.matrix(X.svd$u[-y,]) * 0
    theta1.new <- theta1.old <- t(as.matrix(X.svd$u[y,])) * 0
    Sj.new <- Sj.old <- as.matrix(X.svd$d[1] * t(X.svd$v)) * 0
  }else{
    X.svd <- svd(X.tilde, nu=rankJ, nv=rankJ)
    U.new <- U.old <- as.matrix(X.svd$u[-y,])
    theta1.new <- theta1.old <- t(as.matrix(X.svd$u[y,]))
    if(rankJ==1){Sj.new <- Sj.old <- as.matrix(X.svd$d[1] * t(X.svd$v))
    }else{Sj.new <- Sj.old <- diag(X.svd$d[1:rankJ]) %*% t(X.svd$v) }
  }
  
  #Initialize W and S_i = 0
  W.old <- S.old <- theta2.old <- list() 
  WS <- NULL
  for(i in 1:k){  
    #Get Wi, Si, and theta2i
    X.tilde_i <- X.tilde[c(obs[[i]],y),]
    yi <- nrow(X.tilde_i)
    xi <- (X.tilde_i - rbind(as.matrix(U.new[obs[[i]],]), theta1.new) %*% Sj.new)
    if(rankJ==0){
      vi <- diag(rep(1,n)) 
    }else{
      vi <- diag(rep(1,n)) -  X.svd$v %*% t(X.svd$v)
    }
    if(rankA[i] == 0){
      X2.svd <- svd(xi, nu=1, nv=1)
      W.old[[i]] <- as.matrix(X2.svd$u[-yi,]) *0
      theta2.old[[i]] <- t(as.matrix(X2.svd$u[yi,])) *0
      S.old[[i]] <- as.matrix(X2.svd$d[1] * t(X2.svd$v)) *0
    }else{
      X2.svd <- svd(xi %*% vi, nu=rankA[i], nv=rankA[i])
      W.old[[i]] <- as.matrix(X2.svd$u[-yi,])
      theta2.old[[i]] <- t(as.matrix(X2.svd$u[yi,]))
      if(rankA[i]==1){S.old[[i]] <- as.matrix(X2.svd$d[1] * t(X2.svd$v))
      }else{S.old[[i]] <- diag(X2.svd$d[1:rankA[i]]) %*% t(X2.svd$v) }
    }
    WS <- rbind(WS, W.old[[i]] %*% S.old[[i]])
  }
  error.old <- optim.error(X.tilde, U.old, theta1.old, Sj.old, W.old, S.old, theta2.old, k, obs)
  if(show.error){cat(paste0("Iter: ", 0, "  Error: ", error.old, "\n"))}
  e.vec <- NULL
  S.new <- S.old
  theta2.new <- theta2.old
  W.new <- W.old
  thetaS.sum <- matrix(rep(0,n), ncol=n)
  
  #Step 2: Interatively optimize problem
  for(iter in 1:max.iter){
    #Get U, theta1, and Sj 
    if(rankJ >0){
      X.svd <- svd(X.tilde-rbind(WS, thetaS.sum), nu=rankJ, nv=rankJ)
      neg <- sign(X.svd$u[1,1])
      U.new <- as.matrix(X.svd$u[-y,]) * neg
      theta1.new <- t(as.matrix(X.svd$u[y,])) *neg
      if(rankJ==1){Sj.new <- X.svd$d[1] * t(X.svd$v) * neg
      }else{Sj.new <- diag(X.svd$d[1:rankJ]) %*% t(X.svd$v) * neg }
    }
    
    if(show.error){
      e <- optim.error(X.tilde, U.new, theta1.new, Sj.new, W.old, S.old, theta2.old, k, obs)
      cat(paste0("Iter: ", iter, "  Error: ", e, "  Updated: U, theta1, Sj \n"))
    }
    
    #Get Wi, Si, and theta2i
    thetaS.sum <- 0; WS <- NULL
    for(i in 1:k){
      thetaS <-0
      for(j in 1:k){if(j != i){ thetaS <- thetaS + theta2.new[[j]] %*% S.new[[j]]}}
      X.tilde_i <- X.tilde[c(obs[[i]],y),]
      yi <- nrow(X.tilde_i)
      X.tilde_i[yi,] <- X.tilde_i[yi,] - thetaS
      
      if(rankA[i]>0){
        #Get Wi, Si, and theta2i
        xi <- (X.tilde_i - rbind(as.matrix(U.new[obs[[i]],]), theta1.new) %*% Sj.new)
        if(rankJ==0){
          vi <- diag(rep(1,n))
        }else{
          vi <- diag(rep(1,n)) -  X.svd$v %*% t(X.svd$v) 
        }
        X2.svd <- svd(xi %*% vi, nu=rankA[i], nv=rankA[i])
        
        #X2.svd <- svd(X.tilde_i - rbind(as.matrix(U.new[obs[[i]],]), theta1.new) %*% Sj.new, nu=rankA[i], nv=rankA[i])
        neg2 <- sign(X2.svd$u[1,1])
        W.new[[i]] <- as.matrix(X2.svd$u[-yi,]) * neg2
        theta2.new[[i]] <- t(as.matrix(X2.svd$u[yi,])) * neg2
        if(rankA[i]==1){S.new[[i]] <- as.matrix(X2.svd$d[1] * t(X2.svd$v)) * neg2
        }else{S.new[[i]] <- diag(X2.svd$d[1:rankA[i]]) %*% t(X2.svd$v) * neg2}
      }
      
      #prep for next iteration
      thetaS.sum <- thetaS.sum + theta2.new[[i]] %*% S.new[[i]]
      WS <- rbind(WS, W.new[[i]] %*% S.new[[i]])
      
      if(show.error){
        e <- optim.error(X.tilde, U.new, theta1.new, Sj.new, W.new, S.new, theta2.new, k, obs)
        cat(paste0("Iter: ", iter, "  Error: ", e, "  Updated: Wi, theta2i, Si  i=", i, "\n"))
      }
    }
    
    #Figure out the error
    error <- optim.error(X.tilde, U.new, theta1.new, Sj.new, W.new, S.new, theta2.new, k, obs)
    if(abs(error.old-error) < threshold){
      #If converged, then stop loop
      if(show.message){cat(paste0("Converged in ", iter, " iterations \n"))}
      break
    }else if(iter == max.iter){
      if(show.message){cat(paste0("Warning: ", iter, " iterations reached \n"))}
      break
    }else{
      #If didn't converge, prep for another loop
      e.vec <- c(e.vec, error)
      U.old <- U.new
      W.old <- W.new
      theta2.old <- theta2.new 
      theta1.old <- theta1.new
      Sj.old <- Sj.new
      S.old <- S.new
      error.old <- error
    }
  }
  
  #Scale so first value in U and W are always positive
  if(U.new[1,1]<0){
    U.new <- -1 * U.new
    theta1.new <- -1 * theta1.new
    Sj.new <- -1 * Sj.new
  }
  for(i in 1:k){
    if(W.new[[i]][1,1]<0){
      W.new[[i]] <- W.new[[i]] * -1
      theta_2[[i]] <- theta_2[[i]] * -1
      S.new[[i]] <- S.new(i) * -1
    }
  }
  
  
  #Step 3: Export the results
  U_i <- W <- theta_2 <- list()
  if(is.null(eta)){
    for(i in 1:k){
      U_i[[i]] <- U.new[obs[[i]],]
    }
    theta_1 <- theta1.new
    W <- W.new
    theta_2 <- theta2.new
  }else{
    theta_1 <- (1/sqrt(1-eta)) * theta1.new
    U.new<- (1/sqrt(eta)) * U.new
    for(i in 1:k){ 
      W[[i]] <- (1/sqrt(eta)) * W.new[[i]]
      theta_2[[i]] <- (1/sqrt(1-eta)) * theta2.new[[i]]
    }
    #ReScale to be norm 1
    for(j in 1:ncol(U.new)){
      U.norm <-norm(rbind(as.matrix(U.new[,j]), theta_1[j]),type="F")^2 
      if(U.norm==0){
        U.new[,j] <- as.matrix(U.new[,j])
        theta_1[j] <- theta_1[j]
      }else{
        U.new[,j] <- as.matrix(U.new[,j])/sqrt(U.norm)
        theta_1[j] <- theta_1[j]/sqrt(U.norm)
      }
      Sj.new[j,] <- Sj.new[j,] * sqrt(U.norm)
    }
    for(i in 1:k){
      for(j in 1:ncol(W[[i]])){
        W.norm <-norm(rbind(as.matrix(W[[i]][,j]),theta_2[[i]][j]),type="F")^2 
        if(W.norm==0){
          W[[i]][,j] <- as.matrix(W[[i]][,j])
          theta_2[[i]][j] <- theta_2[[i]][j]
        }else{
          W[[i]][,j] <- as.matrix(W[[i]][,j])/sqrt(W.norm)
          theta_2[[i]][j] <- theta_2[[i]][j]/sqrt(W.norm)
        }
        S.new[[i]][j,] <- S.new[[i]][j,] * sqrt(W.norm)
        U_i[[i]] <- U.new[obs[[i]],]
      }
    }
    
  }
  
  Ypred <- theta_1 %*% Sj.new
  for(i in 1:k){
    Ypred <- Ypred + theta_2[[i]] %*% S.new[[i]]
  }
  
  
  #Map X back to original space
  for(i in 1:k){
    if(is.null(svd.bigX[[i]]) == FALSE){
      U_i[[i]] <- svd.bigX[[i]]$u %*% U_i[[i]]
      W[[i]] <- svd.bigX[[i]]$u %*% W[[i]]
    }
  }
  
  return(list(S_J=Sj.new, S_I=S.new, U_I=U_i, W_I=W,
              theta1=theta_1, theta2=theta_2, fittedY=Ypred,
              error=error, all.error=e.vec,
              iterations = iter, rankJ=rankJ, rankA=rankA, eta=eta))
}


sJIVE.predict <- function(sJIVE.fit, newdata, threshold = 0.001, max.iter=2000){
  ##############################################
  # sJIVE.fit is the output from sJIVE
  # newdata is list with the same predictors and
  #     number of datasets as used in sJIVE.fit
  ##############################################
  sJIVE.pred.err <- function(X.tilde, U, Sj, W, Si, k){
    J <- A <- NULL
    for(i in 1:k){
      J <- rbind(J, as.matrix(U[[i]]) %*% as.matrix(Sj))
      A <- rbind(A, as.matrix(W[[i]]) %*% as.matrix(Si[[i]]))
    }
    temp <- X.tilde - J - A
    error <- norm(temp, type = "F")^2
    return(error)
  }
  
  
  
  if(sJIVE.fit$rankJ==0 & sum(sJIVE.fit$rankA)==0){
    return(list(Ypred = 0,
                Sj = 0,
                Si = 0,
                iteration = 0,
                error = NA))
  }
  
  #Initalize values
  k <- length(newdata)
  n <- ncol(newdata[[1]])
  W <- sJIVE.fit$W_I
  U <- sJIVE.fit$U_I
  rankJ <- ncol(as.matrix(U[[1]]))
  Sj <- matrix(rep(0,rankJ*n), ncol = n)
  
  obs <- rankA <- Si <- list(); temp <- 0; X.tilde <- NULL
  for(i in 1:k){  
    max.obs <- max(temp)
    temp <- (max.obs+1):(max.obs+nrow(newdata[[i]]))
    obs[[i]] <- temp
    
    X.tilde <- rbind(X.tilde, newdata[[i]])
    
    rankA[[i]] <- ncol(as.matrix(W[[i]]))
    Si[[i]] <- matrix(rep(0, rankA[[i]]*n), ncol=n)
  }
  
  #Get Error
  error.old <- sJIVE.pred.err(X.tilde, U, Sj, W, Si, k)
  
  for(iter in 1:max.iter){
    
    #Update Sj
    U.mat <- A <- NULL
    for(i in 1:k){
      U.mat <- rbind(U.mat, as.matrix(U[[i]]))
      A <- rbind(A, as.matrix(W[[i]]) %*% as.matrix(Si[[i]]))
    }
    Sj <- t(U.mat) %*% (X.tilde - A)
    
    #Update Si
    for(i in 1:k){
      Si[[i]] <- t(W[[i]]) %*% (newdata[[i]] - U[[i]] %*% Sj)
    }
    
    #Get Error
    error.new <- sJIVE.pred.err(X.tilde, U, Sj, W, Si, k)
    
    #Check for Convergence
    if(abs(error.old - error.new) < threshold){
      break
    }else{
      error.old <- error.new
    }
  }
  
  Ypred <- sJIVE.fit$theta1 %*% Sj
  for(i in 1:k){
    Ypred <- Ypred + sJIVE.fit$theta2[[i]] %*% Si[[i]]
  }
  
  return(list(Ypred = Ypred,
              Sj = Sj,
              Si = Si,
              iteration = iter,
              error = error.new))
}


sJIVE.ranks <- function(X, Y, eta=NULL, max.iter=1000, threshold = 0.01,
                        max.rank=100, center.scale=T,
                        reduce.dim=T){
  cat("Estimating joint and individual ranks via cross-validation... \n")
  k <- length(X)
  n <- ncol(X[[1]])
  
  #get cv folds
  fold <- list()
  cutoff <- round(quantile(1:n, c(.2,.4,.6,.8)))
  fold[[1]] <- 1:cutoff[1]
  fold[[2]] <- (cutoff[1]+1):cutoff[2]
  fold[[3]] <- (cutoff[2]+1):cutoff[3]
  fold[[4]] <- (cutoff[3]+1):cutoff[4]
  fold[[5]] <- (cutoff[4]+1):n
  
  rankJ <- 0
  rankA <- rep(0,k)
  
  #initialize error
  error.old  <- NULL
  for(i in 1:5){
    #get X train, Y.train
    train.X <- test.X <- list()
    for(j in 1:k){
      train.X[[j]] <- X[[j]][,-fold[[i]]]
      test.X[[j]] <- X[[j]][,fold[[i]]] 
    }
    train.Y <- Y[-fold[[i]]]
    test.Y <- Y[fold[[i]]]
    fit.old <- sJIVE.converge(train.X, train.Y, eta=eta, max.iter = max.iter, 
                     rankJ = rankJ, rankA = rankA, show.message = F, 
                     center.scale=center.scale,
                     reduce.dim=reduce.dim)
    new.data <- sJIVE.predict(fit.old, test.X) 
    error.old <- c(error.old, sum((new.data$Ypred-test.Y)^2) )
  }
  err.old <- mean(error.old)
  
  #iteravely add ranks
  for(iter in 1:1000){
    error.j <- NULL; error.a <- list()
    
    for(i in 1:5){
      #get X train, Y.train
      train.X <- test.X <- list()
      for(j in 1:k){
        train.X[[j]] <- X[[j]][,-fold[[i]]]
        test.X[[j]] <- X[[j]][,fold[[i]]] 
      }
      train.Y <- Y[-fold[[i]]]
      test.Y <- Y[fold[[i]]]
      
      #Add rank to joint
      if(rankJ < max.rank){
        fit.j <- sJIVE.converge(train.X, train.Y, eta=eta, max.iter = max.iter, 
                       rankJ = rankJ+1, rankA = rankA, show.message=F,
                       center.scale=center.scale,
                       reduce.dim=reduce.dim)
        new.data <- sJIVE.predict(fit.j, test.X)
        error.j <- c(error.j, sum((new.data$Ypred-test.Y)^2) )
      }else{
        error.j <- c(error.j, 99999999)
      }
      
      #Add rank to individual
      for(j in 1:k){
        if(rankA[j] < max.rank){
          rankA.new <- rankA
          rankA.new[j] <- rankA.new[j]+1
          
          #Add rank to individual
          fit.a <- sJIVE.converge(train.X, train.Y, eta=eta, max.iter = max.iter, 
                         rankJ = rankJ, rankA = rankA.new, show.message=F,
                         center.scale=center.scale,
                         reduce.dim=reduce.dim)
          new.data <- sJIVE.predict(fit.a, test.X)
          if(length(error.a)<j){error.a[[j]] <- NA}
          error.a[[j]] <- c(error.a[[j]], sum((new.data$Ypred-test.Y)^2) )
        }else{
          if(length(error.a)<j){error.a[[j]] <- NA}
          error.a[[j]] <- c(error.a[[j]], 99999999 )
        }
      }
      
    }
    
    #average over folds
    err.j <- mean(error.j)
    err.a <- lapply(error.a, function(x) mean(x, na.rm=T))
    #cat(error.j)
    #cat(error.a[[1]])
    #cat(error.a[[2]])
    
    #Determine which rank to increase
    asd <- c(err.old - err.j, err.old - as.vector(unlist(err.a)))
    if(max(asd) < threshold){
      break
    }else{
      temp <- which(asd == max(asd))
      if(temp==1){
        #cat(asd)
        rankJ <- rankJ+1
        err.old <- err.j
      }else{
        rankA[temp-1] <- rankA[temp-1]+1
        err.old <- err.a[[temp-1]]
      }
    }
    #cat(paste0("Joint Rank: ", rankJ, "\n"))
    #cat(paste0("Individual Ranks: ", rankA, "\n"))
  }
  
  return(list(rankJ = rankJ, 
              rankA = rankA,
              error = err.old,
              error.joint = err.j,
              error.individual = err.a))
}


sJIVE <- function(X, Y, rankJ = NULL, rankA=NULL,eta=NULL, max.iter=1000,
                      threshold = 0.001,  method="permute",
                      center.scale=TRUE, reduce.dim = TRUE){
  ############################################################################
  #X is a list of 2 or more datasets, each with dimensions p_i by n
  #Y is continuous vector length n
  #eta is a tuning parameter between 0 and 1. When eta=NULL, a gridsearch
  #   is conducted to tune eta. You can specify a value of eta to use, 
  #   or supply a vector of eta values for sJIVE to consider.
  #rankJ is a value for the low-rank of the joint component
  #rankA is a vector of the ranks for each X dataset. When rankJ or rankA
  #   are NULL, a rank selection method (see method) will choose ranks
  #max.iter specifies the maximum number of iterations that will run
  #threshold specifies the criteria to determine when algorithm has 
  #   converged
  #Method = c("permute", "CV"). When ranks are not specified, ranks will
  #   be determined by JIVE's permutation method, or sJIVE's 
  #   cross-validation method
  #Center.scale is a true/false indicator for whether or not to center and 
  #   scale the data prior to fitting.
  ############################################################################
  
  k <- length(X)
  n <- ncol(X[[1]])
  if(length(Y) != n){stop("Number of columns differ between datasets")}
  
  if(center.scale){
    Y <- as.numeric(scale(as.numeric(Y)))
    for(i in 1:k){
      for(j in 1:nrow(X[[i]])){
        X[[i]][j,] <- as.numeric(scale(as.numeric(X[[i]][j,])))
      }
    }
  }
  
  
  if(is.null(eta)){
    e.vec=c(0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99)
  }else{
    e.vec=eta
  }
  
  if(is.null(rankJ) | is.null(rankA)){
    if(method=="permute"){
      temp <- jive(X, Y, center=F, scale=F,orthIndiv = F)
      rankJ <- temp$rankJ
      rankA <- temp$rankA
    }else if(method=="CV"){
    temp <- sJIVE.ranks(X,Y, eta=eta, max.iter = max.iter, center.scale=center.scale,
                        reduce.dim=reduce.dim)
    rankJ <- temp$rankJ
    rankA <- temp$rankA
    }else{
      errorCondition("Invalid method chosen")
    }
    cat(paste0("Using rankJ= ", rankJ, " and rankA= ", paste(rankA, collapse = " "), "\n"))
  }
  
  if(length(e.vec)>1){
  #get cv folds
  n <- length(Y)
  fold <- list()
  cutoff <- round(quantile(1:n, c(.2,.4,.6,.8)))
  fold[[1]] <- 1:cutoff[1]
  fold[[2]] <- (cutoff[1]+1):cutoff[2]
  fold[[3]] <- (cutoff[2]+1):cutoff[3]
  fold[[4]] <- (cutoff[3]+1):cutoff[4]
  fold[[5]] <- (cutoff[4]+1):n
  
  cat("Choosing Tuning Parameter: eta \n")
  err.test <- NA
  for(e in e.vec){
    err.fold <- NA
    for(i in 1:5){
      #Get train/test sets
      sub.train.x <- sub.test.x <- list()
      sub.train.y <- Y[-fold[[i]]]
      sub.test.y <- Y[fold[[i]]]
      for(j in 1:length(X)){
        sub.train.x[[j]] <- X[[j]][,-fold[[i]]]
        sub.test.x[[j]] <- X[[j]][,fold[[i]]]
      }
      fit1 <- sJIVE.converge(sub.train.x, sub.train.y, max.iter = max.iter, 
                    rankJ = rankJ, rankA = rankA, eta = e, 
                    show.message=F, center.scale=center.scale,
                    reduce.dim=reduce.dim)
      #Record Error for fold
      fit_test1 <- sJIVE.predict(fit1, sub.test.x)
      fit.mse <- sum((fit_test1$Ypred - sub.test.y)^2)/length(sub.test.y)
      err.fold <- c(err.fold, fit.mse)
    }
    
    #Record Test Error (using validation set)
    fit.mse <- mean(err.fold, na.rm = T)
    err.test <- c(err.test, fit.mse)
    if(min(err.test, na.rm = T) == fit.mse){
      best.eta <- e
    }
  }
  cat(paste0("Using eta= ", best.eta, "\n"))
  test.best <- sJIVE.converge(X, Y, max.iter = max.iter, 
                     rankJ = rankJ, rankA = rankA, eta = best.eta,
                     threshold = threshold, center.scale=center.scale,
                     reduce.dim=reduce.dim)
  }else{
   test.best <- sJIVE.converge(X, Y, max.iter = max.iter, 
                  rankJ = rankJ, rankA = rankA, eta = e.vec,
                  threshold = threshold, center.scale=center.scale,
                  reduce.dim=reduce.dim)
  }
  
  
  return(test.best)
  
}


