Feature Engineering using `data.table`
================
Giorgos Kaiafas, PhD Researcher <br> mail: <georgios.kaiafas@uni.lu> <br> Kostas Mammas, Statistical Programmer <br> mail: <mammaskon@gmail.com> <br>
EarthBiAs2017, Rhodes Island, Greece

-   [Introduction](#introduction)
    -   [Lecture workflow](#lecture-workflow)
    -   [ECA&D](#ecad)
-   [Download environmental data using the `ECADownloader` tool](#download-environmental-data-using-the-ecadownloader-tool)
    -   [Availability of stations](#availability-of-stations)
-   [Selection of environmental variables for analysis](#selection-of-environmental-variables-for-analysis)
-   [Challenges regarding data availability](#challenges-regarding-data-availability)
-   [Data Loading in R](#data-loading-in-r)
-   [A heuristic approach to impute missing values](#a-heuristic-approach-to-impute-missing-values)
-   [Find the optimal period length of consecutive daily records](#find-the-optimal-period-length-of-consecutive-daily-records)
    -   [Obtain records for the maximum period of consecutive rainfall](#obtain-records-for-the-maximum-period-of-consecutive-rainfall)
-   [Feature engineering](#feature-engineering)
    -   [Rolling Mean](#rolling-mean)
    -   [Lag](#lag)
    -   [Rolling Weighted Mean](#rolling-weighted-mean)
    -   [Rolling Standard Deviation](#rolling-standard-deviation)
    -   [Rolling Quantile](#rolling-quantile)

Introduction
------------

### Lecture workflow

The purpose of this session is to fit a Machine Learning model to predict daily rainfall occurence using a set of environmental variables.

We need to answer a set of questions before we start working on this task:

1.  What type of information will be used?
2.  How are we going to access this information?
3.  What type of data cleaning techniques will be used in order to perform feature transformation?
4.  Which environmental variables will be used in our modelling approach?
5.  If we select 3 meteorological variables how are we going to gather this information in order to fita model to a particular meteorological station?

In order to answer these questions we will follow the steps bresented below:

1.  Obtain environmental daily rainfall records from ECA&D using the `ECADownloader` tool
2.  Select variables of interest
3.  Perform data cleaning/ transofrmation techniques using the `data.table` package
4.  Select country/ stations that will be used to perform feature engineering
5.  Find optimal period where a station has the available records for all the selected meteorological variables.

### ECA&D

ECA&D is a European Climate Assessment & Dataset project. Presented is information on changes in weather and climate extremes, as well as the daily dataset needed to monitor and analyse these extremes. ECA&D was initiated by the ECSN in 1998 and has received financial support from the EUMETNET and the European Commission. You can access the ECA&D website using the following [link](http://www.ecad.eu/).

Download environmental data using the `ECADownloader` tool
----------------------------------------------------------

The `ECADownloader` is a set of functions built in `R` using `data.table` and provide functionalities when it comes to download specific daily environmental series from all the available meteorological stations in Europe.

Using the following [link](https://github.com/mammask/ECADownloader) you can use the `ECADownloader` and obtain the environmental indices of interest.

``` r
# Load packages
library(data.table)
library(stringr)
library(tcltk)

# Define Path
currPath <- "~/Documents/EarthBiAs2017"

# Set current working directory
setwd(currPath)

# Define if dataset will be blended or nonblended
blended   <- TRUE  

# Define variables to transform
metVarTbl <- data.table(metVar = c("DailyMaxTemp", "DailyMinTemp",
                                   "DailyMeanTemp", "DailyPrecipAmount",
                                   "DailyMeanSeaLVLPress","DailyCloudCover",
                                   "DailyHumid", "DailySnowDepth", 
                                   "DailySunShineDur","DailyMeanWindSpeed",
                                   "DailyMaxWindGust","DailyWindDirection"),
                        Include = c("yes", "yes","yes","yes","no","yes","yes",
                                    "no","yes","yes","no","no"))

# Keep selected
metVarTbl <- metVarTbl[Include=="yes", metVar]
print(metVarTbl)
```

    ## [1] "DailyMaxTemp"       "DailyMinTemp"       "DailyMeanTemp"     
    ## [4] "DailyPrecipAmount"  "DailyCloudCover"    "DailyHumid"        
    ## [7] "DailySunShineDur"   "DailyMeanWindSpeed"

In the next step we need to source the supporting functions script available in the ECADownload tool:

``` r
# Load supporting functions
source("./externalFunctions_v1a.R")
```

### Availability of stations

The following function provides information about the list of the available meteorological stations per environmental variable of interest:

``` r
# Function to otain list of stations having the specific environmental variable
availStatPerVar <- function(metVarID){
  
  # function name: availStatPerVar
  #         input: metVarID - A vector indicating the meteorological variables of interest
  #                (see ECADownloader for naming conventions)
  #        output: availableStationsMap a data.table with the available stations
  
  # Define the download path 
  tempDownloadPath <- paste0(currPath,"/",metVarID,"/")
  # File with the list of stations for the specific meteorological variable
  precipStat  <-  paste0(currPath,"/",metVarID,"/stations.txt")
  # Reaf stations file - skipping first 16 rows
  tempMapping <- data.table(read.table(precipStat, skip = 16 ,sep=",",
                                       stringsAsFactors = FALSE, header=TRUE, quote=""))
  
  # Manipulate Longitude and Lattitude - Convert Degrees,minutes,seconds to decimal degrees 
  tempMapping[,latUpd:=sapply(LAT,findLoc)][,longUpd:=sapply(LON,findLoc)]
  tempMapping[,LatLong:=paste0(latUpd,":",longUpd)]
  tempMapping <- tempMapping[!duplicated(LatLong)] # get rid off stations with duplicated locations
  
  # Find Available Stations with their names and their location
  dataFileNames <- list.files(tempDownloadPath, pattern=".txt")
  # List of files with rainfall records
  dataFileNames <- dataFileNames[!dataFileNames %in% c("elements.txt", "sources.txt","stations.txt")]
  dataFileNamesIDs <- as.numeric(gsub(".txt","",
                                      gsub(paste0(linkMap[VarName==metVarID,ID],
                                                  "_STAID"),"",dataFileNames)
                                      )
                                 )
  # data.table with stations
  availableStationsMap <- data.table(STAID=dataFileNamesIDs)
  availableStationsMap <- merge(availableStationsMap,
                                tempMapping[,c("STAID",
                                               "STANAME",
                                               "CN",
                                               "latUpd",
                                               "longUpd",
                                               "LatLong"), with=F],
                                by=c("STAID"), all.y=TRUE)
  availableStationsMap[,MetVar:=metVarID]
  
  cat("Available data of",metVarID," for ",length(unique(availableStationsMap$CN)),"countries\n")
  
  return(availableStationsMap)
}
```

We can find the list of stations having daily precipitation rainfall records:

``` r
resTbl <- availStatPerVar(metVarID = "DailyPrecipAmount")
```

    ## Available data of DailyPrecipAmount  for  59 countries

``` r
print(resTbl)
```

    ##       STAID                                  STANAME CN   latUpd
    ##    1:     1 VAEXJOE                                  SE 56.86667
    ##    2:     2 FALUN                                    SE 60.61667
    ##    3:     3 STENSELE                                 SE 65.06667
    ##    4:     4 LINKOEPING                               SE 58.40000
    ##    5:     6 KARLSTAD                                 SE 59.35000
    ##   ---                                                           
    ## 6485: 11381 ZABLJAK                                  ME 43.15000
    ## 6486: 11382 OLOT                                     ES 42.18806
    ## 6487: 11383 LA POBLA DE SEGUR                        ES 42.24389
    ## 6488: 11385 LES BORGES BLANQUES                      ES 41.51056
    ## 6489: 11386 MASSOTERES                               ES 41.79306
    ##          longUpd                            LatLong            MetVar
    ##    1: 14.8000000              56.8666666666667:14.8 DailyPrecipAmount
    ##    2: 15.6166667  60.6166666666667:15.6166666666667 DailyPrecipAmount
    ##    3: 17.1663889  65.0666666666667:17.1663888888889 DailyPrecipAmount
    ##    4: 15.5330556              58.4:15.5330555555556 DailyPrecipAmount
    ##    5: 13.4666667             59.35:13.4666666666667 DailyPrecipAmount
    ##   ---                                                                
    ## 6485: 19.1300000                        43.15:19.13 DailyPrecipAmount
    ## 6486:  2.4802778  42.1880555555556:2.48027777777778 DailyPrecipAmount
    ## 6487:  0.9680556 42.2438888888889:0.968055555555556 DailyPrecipAmount
    ## 6488:  0.8563889 41.5105555555556:0.856388888888889 DailyPrecipAmount
    ## 6489:  1.3055556  41.7930555555556:1.30555555555556 DailyPrecipAmount

This result can be extended to find the list of stations for the following environmental variables:

1.  DailyMaxTemp
2.  DailyMinTemp
3.  DailyMeanTemp
4.  DailyPrecipAmount
5.  DailyCloudCover
6.  DailyHumid
7.  DailySunShineDur
8.  DailyMeanWindSpeed

``` r
datList <- list()
k <- 1
for (metVarID in metVarTbl){
  
  print(paste0("Processing:",metVarID,"\n"))
  datList[[k]] <- availStatPerVar(metVarID)
  k <- k + 1 
}
```

    ## [1] "Processing:DailyMaxTemp\n"
    ## Available data of DailyMaxTemp  for  60 countries
    ## [1] "Processing:DailyMinTemp\n"
    ## Available data of DailyMinTemp  for  60 countries
    ## [1] "Processing:DailyMeanTemp\n"
    ## Available data of DailyMeanTemp  for  50 countries
    ## [1] "Processing:DailyPrecipAmount\n"
    ## Available data of DailyPrecipAmount  for  59 countries
    ## [1] "Processing:DailyCloudCover\n"
    ## Available data of DailyCloudCover  for  19 countries
    ## [1] "Processing:DailyHumid\n"
    ## Available data of DailyHumid  for  21 countries
    ## [1] "Processing:DailySunShineDur\n"
    ## Available data of DailySunShineDur  for  21 countries
    ## [1] "Processing:DailyMeanWindSpeed\n"
    ## Available data of DailyMeanWindSpeed  for  9 countries

``` r
overall <- rbindlist(datList)
```

Selection of environmental variables for analysis
-------------------------------------------------

We will use the following environmental variables:

1.  Daily Precipitation Amount
2.  Daily Mean Temperature
3.  Daily Mean Humidity

Challenges regarding data availability
--------------------------------------

One of the main challenges is whether a station has information about the 3 variables of interest. In this section we will identify which stations have this information:

1.  Find stations with rainfall and precipitation records:

``` r
# Find station with Rainfall and Temperature Records
rainMeanTemp <- overall[ MetVar == "DailyPrecipAmount",
                         .(STAID)][ ,overall[ MetVar == "DailyMeanTemp",
                                       .(STAID)],
                             on = .(STAID = STAID), nomatch = 0L]
```

1.  Find stations with Rainfall, Temperature and Humidity Records:

``` r
# Find stations with Rainfall, Temperature and Humidity records
rainMeanTempHumid <- rainMeanTemp[, overall[ MetVar == "DailyHumid", .(STAID)], 
                                  on = .(STAID = STAID), nomatch = 0L]

rainMeanTempHumid
```

    ##       STAID
    ##    1:    11
    ##    2:    12
    ##    3:    13
    ##    4:    14
    ##    5:    15
    ##   ---      
    ## 1646: 11348
    ## 1647: 11382
    ## 1648: 11383
    ## 1649: 11385
    ## 1650: 11386

1.  Find the country with the most stations having the 3 environmental variables

``` r
allStations <- unique(overall[STAID %in% 
                                rainMeanTempHumid[, STAID] &
                                MetVar %in% c("DailyPrecipAmount",
                                              "DailyMeanTemp",
                                              "DailyHumid")][,.(STAID,CN)])

# Select Spanish Stations
stationsToKeep <- allStations[CN == "ES", STAID]
```

You can visit the following [link](https://github.com/mammask/EarthBiAs2017/blob/master/Lecture-1-Data_Management.md) in order to improve your skills in `data.table` merge.

Data Loading in R
-----------------

At this point we have dowloaded the data locally. As a next step we need to load the desired variables in R. For this reason we will run the following function:

``` r
# Obtain data in R using as input a set of environmental variables:
obtainStationDat <- function(linkMap, metVarId, stationsToKeep){
  
  library(data.table)
  library(stringr)
  library(tcltk)
  
  # Create an empty list
  tempStat <- list()
  # Obtain download path
  tempDownloadPath <- linkMap[VarName == metVarId,downloadDatPath]
  # Obtain files with the records
  dataFileNames <- list.files(tempDownloadPath, pattern=".txt")
  # Remove un-necessary stations 
  dataFileNames <- dataFileNames[!dataFileNames %in% 
                                   c("elements.txt", "sources.txt","stations.txt")]
  
  # Create a data.table with the names of the files of the rainfall records
  dataFileNamesMap <- data.table(FileName=dataFileNames)
  # Create a data.table with the names of the stations
  stationsToKeep <- data.table(Filename = stationsToKeep)
  # Create the names of the records of interest (see pattern of file names)
  stationsToKeep[, Filename := paste0(linkMap[VarName == metVarId, ID],"_STAID",
                                      str_pad(string = Filename,
                                              width = 6,
                                              side = "left",
                                              pad = "0"),".txt")]
  
  # Define files to download
  statToDownload <- dataFileNamesMap[FileName %in% stationsToKeep[,Filename], FileName]
  
  # Create a progress bar so as to have a sense of the progress
  k <- 1
  mypb <- tkProgressBar(title ="Percentage Complete: 0%", min=0,
                        max=length(statToDownload), initial=0, width=400)
  
  # For loop to read the records of each meteorological station
  for (tempFile_id in statToDownload){
    setTkProgressBar(mypb, k, title=paste0("Percentage Complete: ",
                                           round(k/length(statToDownload)*100,digits = 1),
                                           "% ","Processing Data Read..."))
    tempStat[[k]] <- data.table(read.table(paste0(tempDownloadPath,"/",tempFile_id)
                                           ,skip=20, sep=",",header=TRUE, stringsAsFactors=FALSE))
    
    # Format the date
    tempStat[[k]][,DATE:=as.Date(as.character(DATE), format("%Y%m%d"))]
    # Compute year variable
    tempStat[[k]][,Year:= year(DATE)]
    # Compute month variable
    tempStat[[k]][,Month:= month(DATE)]
    # Create a name with the id of the meteorological variable of interest
    tempStat[[k]][,VarName:=metVarId]
    
    k <- k + 1
  }
  close(mypb)
  return(rbindlist(tempStat))
}
```

We can save time by running this function using a parallel processing approach:

``` r
library(foreach)
library(doParallel)
```

    ## Loading required package: iterators

    ## Loading required package: parallel

``` r
cl <- makeCluster(3)
registerDoParallel(cl)

# Read on parallel the available stations
allRes <- foreach(metVarId = c("DailyPrecipAmount",
                               "DailyMeanTemp",
                               "DailyHumid"), .verbose = T) %dopar% obtainStationDat(linkMap,
                                                                                      metVarId,
                                                                                      stationsToKeep
                                                                                     )
```

    ## automatically exporting the following variables from the local environment:
    ##   linkMap, obtainStationDat, stationsToKeep 
    ## numValues: 3, numResults: 0, stopped: TRUE
    ## got results for task 1
    ## numValues: 3, numResults: 1, stopped: TRUE
    ## returning status FALSE
    ## got results for task 2
    ## numValues: 3, numResults: 2, stopped: TRUE
    ## returning status FALSE
    ## got results for task 3
    ## numValues: 3, numResults: 3, stopped: TRUE
    ## calling combine function
    ## evaluating call object to combine results:
    ##   fun(accum, result.1, result.2, result.3)
    ## returning status TRUE

``` r
stopCluster(cl)
allRes <- rbindlist(allRes)
gc()
```

    ##            used  (Mb) gc trigger  (Mb) max used  (Mb)
    ## Ncells   476382  25.5     940480  50.3   750400  40.1
    ## Vcells 44446517 339.2   89921921 686.1 87695724 669.1

A heuristic approach to impute missing values
---------------------------------------------

There are several approaches to deal with the problem of missing values. These methods refer to multiple imputation techiques, deleting records with missing values, replacing with mean or median etc.

In this exercise we impute maximum 5 records per month using the monthly mean. In cases where more than 5 records appear during a month, these records are excluded.

``` r
# Perform a data cleaning process in order to impute max 5 records per month
# Replace values -9999 with NA
allRes[RR == -9999, RR:= NA]
```

    ##          STAID SOUID       DATE  RR Q_RR Year Month           VarName
    ##       1:   229   709 1955-01-01  35    0 1955     1 DailyPrecipAmount
    ##       2:   229   709 1955-01-02 194    0 1955     1 DailyPrecipAmount
    ##       3:   229   709 1955-01-03   0    0 1955     1 DailyPrecipAmount
    ##       4:   229   709 1955-01-04 168    0 1955     1 DailyPrecipAmount
    ##       5:   229   709 1955-01-05  61    0 1955     1 DailyPrecipAmount
    ##      ---                                                             
    ## 8647589: 11386 75688 2017-07-27  NA    9 2017     7        DailyHumid
    ## 8647590: 11386 75688 2017-07-28  NA    9 2017     7        DailyHumid
    ## 8647591: 11386 75688 2017-07-29  NA    9 2017     7        DailyHumid
    ## 8647592: 11386 75688 2017-07-30  NA    9 2017     7        DailyHumid
    ## 8647593: 11386 75688 2017-07-31  NA    9 2017     7        DailyHumid

``` r
# Compute Monthly Mean by Station month and environmental variable
averageMapper <- allRes[, .(MonthlyMean = mean(RR, na.rm = T)), by = c("STAID","Year", "Month", "VarName")]

# Find number of missing records per station month and meteorological varible 
countNA  <- allRes[is.na(RR), .(CountNumNAs = .N), by =  c("STAID","Year", "Month", "VarName")]

# Obtain count for each monthly mean
resultDT <- merge(averageMapper,countNA, all.x = T, by = c("STAID","Year", "Month", "VarName"))

# Obtain results to original dataset
allRes <- merge(allRes,resultDT, all.x = T, by = c("STAID","Year", "Month", "VarName"))
rm(averageMapper)
rm(countNA)
rm(resultDT)
gc()
```

    ##            used  (Mb) gc trigger   (Mb)  max used  (Mb)
    ## Ncells   477471  25.5     940480   50.3    750400  40.1
    ## Vcells 57432062 438.2  134118365 1023.3 115908679 884.4

``` r
# Replace missing recods with mean 
allRes[, c("MonthlyMean","RR"):= lapply(.SD, as.numeric), .SDcols = c("MonthlyMean","RR")]
```

    ##          STAID Year Month           VarName SOUID       DATE RR Q_RR
    ##       1:   229 1955     1        DailyHumid   995 1955-01-01 94    0
    ##       2:   229 1955     1        DailyHumid   995 1955-01-02 99    0
    ##       3:   229 1955     1        DailyHumid   995 1955-01-03 92    0
    ##       4:   229 1955     1        DailyHumid   995 1955-01-04 98    0
    ##       5:   229 1955     1        DailyHumid   995 1955-01-05 94    0
    ##      ---                                                            
    ## 8647589: 11386 2017     7 DailyPrecipAmount 75690 2017-07-27 NA    9
    ## 8647590: 11386 2017     7 DailyPrecipAmount 75690 2017-07-28 NA    9
    ## 8647591: 11386 2017     7 DailyPrecipAmount 75690 2017-07-29 NA    9
    ## 8647592: 11386 2017     7 DailyPrecipAmount 75690 2017-07-30 NA    9
    ## 8647593: 11386 2017     7 DailyPrecipAmount 75690 2017-07-31 NA    9
    ##          MonthlyMean CountNumNAs
    ##       1:    92.77419          NA
    ##       2:    92.77419          NA
    ##       3:    92.77419          NA
    ##       4:    92.77419          NA
    ##       5:    92.77419          NA
    ##      ---                        
    ## 8647589:         NaN          31
    ## 8647590:         NaN          31
    ## 8647591:         NaN          31
    ## 8647592:         NaN          31
    ## 8647593:         NaN          31

``` r
allRes[is.na(RR) & !is.na(CountNumNAs) & CountNumNAs <= 5, RR:= MonthlyMean]
```

    ##          STAID Year Month           VarName SOUID       DATE RR Q_RR
    ##       1:   229 1955     1        DailyHumid   995 1955-01-01 94    0
    ##       2:   229 1955     1        DailyHumid   995 1955-01-02 99    0
    ##       3:   229 1955     1        DailyHumid   995 1955-01-03 92    0
    ##       4:   229 1955     1        DailyHumid   995 1955-01-04 98    0
    ##       5:   229 1955     1        DailyHumid   995 1955-01-05 94    0
    ##      ---                                                            
    ## 8647589: 11386 2017     7 DailyPrecipAmount 75690 2017-07-27 NA    9
    ## 8647590: 11386 2017     7 DailyPrecipAmount 75690 2017-07-28 NA    9
    ## 8647591: 11386 2017     7 DailyPrecipAmount 75690 2017-07-29 NA    9
    ## 8647592: 11386 2017     7 DailyPrecipAmount 75690 2017-07-30 NA    9
    ## 8647593: 11386 2017     7 DailyPrecipAmount 75690 2017-07-31 NA    9
    ##          MonthlyMean CountNumNAs
    ##       1:    92.77419          NA
    ##       2:    92.77419          NA
    ##       3:    92.77419          NA
    ##       4:    92.77419          NA
    ##       5:    92.77419          NA
    ##      ---                        
    ## 8647589:         NaN          31
    ## 8647590:         NaN          31
    ## 8647591:         NaN          31
    ## 8647592:         NaN          31
    ## 8647593:         NaN          31

``` r
# Ommit observations with more than 5 NAs during a monthly period
allRes <- allRes[is.na(CountNumNAs) | CountNumNAs <= 5]

# Find representtive stations with 3 meteorological variables
repStat <- allRes[, .N, by = list(STAID, DATE)][N>2][order(-N)]

# Update dataset by keeping stations with 3 available meteorological records
allRes  <- allRes[repStat, on = .(STAID = STAID, DATE = DATE)]

# Transform to wide format
allRes <- data.table::dcast.data.table(allRes, STAID + DATE + Year + Month ~ VarName, value.var = c("RR", "Q_RR"))
```

Find the optimal period length of consecutive daily records
-----------------------------------------------------------

At this stage, data imputation is complete. Each station has clean and imputed data. However, we need to ensure that we have complete records. For example, some stations might have discontinuations and two consecutive records might be apart for more than one day.

In the following script we compute the length of each stations period with consecutive rainfall records:

``` r
# Find period with maximum number of available meteorological records
allRes <- copy(allRes[order(STAID, DATE)])
allRes[, Cons := as.numeric(DATE - shift(x = DATE, n = 1, type = "lag", fill = NA))-1, by = STAID]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1955-01-01 1955     1            94               89
    ##       2:   229 1955-01-02 1955     1            99               78
    ##       3:   229 1955-01-03 1955     1            92              103
    ##       4:   229 1955-01-04 1955     1            98              114
    ##       5:   229 1955-01-05 1955     1            94              126
    ##      ---                                                           
    ## 2165737: 11386 2017-06-26 2017     6            58              230
    ## 2165738: 11386 2017-06-27 2017     6            61              235
    ## 2165739: 11386 2017-06-28 2017     6            59              198
    ## 2165740: 11386 2017-06-29 2017     6            55              168
    ## 2165741: 11386 2017-06-30 2017     6            52              166
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                   35               0                  0
    ##       2:                  194               0                  0
    ##       3:                    0               0                  0
    ##       4:                  168               0                  0
    ##       5:                   61               0                  0
    ##      ---                                                        
    ## 2165737:                   46               0                  0
    ## 2165738:                    2               0                  0
    ## 2165739:                   33               0                  0
    ## 2165740:                    0               0                  0
    ## 2165741:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons
    ##       1:                      0   NA
    ##       2:                      0    0
    ##       3:                      0    0
    ##       4:                      0    0
    ##       5:                      0    0
    ##      ---                            
    ## 2165737:                      0    0
    ## 2165738:                      0    0
    ## 2165739:                      0    0
    ## 2165740:                      0    0
    ## 2165741:                      0    0

``` r
allRes[is.na(Cons), Cons:= 0]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1955-01-01 1955     1            94               89
    ##       2:   229 1955-01-02 1955     1            99               78
    ##       3:   229 1955-01-03 1955     1            92              103
    ##       4:   229 1955-01-04 1955     1            98              114
    ##       5:   229 1955-01-05 1955     1            94              126
    ##      ---                                                           
    ## 2165737: 11386 2017-06-26 2017     6            58              230
    ## 2165738: 11386 2017-06-27 2017     6            61              235
    ## 2165739: 11386 2017-06-28 2017     6            59              198
    ## 2165740: 11386 2017-06-29 2017     6            55              168
    ## 2165741: 11386 2017-06-30 2017     6            52              166
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                   35               0                  0
    ##       2:                  194               0                  0
    ##       3:                    0               0                  0
    ##       4:                  168               0                  0
    ##       5:                   61               0                  0
    ##      ---                                                        
    ## 2165737:                   46               0                  0
    ## 2165738:                    2               0                  0
    ## 2165739:                   33               0                  0
    ## 2165740:                    0               0                  0
    ## 2165741:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons
    ##       1:                      0    0
    ##       2:                      0    0
    ##       3:                      0    0
    ##       4:                      0    0
    ##       5:                      0    0
    ##      ---                            
    ## 2165737:                      0    0
    ## 2165738:                      0    0
    ## 2165739:                      0    0
    ## 2165740:                      0    0
    ## 2165741:                      0    0

``` r
allRes[, Group := cumsum(Cons), by = STAID]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1955-01-01 1955     1            94               89
    ##       2:   229 1955-01-02 1955     1            99               78
    ##       3:   229 1955-01-03 1955     1            92              103
    ##       4:   229 1955-01-04 1955     1            98              114
    ##       5:   229 1955-01-05 1955     1            94              126
    ##      ---                                                           
    ## 2165737: 11386 2017-06-26 2017     6            58              230
    ## 2165738: 11386 2017-06-27 2017     6            61              235
    ## 2165739: 11386 2017-06-28 2017     6            59              198
    ## 2165740: 11386 2017-06-29 2017     6            55              168
    ## 2165741: 11386 2017-06-30 2017     6            52              166
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                   35               0                  0
    ##       2:                  194               0                  0
    ##       3:                    0               0                  0
    ##       4:                  168               0                  0
    ##       5:                   61               0                  0
    ##      ---                                                        
    ## 2165737:                   46               0                  0
    ## 2165738:                    2               0                  0
    ## 2165739:                   33               0                  0
    ## 2165740:                    0               0                  0
    ## 2165741:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons Group
    ##       1:                      0    0     0
    ##       2:                      0    0     0
    ##       3:                      0    0     0
    ##       4:                      0    0     0
    ##       5:                      0    0     0
    ##      ---                                  
    ## 2165737:                      0    0     0
    ## 2165738:                      0    0     0
    ## 2165739:                      0    0     0
    ## 2165740:                      0    0     0
    ## 2165741:                      0    0     0

``` r
# Obtain period length for each station
periodTbl <- allRes[, { minDate = min(DATE);
                        maxDate = max(DATE);
                        
                        list( MinDate = minDate, 
                              MaxDate = maxDate,
                              Length  = as.numeric(maxDate-minDate))
                        },
                        by = list(STAID, Group)
                    ][order(STAID, -Length)]
```

### Obtain records for the maximum period of consecutive rainfall

For each station we find the maximum time period of consecutive rainfall.

``` r
library(tidyverse)
library(data.table)
library(zoo)
library(lubridate)
library(tidyverse)
library(RcppRoll)
library(caTools)
```

``` r
maxLenths <- periodTbl[, .(Length = max(Length)), by = STAID]
maxDuration <- periodTbl[maxLenths, on = .(STAID = STAID, Length = Length)]
head(maxDuration)
```

    ##    STAID Group    MinDate    MaxDate Length
    ## 1:   229  2102 1961-01-01 2017-06-30  20634
    ## 2:   230  2855 1939-06-01 2017-06-30  28519
    ## 3:   231  2978 1986-06-01 2017-06-30  11352
    ## 4:   232    61 1960-05-01 2009-08-31  18019
    ## 5:   233     0 1961-01-01 2017-06-30  20634
    ## 6:   234     0 1950-01-01 2017-06-30  24652

``` r
allRes <- merge(allRes, maxDuration[, !"Group", with=FALSE], all.x = T, by = "STAID")
allRes <- allRes[DATE %between% list(MinDate, MaxDate)]
```

Feature engineering
-------------------

In this section we begin the feature engineering approach.
Feature engineering is the process of using domain knowledge of the data to create features that make the machine learning algorithms work. Rolling analysis will be a part of the process.
*`Coming up with features is difficult, time-consuming, requires expert knowledge. "Applied machine learning" is basically feature engineering.`*
*`Andrew Ng, Machine Learning and AI via Brain simulations`*

A common technique to assess the constancy of a model’s parameters is to compute parameter estimates over a rolling window of a fixed size through the sample.
Moving average methods are common in rolling analysis, and these methods lie at the heart of the technical analysis of financial time series. Moving averages typically use either equal weights for the observations or customized declining weights.
We create the new features by using rolling averages with and without weighs.

### Rolling Mean

First, we calculate the average daily series of the previous 30 and 60 available days for the daily rainfall, humidity and temperature.

``` r
# Compute Quarter indicator variable
allRes[, Quarter:= quarter(DATE)]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1961-01-01 1961     1            73               78
    ##       2:   229 1961-01-02 1961     1            88               82
    ##       3:   229 1961-01-03 1961     1            82               96
    ##       4:   229 1961-01-04 1961     1            80               78
    ##       5:   229 1961-01-05 1961     1            83               54
    ##      ---                                                           
    ## 1670905: 11386 2017-06-26 2017     6            58              230
    ## 1670906: 11386 2017-06-27 2017     6            61              235
    ## 1670907: 11386 2017-06-28 2017     6            59              198
    ## 1670908: 11386 2017-06-29 2017     6            55              168
    ## 1670909: 11386 2017-06-30 2017     6            52              166
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                    0               0                  0
    ##       2:                    2               0                  0
    ##       3:                   29               0                  0
    ##       4:                    0               0                  0
    ##       5:                    0               0                  0
    ##      ---                                                        
    ## 1670905:                   46               0                  0
    ## 1670906:                    2               0                  0
    ## 1670907:                   33               0                  0
    ## 1670908:                    0               0                  0
    ## 1670909:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons Group    MinDate    MaxDate Length
    ##       1:                      0 2102  2102 1961-01-01 2017-06-30  20634
    ##       2:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       3:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       4:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       5:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##      ---                                                               
    ## 1670905:                      0    0     0 2017-05-18 2017-06-30     43
    ## 1670906:                      0    0     0 2017-05-18 2017-06-30     43
    ## 1670907:                      0    0     0 2017-05-18 2017-06-30     43
    ## 1670908:                      0    0     0 2017-05-18 2017-06-30     43
    ## 1670909:                      0    0     0 2017-05-18 2017-06-30     43
    ##          Quarter
    ##       1:       1
    ##       2:       1
    ##       3:       1
    ##       4:       1
    ##       5:       1
    ##      ---        
    ## 1670905:       2
    ## 1670906:       2
    ## 1670907:       2
    ## 1670908:       2
    ## 1670909:       2

``` r
## Computation of rolling mean using as time window 30 days
# ---------------------------------------------------------

# As a pre-processing step we have to exclude the stations that have less than 30 observations
excludeStations30 <- allRes[, .N, by=STAID][N<30, STAID]
allRes <- allRes[!(STAID %in% excludeStations30)]

# Provide names of the variables to create
varsToCreate30 <- c("PrecipRollAverage30","HumidRollAverage30","TempRollAverage30")

# Provide list of the variables that will be used to compute rolling mean
varsToModify <- c("RR_DailyPrecipAmount", "RR_DailyHumid", "RR_DailyMeanTemp")

# Compute rolling mean using a time window of 30 days
# align is mandatory in order to calculate for each observation the rolling mean of the 30 previous values.
allRes[, c(varsToCreate30) := lapply(.SD, rollmean, 30, fill = NA, align = "right"),.SDcols = varsToModify, by = STAID]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1961-01-01 1961     1            73               78
    ##       2:   229 1961-01-02 1961     1            88               82
    ##       3:   229 1961-01-03 1961     1            82               96
    ##       4:   229 1961-01-04 1961     1            80               78
    ##       5:   229 1961-01-05 1961     1            83               54
    ##      ---                                                           
    ## 1670905: 11386 2017-06-26 2017     6            58              230
    ## 1670906: 11386 2017-06-27 2017     6            61              235
    ## 1670907: 11386 2017-06-28 2017     6            59              198
    ## 1670908: 11386 2017-06-29 2017     6            55              168
    ## 1670909: 11386 2017-06-30 2017     6            52              166
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                    0               0                  0
    ##       2:                    2               0                  0
    ##       3:                   29               0                  0
    ##       4:                    0               0                  0
    ##       5:                    0               0                  0
    ##      ---                                                        
    ## 1670905:                   46               0                  0
    ## 1670906:                    2               0                  0
    ## 1670907:                   33               0                  0
    ## 1670908:                    0               0                  0
    ## 1670909:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons Group    MinDate    MaxDate Length
    ##       1:                      0 2102  2102 1961-01-01 2017-06-30  20634
    ##       2:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       3:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       4:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       5:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##      ---                                                               
    ## 1670905:                      0    0     0 2017-05-18 2017-06-30     43
    ## 1670906:                      0    0     0 2017-05-18 2017-06-30     43
    ## 1670907:                      0    0     0 2017-05-18 2017-06-30     43
    ## 1670908:                      0    0     0 2017-05-18 2017-06-30     43
    ## 1670909:                      0    0     0 2017-05-18 2017-06-30     43
    ##          Quarter PrecipRollAverage30 HumidRollAverage30 TempRollAverage30
    ##       1:       1                  NA                 NA                NA
    ##       2:       1                  NA                 NA                NA
    ##       3:       1                  NA                 NA                NA
    ##       4:       1                  NA                 NA                NA
    ##       5:       1                  NA                 NA                NA
    ##      ---                                                                 
    ## 1670905:       2            9.200000           52.80000          228.8667
    ## 1670906:       2            9.266667           53.23333          229.5333
    ## 1670907:       2           10.366667           53.63333          229.6667
    ## 1670908:       2           10.366667           53.60000          229.5333
    ## 1670909:       2           10.366667           53.50000          228.6667

``` r
## Computation of rolling mean using as time window 60 days
# ---------------------------------------------------------

# As a pre-processing step we have to exclude the stations that have less than 60 observations
excludeStations60 <- allRes[, .N, by=STAID][N<60, STAID]
allRes <- allRes[!(STAID %in% excludeStations60)]

# Provide names of the variables to create
varsToCreate60 <- c("PrecipRollAverage60","HumidRollAverage60","TempRollAverage60")

# Provide list of the variables that will be used to compute rolling mean
varsToModify <- c("RR_DailyPrecipAmount", "RR_DailyHumid", "RR_DailyMeanTemp")

# Compute rolling mean using a time window of 60 days
# align is mandatory in order to calculate for each observation the rolling mean of the 60 previous values.
allRes[, c(varsToCreate60) := lapply(.SD, rollmean, 60, fill = NA, align = "right"),.SDcols = varsToModify, by = STAID]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1961-01-01 1961     1            73               78
    ##       2:   229 1961-01-02 1961     1            88               82
    ##       3:   229 1961-01-03 1961     1            82               96
    ##       4:   229 1961-01-04 1961     1            80               78
    ##       5:   229 1961-01-05 1961     1            83               54
    ##      ---                                                           
    ## 1670861: 11385 2017-06-26 2017     6            67              240
    ## 1670862: 11385 2017-06-27 2017     6            55              257
    ## 1670863: 11385 2017-06-28 2017     6            54              220
    ## 1670864: 11385 2017-06-29 2017     6            48              189
    ## 1670865: 11385 2017-06-30 2017     6            49              184
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                    0               0                  0
    ##       2:                    2               0                  0
    ##       3:                   29               0                  0
    ##       4:                    0               0                  0
    ##       5:                    0               0                  0
    ##      ---                                                        
    ## 1670861:                   28               0                  0
    ## 1670862:                    0               0                  0
    ## 1670863:                    4               0                  0
    ## 1670864:                    0               0                  0
    ## 1670865:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons Group    MinDate    MaxDate Length
    ##       1:                      0 2102  2102 1961-01-01 2017-06-30  20634
    ##       2:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       3:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       4:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       5:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##      ---                                                               
    ## 1670861:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670862:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670863:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670864:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670865:                      0    0     0 2017-01-25 2017-06-30    156
    ##          Quarter PrecipRollAverage30 HumidRollAverage30 TempRollAverage30
    ##       1:       1                  NA                 NA                NA
    ##       2:       1                  NA                 NA                NA
    ##       3:       1                  NA                 NA                NA
    ##       4:       1                  NA                 NA                NA
    ##       5:       1                  NA                 NA                NA
    ##      ---                                                                 
    ## 1670861:       2            14.50000           56.46667          238.6333
    ## 1670862:       2            14.50000           56.53333          239.8000
    ## 1670863:       2            14.46667           56.76667          240.1667
    ## 1670864:       2            14.46667           56.43333          240.1000
    ## 1670865:       2            14.46667           56.30000          239.5000
    ##          PrecipRollAverage60 HumidRollAverage60 TempRollAverage60
    ##       1:                  NA                 NA                NA
    ##       2:                  NA                 NA                NA
    ##       3:                  NA                 NA                NA
    ##       4:                  NA                 NA                NA
    ##       5:                  NA                 NA                NA
    ##      ---                                                         
    ## 1670861:            12.91667           57.96667          207.2833
    ## 1670862:            12.91667           57.81667          210.1833
    ## 1670863:            12.98333           57.51667          212.0500
    ## 1670864:            12.01667           57.10000          212.8833
    ## 1670865:            12.01667           57.03333          214.0333

``` r
str(allRes)
```

    ## Classes 'data.table' and 'data.frame':   1670865 obs. of  22 variables:
    ##  $ STAID                 : int  229 229 229 229 229 229 229 229 229 229 ...
    ##  $ DATE                  : Date, format: "1961-01-01" "1961-01-02" ...
    ##  $ Year                  : int  1961 1961 1961 1961 1961 1961 1961 1961 1961 1961 ...
    ##  $ Month                 : int  1 1 1 1 1 1 1 1 1 1 ...
    ##  $ RR_DailyHumid         : num  73 88 82 80 83 99 94 92 97 88 ...
    ##  $ RR_DailyMeanTemp      : num  78 82 96 78 54 24 67 113 58 94 ...
    ##  $ RR_DailyPrecipAmount  : num  0 2 29 0 0 0 0 0 2 2 ...
    ##  $ Q_RR_DailyHumid       : int  0 0 0 0 0 0 0 0 0 0 ...
    ##  $ Q_RR_DailyMeanTemp    : int  0 0 0 0 0 0 0 0 0 0 ...
    ##  $ Q_RR_DailyPrecipAmount: int  0 0 0 0 0 0 0 0 0 0 ...
    ##  $ Cons                  : num  2102 0 0 0 0 ...
    ##  $ Group                 : num  2102 2102 2102 2102 2102 ...
    ##  $ MinDate               : Date, format: "1961-01-01" "1961-01-01" ...
    ##  $ MaxDate               : Date, format: "2017-06-30" "2017-06-30" ...
    ##  $ Length                : num  20634 20634 20634 20634 20634 ...
    ##  $ Quarter               : int  1 1 1 1 1 1 1 1 1 1 ...
    ##  $ PrecipRollAverage30   : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ HumidRollAverage30    : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ TempRollAverage30     : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ PrecipRollAverage60   : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ HumidRollAverage60    : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ TempRollAverage60     : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  - attr(*, "sorted")= chr "STAID"
    ##  - attr(*, ".internal.selfref")=<externalptr>

### Lag

The lag of each one of the available meteorological variables is calculated to capture possible daily dependencies. In the following script we calculate lags for the five previous days:

``` r
## Computation of daily lag variables t-1 up to t-5
# ---------------------------------------------------------

# Provide names of the variables to create
varsToCreateLag <- c("Preciplag", "Humidlag", "Templag")

# Provide list of the variables that will be used to compute rolling mean
varsToModify    <- c("RR_DailyPrecipAmount", "RR_DailyHumid", "RR_DailyMeanTemp")

# Perform a for loop to compute variables for each lag
for (i in 1:5){
  print(paste0("Computing step ",i,"\n"))
  
  allRes[, paste0(varsToCreateLag,i):= lapply(.SD, data.table::shift,
                                           type = "lag",
                                           n    = i,
                                           fill = NA
                                           ), 
                .SDcols = varsToModify,
      by = STAID
      ]
}
```

    ## [1] "Computing step 1\n"
    ## [1] "Computing step 2\n"
    ## [1] "Computing step 3\n"
    ## [1] "Computing step 4\n"
    ## [1] "Computing step 5\n"

### Rolling Weighted Mean

In this section, we compute a weighted rolling mean so us to give more weight to the more recent variables:

``` r
## Computation of rolling weighted mean using as time window 15 days
# ---------------------------------------------------------

# Create a custom vector of weights
customWeights <- 1:15/30

# Provide names of the variables to create
varsToCreateWeightRollMean <- c("RainweightedRollMean15",
                                "TempweightedRollMean15",
                                "HumidweightedRollMean15")

# Provide list of the variables that will be used to compute the weighted rolling mean
varsToModify               <- c("RR_DailyPrecipAmount", "RR_DailyHumid", "RR_DailyMeanTemp")


# Compute weighted rolling mean for the previous 15 days of each record per station
allRes[, c(varsToCreateWeightRollMean):= lapply(.SD,
                                            roll_mean,
                                            n       = 15L,
                                            weights = customWeights,
                                            fill    = NA,
                                            align   = "right"),
    .SDcols = varsToModify,
    by=STAID
    ]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1961-01-01 1961     1            73               78
    ##       2:   229 1961-01-02 1961     1            88               82
    ##       3:   229 1961-01-03 1961     1            82               96
    ##       4:   229 1961-01-04 1961     1            80               78
    ##       5:   229 1961-01-05 1961     1            83               54
    ##      ---                                                           
    ## 1670861: 11385 2017-06-26 2017     6            67              240
    ## 1670862: 11385 2017-06-27 2017     6            55              257
    ## 1670863: 11385 2017-06-28 2017     6            54              220
    ## 1670864: 11385 2017-06-29 2017     6            48              189
    ## 1670865: 11385 2017-06-30 2017     6            49              184
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                    0               0                  0
    ##       2:                    2               0                  0
    ##       3:                   29               0                  0
    ##       4:                    0               0                  0
    ##       5:                    0               0                  0
    ##      ---                                                        
    ## 1670861:                   28               0                  0
    ## 1670862:                    0               0                  0
    ## 1670863:                    4               0                  0
    ## 1670864:                    0               0                  0
    ## 1670865:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons Group    MinDate    MaxDate Length
    ##       1:                      0 2102  2102 1961-01-01 2017-06-30  20634
    ##       2:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       3:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       4:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       5:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##      ---                                                               
    ## 1670861:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670862:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670863:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670864:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670865:                      0    0     0 2017-01-25 2017-06-30    156
    ##          Quarter PrecipRollAverage30 HumidRollAverage30 TempRollAverage30
    ##       1:       1                  NA                 NA                NA
    ##       2:       1                  NA                 NA                NA
    ##       3:       1                  NA                 NA                NA
    ##       4:       1                  NA                 NA                NA
    ##       5:       1                  NA                 NA                NA
    ##      ---                                                                 
    ## 1670861:       2            14.50000           56.46667          238.6333
    ## 1670862:       2            14.50000           56.53333          239.8000
    ## 1670863:       2            14.46667           56.76667          240.1667
    ## 1670864:       2            14.46667           56.43333          240.1000
    ## 1670865:       2            14.46667           56.30000          239.5000
    ##          PrecipRollAverage60 HumidRollAverage60 TempRollAverage60
    ##       1:                  NA                 NA                NA
    ##       2:                  NA                 NA                NA
    ##       3:                  NA                 NA                NA
    ##       4:                  NA                 NA                NA
    ##       5:                  NA                 NA                NA
    ##      ---                                                         
    ## 1670861:            12.91667           57.96667          207.2833
    ## 1670862:            12.91667           57.81667          210.1833
    ## 1670863:            12.98333           57.51667          212.0500
    ## 1670864:            12.01667           57.10000          212.8833
    ## 1670865:            12.01667           57.03333          214.0333
    ##          Preciplag1 Humidlag1 Templag1 Preciplag2 Humidlag2 Templag2
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:          0        73       78         NA        NA       NA
    ##       3:          2        88       82          0        73       78
    ##       4:         29        82       96          2        88       82
    ##       5:          0        80       78         29        82       96
    ##      ---                                                            
    ## 1670861:          3        66      247          0        58      267
    ## 1670862:         28        67      240          3        66      247
    ## 1670863:          0        55      257         28        67      240
    ## 1670864:          4        54      220          0        55      257
    ## 1670865:          0        48      189          4        54      220
    ##          Preciplag3 Humidlag3 Templag3 Preciplag4 Humidlag4 Templag4
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:         NA        NA       NA         NA        NA       NA
    ##       3:         NA        NA       NA         NA        NA       NA
    ##       4:          0        73       78         NA        NA       NA
    ##       5:          2        88       82          0        73       78
    ##      ---                                                            
    ## 1670861:          0        50      281          0        49      282
    ## 1670862:          0        58      267          0        50      281
    ## 1670863:          3        66      247          0        58      267
    ## 1670864:         28        67      240          3        66      247
    ## 1670865:          0        55      257         28        67      240
    ##          Preciplag5 Humidlag5 Templag5 RainweightedRollMean15
    ##       1:         NA        NA       NA                     NA
    ##       2:         NA        NA       NA                     NA
    ##       3:         NA        NA       NA                     NA
    ##       4:         NA        NA       NA                     NA
    ##       5:         NA        NA       NA                     NA
    ##      ---                                                     
    ## 1670861:          0        54      269               3.850000
    ## 1670862:          0        49      282               3.591667
    ## 1670863:          0        50      281               3.833333
    ## 1670864:          0        58      267               3.541667
    ## 1670865:          3        66      247               3.250000
    ##          TempweightedRollMean15 HumidweightedRollMean15
    ##       1:                     NA                      NA
    ##       2:                     NA                      NA
    ##       3:                     NA                      NA
    ##       4:                     NA                      NA
    ##       5:                     NA                      NA
    ##      ---                                               
    ## 1670861:               55.23333                265.4833
    ## 1670862:               55.62500                264.1750
    ## 1670863:               55.80833                258.2417
    ## 1670864:               55.15833                248.8167
    ## 1670865:               54.56667                239.4833

### Rolling Standard Deviation

The same logic can be applied to compute the rolling standard deviation:

``` r
## Computation of rolling sd using as time window 15 days
# ---------------------------------------------------------

# Provide names of the variables to create
varsToCreateWeightRollSD <- c("RainweightedRollSd15",
                              "TempweightedRollSd15",
                              "HumidweightedRollSd15")

# Provide list of the variables that will be used to compute the weighted rolling sd
varsToModify               <- c("RR_DailyPrecipAmount", "RR_DailyHumid", "RR_DailyMeanTemp")


# Compute weighted rolling sd for the previous 15 days of each record per station
allRes[, (varsToCreateWeightRollSD):= lapply(.SD,
                                            roll_sd,
                                            n       = 15L,
                                            weights = customWeights,
                                            fill    = NA,
                                            align   = "right"),
    .SDcols = varsToModify,
    by=STAID
    ]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1961-01-01 1961     1            73               78
    ##       2:   229 1961-01-02 1961     1            88               82
    ##       3:   229 1961-01-03 1961     1            82               96
    ##       4:   229 1961-01-04 1961     1            80               78
    ##       5:   229 1961-01-05 1961     1            83               54
    ##      ---                                                           
    ## 1670861: 11385 2017-06-26 2017     6            67              240
    ## 1670862: 11385 2017-06-27 2017     6            55              257
    ## 1670863: 11385 2017-06-28 2017     6            54              220
    ## 1670864: 11385 2017-06-29 2017     6            48              189
    ## 1670865: 11385 2017-06-30 2017     6            49              184
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                    0               0                  0
    ##       2:                    2               0                  0
    ##       3:                   29               0                  0
    ##       4:                    0               0                  0
    ##       5:                    0               0                  0
    ##      ---                                                        
    ## 1670861:                   28               0                  0
    ## 1670862:                    0               0                  0
    ## 1670863:                    4               0                  0
    ## 1670864:                    0               0                  0
    ## 1670865:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons Group    MinDate    MaxDate Length
    ##       1:                      0 2102  2102 1961-01-01 2017-06-30  20634
    ##       2:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       3:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       4:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       5:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##      ---                                                               
    ## 1670861:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670862:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670863:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670864:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670865:                      0    0     0 2017-01-25 2017-06-30    156
    ##          Quarter PrecipRollAverage30 HumidRollAverage30 TempRollAverage30
    ##       1:       1                  NA                 NA                NA
    ##       2:       1                  NA                 NA                NA
    ##       3:       1                  NA                 NA                NA
    ##       4:       1                  NA                 NA                NA
    ##       5:       1                  NA                 NA                NA
    ##      ---                                                                 
    ## 1670861:       2            14.50000           56.46667          238.6333
    ## 1670862:       2            14.50000           56.53333          239.8000
    ## 1670863:       2            14.46667           56.76667          240.1667
    ## 1670864:       2            14.46667           56.43333          240.1000
    ## 1670865:       2            14.46667           56.30000          239.5000
    ##          PrecipRollAverage60 HumidRollAverage60 TempRollAverage60
    ##       1:                  NA                 NA                NA
    ##       2:                  NA                 NA                NA
    ##       3:                  NA                 NA                NA
    ##       4:                  NA                 NA                NA
    ##       5:                  NA                 NA                NA
    ##      ---                                                         
    ## 1670861:            12.91667           57.96667          207.2833
    ## 1670862:            12.91667           57.81667          210.1833
    ## 1670863:            12.98333           57.51667          212.0500
    ## 1670864:            12.01667           57.10000          212.8833
    ## 1670865:            12.01667           57.03333          214.0333
    ##          Preciplag1 Humidlag1 Templag1 Preciplag2 Humidlag2 Templag2
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:          0        73       78         NA        NA       NA
    ##       3:          2        88       82          0        73       78
    ##       4:         29        82       96          2        88       82
    ##       5:          0        80       78         29        82       96
    ##      ---                                                            
    ## 1670861:          3        66      247          0        58      267
    ## 1670862:         28        67      240          3        66      247
    ## 1670863:          0        55      257         28        67      240
    ## 1670864:          4        54      220          0        55      257
    ## 1670865:          0        48      189          4        54      220
    ##          Preciplag3 Humidlag3 Templag3 Preciplag4 Humidlag4 Templag4
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:         NA        NA       NA         NA        NA       NA
    ##       3:         NA        NA       NA         NA        NA       NA
    ##       4:          0        73       78         NA        NA       NA
    ##       5:          2        88       82          0        73       78
    ##      ---                                                            
    ## 1670861:          0        50      281          0        49      282
    ## 1670862:          0        58      267          0        50      281
    ## 1670863:          3        66      247          0        58      267
    ## 1670864:         28        67      240          3        66      247
    ## 1670865:          0        55      257         28        67      240
    ##          Preciplag5 Humidlag5 Templag5 RainweightedRollMean15
    ##       1:         NA        NA       NA                     NA
    ##       2:         NA        NA       NA                     NA
    ##       3:         NA        NA       NA                     NA
    ##       4:         NA        NA       NA                     NA
    ##       5:         NA        NA       NA                     NA
    ##      ---                                                     
    ## 1670861:          0        54      269               3.850000
    ## 1670862:          0        49      282               3.591667
    ## 1670863:          0        50      281               3.833333
    ## 1670864:          0        58      267               3.541667
    ## 1670865:          3        66      247               3.250000
    ##          TempweightedRollMean15 HumidweightedRollMean15
    ##       1:                     NA                      NA
    ##       2:                     NA                      NA
    ##       3:                     NA                      NA
    ##       4:                     NA                      NA
    ##       5:                     NA                      NA
    ##      ---                                               
    ## 1670861:               55.23333                265.4833
    ## 1670862:               55.62500                264.1750
    ## 1670863:               55.80833                258.2417
    ## 1670864:               55.15833                248.8167
    ## 1670865:               54.56667                239.4833
    ##          RainweightedRollSd15 TempweightedRollSd15 HumidweightedRollSd15
    ##       1:                   NA                   NA                    NA
    ##       2:                   NA                   NA                    NA
    ##       3:                   NA                   NA                    NA
    ##       4:                   NA                   NA                    NA
    ##       5:                   NA                   NA                    NA
    ##      ---                                                                
    ## 1670861:            13.526363             36.76821              142.8937
    ## 1670862:            12.624422             35.75612              141.4852
    ## 1670863:            11.730100             34.55831              133.9859
    ## 1670864:            10.829406             32.45483              123.5142
    ## 1670865:             9.928764             30.80808              113.8534

### Rolling Quantile

``` r
## Computation of rolling quantile (90%) using as time window 15 days
# ---------------------------------------------------------

allRes[, RainRollQuantile15:=  caTools::runquantile(RR_DailyPrecipAmount, k = 15, 
                                                    probs = 0.9, endrule="NA", align = "right"), by = STAID]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1961-01-01 1961     1            73               78
    ##       2:   229 1961-01-02 1961     1            88               82
    ##       3:   229 1961-01-03 1961     1            82               96
    ##       4:   229 1961-01-04 1961     1            80               78
    ##       5:   229 1961-01-05 1961     1            83               54
    ##      ---                                                           
    ## 1670861: 11385 2017-06-26 2017     6            67              240
    ## 1670862: 11385 2017-06-27 2017     6            55              257
    ## 1670863: 11385 2017-06-28 2017     6            54              220
    ## 1670864: 11385 2017-06-29 2017     6            48              189
    ## 1670865: 11385 2017-06-30 2017     6            49              184
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                    0               0                  0
    ##       2:                    2               0                  0
    ##       3:                   29               0                  0
    ##       4:                    0               0                  0
    ##       5:                    0               0                  0
    ##      ---                                                        
    ## 1670861:                   28               0                  0
    ## 1670862:                    0               0                  0
    ## 1670863:                    4               0                  0
    ## 1670864:                    0               0                  0
    ## 1670865:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons Group    MinDate    MaxDate Length
    ##       1:                      0 2102  2102 1961-01-01 2017-06-30  20634
    ##       2:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       3:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       4:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       5:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##      ---                                                               
    ## 1670861:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670862:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670863:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670864:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670865:                      0    0     0 2017-01-25 2017-06-30    156
    ##          Quarter PrecipRollAverage30 HumidRollAverage30 TempRollAverage30
    ##       1:       1                  NA                 NA                NA
    ##       2:       1                  NA                 NA                NA
    ##       3:       1                  NA                 NA                NA
    ##       4:       1                  NA                 NA                NA
    ##       5:       1                  NA                 NA                NA
    ##      ---                                                                 
    ## 1670861:       2            14.50000           56.46667          238.6333
    ## 1670862:       2            14.50000           56.53333          239.8000
    ## 1670863:       2            14.46667           56.76667          240.1667
    ## 1670864:       2            14.46667           56.43333          240.1000
    ## 1670865:       2            14.46667           56.30000          239.5000
    ##          PrecipRollAverage60 HumidRollAverage60 TempRollAverage60
    ##       1:                  NA                 NA                NA
    ##       2:                  NA                 NA                NA
    ##       3:                  NA                 NA                NA
    ##       4:                  NA                 NA                NA
    ##       5:                  NA                 NA                NA
    ##      ---                                                         
    ## 1670861:            12.91667           57.96667          207.2833
    ## 1670862:            12.91667           57.81667          210.1833
    ## 1670863:            12.98333           57.51667          212.0500
    ## 1670864:            12.01667           57.10000          212.8833
    ## 1670865:            12.01667           57.03333          214.0333
    ##          Preciplag1 Humidlag1 Templag1 Preciplag2 Humidlag2 Templag2
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:          0        73       78         NA        NA       NA
    ##       3:          2        88       82          0        73       78
    ##       4:         29        82       96          2        88       82
    ##       5:          0        80       78         29        82       96
    ##      ---                                                            
    ## 1670861:          3        66      247          0        58      267
    ## 1670862:         28        67      240          3        66      247
    ## 1670863:          0        55      257         28        67      240
    ## 1670864:          4        54      220          0        55      257
    ## 1670865:          0        48      189          4        54      220
    ##          Preciplag3 Humidlag3 Templag3 Preciplag4 Humidlag4 Templag4
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:         NA        NA       NA         NA        NA       NA
    ##       3:         NA        NA       NA         NA        NA       NA
    ##       4:          0        73       78         NA        NA       NA
    ##       5:          2        88       82          0        73       78
    ##      ---                                                            
    ## 1670861:          0        50      281          0        49      282
    ## 1670862:          0        58      267          0        50      281
    ## 1670863:          3        66      247          0        58      267
    ## 1670864:         28        67      240          3        66      247
    ## 1670865:          0        55      257         28        67      240
    ##          Preciplag5 Humidlag5 Templag5 RainweightedRollMean15
    ##       1:         NA        NA       NA                     NA
    ##       2:         NA        NA       NA                     NA
    ##       3:         NA        NA       NA                     NA
    ##       4:         NA        NA       NA                     NA
    ##       5:         NA        NA       NA                     NA
    ##      ---                                                     
    ## 1670861:          0        54      269               3.850000
    ## 1670862:          0        49      282               3.591667
    ## 1670863:          0        50      281               3.833333
    ## 1670864:          0        58      267               3.541667
    ## 1670865:          3        66      247               3.250000
    ##          TempweightedRollMean15 HumidweightedRollMean15
    ##       1:                     NA                      NA
    ##       2:                     NA                      NA
    ##       3:                     NA                      NA
    ##       4:                     NA                      NA
    ##       5:                     NA                      NA
    ##      ---                                               
    ## 1670861:               55.23333                265.4833
    ## 1670862:               55.62500                264.1750
    ## 1670863:               55.80833                258.2417
    ## 1670864:               55.15833                248.8167
    ## 1670865:               54.56667                239.4833
    ##          RainweightedRollSd15 TempweightedRollSd15 HumidweightedRollSd15
    ##       1:                   NA                   NA                    NA
    ##       2:                   NA                   NA                    NA
    ##       3:                   NA                   NA                    NA
    ##       4:                   NA                   NA                    NA
    ##       5:                   NA                   NA                    NA
    ##      ---                                                                
    ## 1670861:            13.526363             36.76821              142.8937
    ## 1670862:            12.624422             35.75612              141.4852
    ## 1670863:            11.730100             34.55831              133.9859
    ## 1670864:            10.829406             32.45483              123.5142
    ## 1670865:             9.928764             30.80808              113.8534
    ##          RainRollQuantile15
    ##       1:                 NA
    ##       2:                 NA
    ##       3:                 NA
    ##       4:                 NA
    ##       5:                 NA
    ##      ---                   
    ## 1670861:                1.8
    ## 1670862:                1.8
    ## 1670863:                3.6
    ## 1670864:                3.6
    ## 1670865:                3.6

``` r
allRes[, TempRollQuantile15:=  caTools::runquantile(RR_DailyMeanTemp, k = 15, 
                                                    probs = 0.9, endrule="NA", align = "right"), by = STAID]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1961-01-01 1961     1            73               78
    ##       2:   229 1961-01-02 1961     1            88               82
    ##       3:   229 1961-01-03 1961     1            82               96
    ##       4:   229 1961-01-04 1961     1            80               78
    ##       5:   229 1961-01-05 1961     1            83               54
    ##      ---                                                           
    ## 1670861: 11385 2017-06-26 2017     6            67              240
    ## 1670862: 11385 2017-06-27 2017     6            55              257
    ## 1670863: 11385 2017-06-28 2017     6            54              220
    ## 1670864: 11385 2017-06-29 2017     6            48              189
    ## 1670865: 11385 2017-06-30 2017     6            49              184
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                    0               0                  0
    ##       2:                    2               0                  0
    ##       3:                   29               0                  0
    ##       4:                    0               0                  0
    ##       5:                    0               0                  0
    ##      ---                                                        
    ## 1670861:                   28               0                  0
    ## 1670862:                    0               0                  0
    ## 1670863:                    4               0                  0
    ## 1670864:                    0               0                  0
    ## 1670865:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons Group    MinDate    MaxDate Length
    ##       1:                      0 2102  2102 1961-01-01 2017-06-30  20634
    ##       2:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       3:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       4:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       5:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##      ---                                                               
    ## 1670861:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670862:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670863:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670864:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670865:                      0    0     0 2017-01-25 2017-06-30    156
    ##          Quarter PrecipRollAverage30 HumidRollAverage30 TempRollAverage30
    ##       1:       1                  NA                 NA                NA
    ##       2:       1                  NA                 NA                NA
    ##       3:       1                  NA                 NA                NA
    ##       4:       1                  NA                 NA                NA
    ##       5:       1                  NA                 NA                NA
    ##      ---                                                                 
    ## 1670861:       2            14.50000           56.46667          238.6333
    ## 1670862:       2            14.50000           56.53333          239.8000
    ## 1670863:       2            14.46667           56.76667          240.1667
    ## 1670864:       2            14.46667           56.43333          240.1000
    ## 1670865:       2            14.46667           56.30000          239.5000
    ##          PrecipRollAverage60 HumidRollAverage60 TempRollAverage60
    ##       1:                  NA                 NA                NA
    ##       2:                  NA                 NA                NA
    ##       3:                  NA                 NA                NA
    ##       4:                  NA                 NA                NA
    ##       5:                  NA                 NA                NA
    ##      ---                                                         
    ## 1670861:            12.91667           57.96667          207.2833
    ## 1670862:            12.91667           57.81667          210.1833
    ## 1670863:            12.98333           57.51667          212.0500
    ## 1670864:            12.01667           57.10000          212.8833
    ## 1670865:            12.01667           57.03333          214.0333
    ##          Preciplag1 Humidlag1 Templag1 Preciplag2 Humidlag2 Templag2
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:          0        73       78         NA        NA       NA
    ##       3:          2        88       82          0        73       78
    ##       4:         29        82       96          2        88       82
    ##       5:          0        80       78         29        82       96
    ##      ---                                                            
    ## 1670861:          3        66      247          0        58      267
    ## 1670862:         28        67      240          3        66      247
    ## 1670863:          0        55      257         28        67      240
    ## 1670864:          4        54      220          0        55      257
    ## 1670865:          0        48      189          4        54      220
    ##          Preciplag3 Humidlag3 Templag3 Preciplag4 Humidlag4 Templag4
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:         NA        NA       NA         NA        NA       NA
    ##       3:         NA        NA       NA         NA        NA       NA
    ##       4:          0        73       78         NA        NA       NA
    ##       5:          2        88       82          0        73       78
    ##      ---                                                            
    ## 1670861:          0        50      281          0        49      282
    ## 1670862:          0        58      267          0        50      281
    ## 1670863:          3        66      247          0        58      267
    ## 1670864:         28        67      240          3        66      247
    ## 1670865:          0        55      257         28        67      240
    ##          Preciplag5 Humidlag5 Templag5 RainweightedRollMean15
    ##       1:         NA        NA       NA                     NA
    ##       2:         NA        NA       NA                     NA
    ##       3:         NA        NA       NA                     NA
    ##       4:         NA        NA       NA                     NA
    ##       5:         NA        NA       NA                     NA
    ##      ---                                                     
    ## 1670861:          0        54      269               3.850000
    ## 1670862:          0        49      282               3.591667
    ## 1670863:          0        50      281               3.833333
    ## 1670864:          0        58      267               3.541667
    ## 1670865:          3        66      247               3.250000
    ##          TempweightedRollMean15 HumidweightedRollMean15
    ##       1:                     NA                      NA
    ##       2:                     NA                      NA
    ##       3:                     NA                      NA
    ##       4:                     NA                      NA
    ##       5:                     NA                      NA
    ##      ---                                               
    ## 1670861:               55.23333                265.4833
    ## 1670862:               55.62500                264.1750
    ## 1670863:               55.80833                258.2417
    ## 1670864:               55.15833                248.8167
    ## 1670865:               54.56667                239.4833
    ##          RainweightedRollSd15 TempweightedRollSd15 HumidweightedRollSd15
    ##       1:                   NA                   NA                    NA
    ##       2:                   NA                   NA                    NA
    ##       3:                   NA                   NA                    NA
    ##       4:                   NA                   NA                    NA
    ##       5:                   NA                   NA                    NA
    ##      ---                                                                
    ## 1670861:            13.526363             36.76821              142.8937
    ## 1670862:            12.624422             35.75612              141.4852
    ## 1670863:            11.730100             34.55831              133.9859
    ## 1670864:            10.829406             32.45483              123.5142
    ## 1670865:             9.928764             30.80808              113.8534
    ##          RainRollQuantile15 TempRollQuantile15
    ##       1:                 NA                 NA
    ##       2:                 NA                 NA
    ##       3:                 NA                 NA
    ##       4:                 NA                 NA
    ##       5:                 NA                 NA
    ##      ---                                      
    ## 1670861:                1.8              279.0
    ## 1670862:                1.8              279.0
    ## 1670863:                3.6              279.0
    ## 1670864:                3.6              279.0
    ## 1670865:                3.6              277.8

``` r
allRes[, HumidRollQuantile15:=  caTools::runquantile(RR_DailyHumid, k = 15, 
                                                     probs = 0.9, endrule="NA", align = "right"), by = STAID]
```

    ##          STAID       DATE Year Month RR_DailyHumid RR_DailyMeanTemp
    ##       1:   229 1961-01-01 1961     1            73               78
    ##       2:   229 1961-01-02 1961     1            88               82
    ##       3:   229 1961-01-03 1961     1            82               96
    ##       4:   229 1961-01-04 1961     1            80               78
    ##       5:   229 1961-01-05 1961     1            83               54
    ##      ---                                                           
    ## 1670861: 11385 2017-06-26 2017     6            67              240
    ## 1670862: 11385 2017-06-27 2017     6            55              257
    ## 1670863: 11385 2017-06-28 2017     6            54              220
    ## 1670864: 11385 2017-06-29 2017     6            48              189
    ## 1670865: 11385 2017-06-30 2017     6            49              184
    ##          RR_DailyPrecipAmount Q_RR_DailyHumid Q_RR_DailyMeanTemp
    ##       1:                    0               0                  0
    ##       2:                    2               0                  0
    ##       3:                   29               0                  0
    ##       4:                    0               0                  0
    ##       5:                    0               0                  0
    ##      ---                                                        
    ## 1670861:                   28               0                  0
    ## 1670862:                    0               0                  0
    ## 1670863:                    4               0                  0
    ## 1670864:                    0               0                  0
    ## 1670865:                    0               0                  0
    ##          Q_RR_DailyPrecipAmount Cons Group    MinDate    MaxDate Length
    ##       1:                      0 2102  2102 1961-01-01 2017-06-30  20634
    ##       2:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       3:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       4:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##       5:                      0    0  2102 1961-01-01 2017-06-30  20634
    ##      ---                                                               
    ## 1670861:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670862:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670863:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670864:                      0    0     0 2017-01-25 2017-06-30    156
    ## 1670865:                      0    0     0 2017-01-25 2017-06-30    156
    ##          Quarter PrecipRollAverage30 HumidRollAverage30 TempRollAverage30
    ##       1:       1                  NA                 NA                NA
    ##       2:       1                  NA                 NA                NA
    ##       3:       1                  NA                 NA                NA
    ##       4:       1                  NA                 NA                NA
    ##       5:       1                  NA                 NA                NA
    ##      ---                                                                 
    ## 1670861:       2            14.50000           56.46667          238.6333
    ## 1670862:       2            14.50000           56.53333          239.8000
    ## 1670863:       2            14.46667           56.76667          240.1667
    ## 1670864:       2            14.46667           56.43333          240.1000
    ## 1670865:       2            14.46667           56.30000          239.5000
    ##          PrecipRollAverage60 HumidRollAverage60 TempRollAverage60
    ##       1:                  NA                 NA                NA
    ##       2:                  NA                 NA                NA
    ##       3:                  NA                 NA                NA
    ##       4:                  NA                 NA                NA
    ##       5:                  NA                 NA                NA
    ##      ---                                                         
    ## 1670861:            12.91667           57.96667          207.2833
    ## 1670862:            12.91667           57.81667          210.1833
    ## 1670863:            12.98333           57.51667          212.0500
    ## 1670864:            12.01667           57.10000          212.8833
    ## 1670865:            12.01667           57.03333          214.0333
    ##          Preciplag1 Humidlag1 Templag1 Preciplag2 Humidlag2 Templag2
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:          0        73       78         NA        NA       NA
    ##       3:          2        88       82          0        73       78
    ##       4:         29        82       96          2        88       82
    ##       5:          0        80       78         29        82       96
    ##      ---                                                            
    ## 1670861:          3        66      247          0        58      267
    ## 1670862:         28        67      240          3        66      247
    ## 1670863:          0        55      257         28        67      240
    ## 1670864:          4        54      220          0        55      257
    ## 1670865:          0        48      189          4        54      220
    ##          Preciplag3 Humidlag3 Templag3 Preciplag4 Humidlag4 Templag4
    ##       1:         NA        NA       NA         NA        NA       NA
    ##       2:         NA        NA       NA         NA        NA       NA
    ##       3:         NA        NA       NA         NA        NA       NA
    ##       4:          0        73       78         NA        NA       NA
    ##       5:          2        88       82          0        73       78
    ##      ---                                                            
    ## 1670861:          0        50      281          0        49      282
    ## 1670862:          0        58      267          0        50      281
    ## 1670863:          3        66      247          0        58      267
    ## 1670864:         28        67      240          3        66      247
    ## 1670865:          0        55      257         28        67      240
    ##          Preciplag5 Humidlag5 Templag5 RainweightedRollMean15
    ##       1:         NA        NA       NA                     NA
    ##       2:         NA        NA       NA                     NA
    ##       3:         NA        NA       NA                     NA
    ##       4:         NA        NA       NA                     NA
    ##       5:         NA        NA       NA                     NA
    ##      ---                                                     
    ## 1670861:          0        54      269               3.850000
    ## 1670862:          0        49      282               3.591667
    ## 1670863:          0        50      281               3.833333
    ## 1670864:          0        58      267               3.541667
    ## 1670865:          3        66      247               3.250000
    ##          TempweightedRollMean15 HumidweightedRollMean15
    ##       1:                     NA                      NA
    ##       2:                     NA                      NA
    ##       3:                     NA                      NA
    ##       4:                     NA                      NA
    ##       5:                     NA                      NA
    ##      ---                                               
    ## 1670861:               55.23333                265.4833
    ## 1670862:               55.62500                264.1750
    ## 1670863:               55.80833                258.2417
    ## 1670864:               55.15833                248.8167
    ## 1670865:               54.56667                239.4833
    ##          RainweightedRollSd15 TempweightedRollSd15 HumidweightedRollSd15
    ##       1:                   NA                   NA                    NA
    ##       2:                   NA                   NA                    NA
    ##       3:                   NA                   NA                    NA
    ##       4:                   NA                   NA                    NA
    ##       5:                   NA                   NA                    NA
    ##      ---                                                                
    ## 1670861:            13.526363             36.76821              142.8937
    ## 1670862:            12.624422             35.75612              141.4852
    ## 1670863:            11.730100             34.55831              133.9859
    ## 1670864:            10.829406             32.45483              123.5142
    ## 1670865:             9.928764             30.80808              113.8534
    ##          RainRollQuantile15 TempRollQuantile15 HumidRollQuantile15
    ##       1:                 NA                 NA                  NA
    ##       2:                 NA                 NA                  NA
    ##       3:                 NA                 NA                  NA
    ##       4:                 NA                 NA                  NA
    ##       5:                 NA                 NA                  NA
    ##      ---                                                          
    ## 1670861:                1.8              279.0                62.8
    ## 1670862:                1.8              279.0                62.8
    ## 1670863:                3.6              279.0                62.8
    ## 1670864:                3.6              279.0                62.8
    ## 1670865:                3.6              277.8                62.8

``` r
str(allRes)
```

    ## Classes 'data.table' and 'data.frame':   1670865 obs. of  46 variables:
    ##  $ STAID                  : int  229 229 229 229 229 229 229 229 229 229 ...
    ##  $ DATE                   : Date, format: "1961-01-01" "1961-01-02" ...
    ##  $ Year                   : int  1961 1961 1961 1961 1961 1961 1961 1961 1961 1961 ...
    ##  $ Month                  : int  1 1 1 1 1 1 1 1 1 1 ...
    ##  $ RR_DailyHumid          : num  73 88 82 80 83 99 94 92 97 88 ...
    ##  $ RR_DailyMeanTemp       : num  78 82 96 78 54 24 67 113 58 94 ...
    ##  $ RR_DailyPrecipAmount   : num  0 2 29 0 0 0 0 0 2 2 ...
    ##  $ Q_RR_DailyHumid        : int  0 0 0 0 0 0 0 0 0 0 ...
    ##  $ Q_RR_DailyMeanTemp     : int  0 0 0 0 0 0 0 0 0 0 ...
    ##  $ Q_RR_DailyPrecipAmount : int  0 0 0 0 0 0 0 0 0 0 ...
    ##  $ Cons                   : num  2102 0 0 0 0 ...
    ##  $ Group                  : num  2102 2102 2102 2102 2102 ...
    ##  $ MinDate                : Date, format: "1961-01-01" "1961-01-01" ...
    ##  $ MaxDate                : Date, format: "2017-06-30" "2017-06-30" ...
    ##  $ Length                 : num  20634 20634 20634 20634 20634 ...
    ##  $ Quarter                : int  1 1 1 1 1 1 1 1 1 1 ...
    ##  $ PrecipRollAverage30    : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ HumidRollAverage30     : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ TempRollAverage30      : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ PrecipRollAverage60    : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ HumidRollAverage60     : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ TempRollAverage60      : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ Preciplag1             : num  NA 0 2 29 0 0 0 0 0 2 ...
    ##  $ Humidlag1              : num  NA 73 88 82 80 83 99 94 92 97 ...
    ##  $ Templag1               : num  NA 78 82 96 78 54 24 67 113 58 ...
    ##  $ Preciplag2             : num  NA NA 0 2 29 0 0 0 0 0 ...
    ##  $ Humidlag2              : num  NA NA 73 88 82 80 83 99 94 92 ...
    ##  $ Templag2               : num  NA NA 78 82 96 78 54 24 67 113 ...
    ##  $ Preciplag3             : num  NA NA NA 0 2 29 0 0 0 0 ...
    ##  $ Humidlag3              : num  NA NA NA 73 88 82 80 83 99 94 ...
    ##  $ Templag3               : num  NA NA NA 78 82 96 78 54 24 67 ...
    ##  $ Preciplag4             : num  NA NA NA NA 0 2 29 0 0 0 ...
    ##  $ Humidlag4              : num  NA NA NA NA 73 88 82 80 83 99 ...
    ##  $ Templag4               : num  NA NA NA NA 78 82 96 78 54 24 ...
    ##  $ Preciplag5             : num  NA NA NA NA NA 0 2 29 0 0 ...
    ##  $ Humidlag5              : num  NA NA NA NA NA 73 88 82 80 83 ...
    ##  $ Templag5               : num  NA NA NA NA NA 78 82 96 78 54 ...
    ##  $ RainweightedRollMean15 : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ TempweightedRollMean15 : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ HumidweightedRollMean15: num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ RainweightedRollSd15   : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ TempweightedRollSd15   : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ HumidweightedRollSd15  : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ RainRollQuantile15     : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ TempRollQuantile15     : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  $ HumidRollQuantile15    : num  NA NA NA NA NA NA NA NA NA NA ...
    ##  - attr(*, "sorted")= chr "STAID"
    ##  - attr(*, ".internal.selfref")=<externalptr>
