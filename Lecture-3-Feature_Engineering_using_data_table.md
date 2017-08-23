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
-   [Feature engineering](#feature-engineering)
    -   [Obtain records for the maximum period of consecutive rainfall](#obtain-records-for-the-maximum-period-of-consecutive-rainfall)
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
  
  tempDownloadPath <- paste0(currPath,"/",metVarID,"/")
  precipStat  <-  paste0(currPath,"/",metVarID,"/stations.txt")
  tempMapping <- data.table(read.table(precipStat, skip = 16 ,sep=",",
                                       stringsAsFactors = FALSE, header=TRUE, quote=""))
  
  # Manipulate Longitude and Lattitude - Convert Degrees,minutes,seconds to decimal degrees 
  tempMapping[,latUpd:=sapply(LAT,findLoc)][,longUpd:=sapply(LON,findLoc)]
  tempMapping[,LatLong:=paste0(latUpd,":",longUpd)]
  tempMapping <- tempMapping[!duplicated(LatLong)] # get rid off stations with duplicated locations
  
  # Find Available Stations with their names and their location
  dataFileNames <- list.files(tempDownloadPath, pattern=".txt")
  dataFileNames <- dataFileNames[!dataFileNames %in% c("elements.txt", "sources.txt","stations.txt")]
  dataFileNamesIDs <- as.numeric(gsub(".txt","",
                                      gsub(paste0(linkMap[VarName==metVarID,ID],
                                                  "_STAID"),"",dataFileNames)
                                      )
                                 )
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
  tempStat <- list()
  tempDownloadPath <- linkMap[VarName == metVarId,downloadDatPath]
  dataFileNames <- list.files(tempDownloadPath, pattern=".txt")
  dataFileNames <- dataFileNames[!dataFileNames %in% 
                                   c("elements.txt", "sources.txt","stations.txt")]
  dataFileNamesMap <- data.table(FileName=dataFileNames)
  stationsToKeep <- data.table(Filename = stationsToKeep)
  stationsToKeep[, Filename := paste0(linkMap[VarName == metVarId, ID],"_STAID",
                                      str_pad(string = Filename,
                                              width = 6,
                                              side = "left",
                                              pad = "0"),".txt")]
  
  statToDownload <- dataFileNamesMap[FileName %in% stationsToKeep[,Filename], FileName]
  
  k <- 1
  mypb <- tkProgressBar(title ="Percentage Complete: 0%", min=0,
                        max=length(statToDownload), initial=0, width=400)
  
  for (tempFile_id in statToDownload){
    setTkProgressBar(mypb, k, title=paste0("Percentage Complete: ",
                                           round(k/length(statToDownload)*100,digits = 1),
                                           "% ","Processing Data Read..."))
    tempStat[[k]] <- data.table(read.table(paste0(tempDownloadPath,"/",tempFile_id)
                                           ,skip=20, sep=",",header=TRUE, stringsAsFactors=FALSE))
    
    tempStat[[k]][,DATE:=as.Date(as.character(DATE), format("%Y%m%d"))]
    tempStat[[k]][,Year:= year(DATE)]
    tempStat[[k]][,Month:= month(DATE)]
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
    ## Ncells   601905  32.2    1168576  62.5  1168576  62.5
    ## Vcells 44859168 342.3   90417030 689.9 88108531 672.3

A heuristic approach to impute missing values
---------------------------------------------

There are several approaches to deal with the problem of missing values. These methods refer to multiple imputation techiques, deleting records with missing values, replacing with mean or median etc.

In this exercise we impute maximum 5 records per month using the monthly mean. In cases where more than 5 records appear during a month, these records are excluded.

``` r
# Perform a data cleaning process in order to impute max 5 records per month
# Replace values -9999 with NA
allRes[RR == -9999, RR:= NA]

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
    ## Ncells   602804  32.2    1168576   62.5   1168576  62.5
    ## Vcells 57842650 441.4  136711214 1043.1 111956687 854.2

``` r
# Replace missing recods with mean 
allRes[, c("MonthlyMean","RR"):= lapply(.SD, as.numeric), .SDcols = c("MonthlyMean","RR")]

allRes[is.na(RR) & !is.na(CountNumNAs) & CountNumNAs <= 5, RR:= MonthlyMean]

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
allRes[is.na(Cons), Cons:= 0]
allRes[, Group := cumsum(Cons), by = STAID]

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

Feature engineering
-------------------

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
# periodTbl <- read_rds("./periodTbl.rds")
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
# allRes <- read_rds("./allRes.rds")
allRes <- merge(allRes, maxDuration[, !"Group", with=FALSE], all.x = T, by = "STAID")
allRes <- allRes[DATE %between% list(MinDate, MaxDate)]
```

### Rolling Mean

In this section we begin the feature transformation approach. First, we calculate the average daily series of the previous 30 and 60 available days for the daily rainfall, humidity and temperature.

``` r
# Compute Quarter indicator variable
allRes[, Quarter:= quarter(DATE)]

## Computation of rolling mean using as time window 30 days
# ---------------------------------------------------------

# Provide names of the variables to create
varsToCreate30 <- c("PrecipRollAverage30","HumidRollAverage30","TempRollAverage30")

# Provide list of the variables that will be used to compute rolling mean
varsToModify <- c("RR_DailyPrecipAmount", "RR_DailyHumid", "RR_DailyMeanTemp")

# Compute rolling mean using a time window of 30 days
allRes[, varsToCreate30 := lapply(.SD, rollmean, 30, fill = NA),.SDcols = varsToModify, by = STAID]

## Computation of rolling mean using as time window 60 days
# ---------------------------------------------------------

# Provide names of the variables to create
varsToCreate60 <- c("PrecipRollAverage60","HumidRollAverage60","TempRollAverage60")

# Provide list of the variables that will be used to compute rolling mean
varsToModify <- c("RR_DailyPrecipAmount", "RR_DailyHumid", "RR_DailyMeanTemp")

# Compute rolling mean using a time window of 60 days
# allRes[, varsToCreate60 := lapply(.SD, rollmean, 60, fill = NA),.SDcols = varsToModify, by = STAID]
```

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
allRes[, varsToCreateWeightRollMean:= lapply(.SD,
                                            roll_mean,
                                            n       = 15L,
                                            weights = customWeights,
                                            fill    = NA,
                                            align   = "right"),
    .SDcols = varsToModify,
    by=STAID
    ]
```

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
allRes[, varsToCreateWeightRollSD:= lapply(.SD,
                                            roll_sd,
                                            n       = 15L,
                                            weights = customWeights,
                                            fill    = NA,
                                            align   = "right"),
    .SDcols = varsToModify,
    by=STAID
    ]
```

### Rolling Quantile

``` r
## Computation of rolling quantile (90%) using as time window 15 days
# ---------------------------------------------------------

# Provide names of the variables to create
varsToCreateWeightRollQQ <- c("RainweightedRollQuantile15",
                              "TempweightedRollQuantile15",
                              "HumidweightedRollQuantile15")

# Provide list of the variables that will be used to compute the  quantile (90%)
varsToModify               <- c("RR_DailyPrecipAmount", "RR_DailyHumid", "RR_DailyMeanTemp")


# Compute quantile (90%) for the previous 15 days of each record per station
#allRes[, varsToCreateWeightRollQQ:= lapply(.SD,
#                                            runquantile,
#                                            k       = 15,
#                                            probs   = 0.9,
#                                            align   = "right"),
#    .SDcols = varsToModify,
#    by=STAID
#    ]
```
