## Supporting Functions 
if (blended==TRUE) {  blendStat <- "ECA_blend" } else { blendStat <- "ECA_nonblend"}
## Define Base Download Link for Meteorological Data
baseLinkDat <- "http://www.ecad.eu/utils/downloadfile.php?file=download/"

## Define Base Download Link for Mateorological Stations Information Map
baseLinkMap <- "http://www.ecad.eu/download/"

## Define Link Map
linkMap <-  data.table(VarName=c("DailyMaxTemp", "DailyMinTemp",
                                 "DailyMeanTemp", "DailyPrecipAmount",
                                 "DailyMeanSeaLVLPress","DailyCloudCover",
                                 "DailyHumid", "DailySnowDepth", 
                                 "DailySunShineDur","DailyMeanWindSpeed",
                                 "DailyMaxWindGust","DailyWindDirection"),
                       
                       Link=c("_tx.zip",
                              "_tn.zip",
                              "_tg.zip",
                              "_rr.zip",
                              "_pp.zip",
                              "_cc.zip",
                              "_hu.zip",
                              "_sd.zip",
                              "_ss.zip",
                              "_fg.zip",
                              "_fx.zip",
                              "_dd.zip"),
                       
                       Map=c("_station_tx.txt",
                             "_station_tn.txt",
                             "_station_tg.txt",
                             "_station_rr.txt",
                             "_station_pp.txt",
                             "_station_cc.txt",
                             "_station_hu.txt",
                             "_station_sd.txt",
                             "_station_ss.txt",
                             "_station_fg.txt",
                             "_station_fx.txt",
                             "_station_dd.txt"),
                       ID=c("TX",
                            "TN",
                            "TG",
                            "RR",
                            "PP",
                            "CC",
                            "HU",
                            "SD",
                            "SS",
                            "FG",
                            "FX",
                            "DD"))

linkMap[,downloadDatLink:=paste0(baseLinkDat,blendStat,Link)]
linkMap[,downloadStationLink:=paste0(baseLinkMap,blendStat,Map)]
linkMap[,downloadDatPath:=paste0(currPath,"/",VarName)]

download_Data <- function(metVar,linkMap){
  library(data.table)
  cat("Currently preparing system to Download the desired meteorological data..\n")
  cat("Creating download local system paths...\n")
  ## Creating Download Local System Paths
  dir.create(linkMap[VarName==metVar,downloadDatPath], showWarnings = FALSE)
  
  file <- basename(linkMap[VarName==metVar,downloadDatLink])
  
  cat("Currently downloading data: ",metVar,"\n")
  
  downloadTime <- system.time(download.file(linkMap[VarName==metVar,downloadDatLink], 
                                            paste0(linkMap[VarName==metVar,downloadDatPath],"/",file)))
  
  cat("Data downloaded in: ",downloadTime[[3]]," secs\n") 
  
  cat("Decompressing downloaded files...\n")
  unzipTime <- system.time(unzip(paste0(linkMap[VarName==metVar,downloadDatPath],"/",file), exdir=linkMap[VarName==metVar,downloadDatPath]))
  
  cat("Files decompressed in ",unzipTime[[3]]," secs\n")
  # Delete Zip File
  unlink(paste0(linkMap[VarName==metVar,downloadDatPath],"/",list.files(linkMap[VarName==metVar,downloadDatPath], pattern=".zip")))
}

# Download Data in parallel

parallelDownloadData <- function(core_id){
  library(data.table)
  library(foreach)
  library(doParallel)
  # Define meteorological variables adressing to core_id
  metVarList <- distrMap[Core==core_id,Variable]
  
  # Download Data for each meterological variable
  for (metVarList_id in metVarList){
    download_Data(metVar<-metVarList_id, linkMap)
  }
}




# Convert Degrees,minutes,seconds to decimal degrees 


