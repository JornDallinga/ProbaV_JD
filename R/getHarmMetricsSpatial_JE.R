getHarmMetricsSpatial_JE <- function(x, n_years=NULL, order=1, robust=FALSE,
                                     cf_bands, thresholds=c(-80, Inf, -120, 120) , span=0.3, scale_f=NULL, minrows=1, mc.cores=1, logfile, df_probav_sm, ...) {
  
  #s_info <- getProbaVinfo(probav_sm_dir, pattern =  bands_sel, tiles = tiles[tn])
  s_info <- df_probav_sm
  #s_info <- getProbaVinfo(names(x))
  bands <- s_info[s_info$date == s_info$date[1], 'band']
  dates <- s_info[s_info$band == bands[1], 'date']
  ydays <- s_info[s_info$band == bands[1], 'yday']
  if (nlayers(x) != length(bands) * length(dates)) {
    stop("Inputstack nlayers doesn't fit meta data in layer names!")
  }
  thresholds <- matrix(thresholds, nrow=2)
  len_res <- (4 + (order*2)) * length(bands)
  
  cat("\nOutputlayers:", len_res, "\n")
  
  
  fun <- function(x){
    # smooth loess and getHarmMetrics
    m <- matrix(x, nrow= length(bands), ncol=length(dates))
    
    if (!all(is.na(m[1,]))) {
      res <- try({
        # smooth loess on all cf bands, then combine
        qc <- foreach(bn = 1:length(cf_bands), .combine='&') %do% {
          qcb <-   smoothLoess(m[cf_bands[bn],], dates = dates, threshold = thresholds[,bn],
                               res_type = "QC", span=span)
          qcb == 1
        }
        
        #get metrics
        coefs <- apply(m, 1, FUN=getHarmMetrics, yday=ydays, QC_good=qc, order=order, robust=robust, dates = dates)
        
        if (!is.null(scale_f)){
          # scaling
          res_1 <- as.integer(t(round((scale_f) * t(coefs))))
        } else res_1 <- c(coefs)
        
        if (length(res_1) != len_res) {
          res_1 <- rep(-9999, len_res)
        }
        res_1
      })
      
      if(class(res) == 'try-error') {
        res <- rep(NA_integer_, len_res)
      }
      
    } else {
      res <- rep(NA_integer_, len_res)
    }
    
    # no names, because they get lsot in mc.calc anyway
    return(res)
  }
  
  # use mcCalc ratehr than mc.calc (controll minrows)
  out <- mcCalc(x=x, fun=fun, minrows = 15, mc.cores = mc.cores, logfile=logfile, out_name = out_name)
  
  return(out)
}