findLoc <- function(x) {
  tempLoc <- str_split(x, pattern = ":")
  x.out  <- as.numeric(tempLoc[[1]][1]) + as.numeric(tempLoc[[1]][2])/60 + as.numeric(tempLoc[[1]][3])/3600
  return(x.out)
}


## Manipulate Mapping File - Keep Existing MEteorological Stations

manipulateMapping <- function(metVar){
  # Find Data path of variable of interest
  tempDownloadPath <- linkMap[VarName %in% metVar,downloadDatPath]
  
  tempMapping <- data.table(read.table(paste0(tempDownloadPath,"/stations.txt"), skip = 16 ,sep=",",
                                       stringsAsFactors = FALSE, header=TRUE, quote=""))
  
  # Manipulate Longitude and Lattitude - Convert Degrees,minutes,seconds to decimal degrees 
  
  tempMapping[,latUpd:=sapply(LAT,findLoc)][,longUpd:=sapply(LON,findLoc)]
  tempMapping[,LatLong:=paste0(latUpd,":",longUpd)]
  tempMapping <- tempMapping[!duplicated(LatLong)] # get rid off stations with duplicated locations
  
  # Find Available Stations with their names and their location
  
  dataFileNames <- list.files(tempDownloadPath, pattern=".txt")
  dataFileNames <- dataFileNames[!dataFileNames %in% c("elements.txt", "sources.txt","stations.txt")]
  dataFileNamesIDs <- as.numeric(gsub(".txt","",gsub(paste0(linkMap[VarName==metVar,ID],"_STAID"),"",dataFileNames)))
  availableStationsMap <- data.table(STAID=dataFileNamesIDs)
  availableStationsMap <- merge(availableStationsMap,
                                tempMapping[,c("STAID","STANAME","CN","latUpd","longUpd","LatLong"), with=F],
                                by=c("STAID"), all.y=TRUE)
  availableStationsMap[,MetVar:=metVar]
  cat("Available data of",metVar," for ",length(unique(availableStationsMap$CN)),"countries\n")
  return(availableStationsMap)
}

# Produce Charts of Available Stations per Country - Meteorological Variable

produceMappingCharts <- function(uniqueComb_id) {
 
  library(tcltk)
  library(data.table)
  library(ggmap)
  library(foreach)
  library(doParallel)
  
  tempUniqueComb <- uniqueComb[Core==uniqueComb_id]
  idx <- 1
  mypb <- tkProgressBar(title = paste0("Core:",uniqueComb_id, " Parallel Processing"), label=paste0("Complete: 0%"), min=0, max=nrow(tempUniqueComb), initial=0, width=400)
  for (i in 1:nrow(tempUniqueComb)){
    setTkProgressBar(mypb, idx, title=paste0("Core:",uniqueComb_id," - Complete: ",round(idx/nrow(tempUniqueComb)*100,digits = 1),"% ","Executing Parallel Processing"),
                     label= paste0("Complete: ", round(idx/nrow(tempUniqueComb)*100,digits = 1),"%"))
    
    CN_id <- tempUniqueComb[i,CN]
    MetVar_id <- tempUniqueComb[i,MetVar]
    
    tempMap <- totalMap[MetVar==MetVar_id & CN==CN_id]
    mapgilbert <- get_map(location = c(lon = mean(tempMap$longUpd), lat = mean(tempMap$latUpd)), zoom = 4, maptype = "toner" , scale = 2)
    
    tempPlot <- ggmap(mapgilbert) +
      geom_point(data = tempMap, aes(x = longUpd, y = latUpd, fill = "red", alpha = 0.8), size = 2, shape = 21) +
      guides(fill=FALSE, alpha=FALSE, size=FALSE) + 
      ggtitle(paste0("Reporting Stations - Country: ",CN_id, " - Variable: ", MetVar_id)) + 
      xlab("Longitude") + ylab("Latitude")
    ggsave(file=paste0(StationPlotPath,"Reporting Stations-Country-",CN_id, "-Variable-", MetVar_id,".png")  ,dpi = 300)
  idx <- idx +1
  }
  close(mypb)
}
