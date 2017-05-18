Introduction to large data management using `data.table`<br>
================
Kostas Mammas, Statistical Programmer <br> mail <mammaskon@gmail.com> <br>
EarthBiAs2017, Rhodes Island, Greece

-   [Introduction](#introduction)
-   [Understanding the data structure](#understanding-the-data-structure)
-   [Lecture-1: Introduction to `data.table`](#lecture-1-introduction-to-data.table)
    -   [Data import](#data-import)
    -   [Create new variables](#create-new-variables)
    -   [Managing formats](#managing-formats)
    -   [Subsetting](#subsetting)
    -   [Group by](#group-by)
    -   [Working with `shift`](#working-with-shift)
    -   [Creating temporary variables](#creating-temporary-variables)
    -   [Special Symbols](#special-symbols)
        -   [`SD`](#sd)
        -   [`.N`](#n)
        -   [Exercise 1: Summary statistics](#exercise-1-summary-statistics)
    -   [Environmental indices with `data.table`](#environmental-indices-with-data.table)
        -   [Number of days with "extreme" rainfall events](#number-of-days-with-extreme-rainfall-events)
        -   [Maximum number of consecutive rainfall events](#maximum-number-of-consecutive-rainfall-events)
        -   [Exercise 2: Compute the maximum number of extreme consecutive rainfall events](#exercise-2-compute-the-maximum-number-of-extreme-consecutive-rainfall-events)
-   [Lecture 2: Visualization of environmental rainfall series](#lecture-2-visualization-of-environmental-rainfall-series)
    -   [Visualization of rainfall series](#visualization-of-rainfall-series)

Introduction
============

The present document works as a user manual of various techniques that can be followed in order to perform efficient data manipulation of environmental data using the `data.table` package.

Before we start you need to setup your working directory by following this [link](https://github.com/mammask/EarthBiAs2017/blob/master/setupR.md).

Understanding the data structure
================================

The dataset consists of 5 columns:

-   **STAID**: Station identifier
-   **SOUID**: Source identifier
-   **DATE** : Date YYYYMMDD
-   **RR** : Precipitation amount in 0.1 mm
-   **Q\_RR** : quality code for RR (0='valid'; 1='suspect'; 9='missing')

Lecture-1: Introduction to `data.table`
=======================================

Data import
-----------

``` r
# Load libraries
library(data.table)
# Set working directory
setwd("~/Documents/Summer_School_2017/EarthBiAs2017/")
# Read precipitation data
envDat <- readRDS("./data/spanishPrecipRecords.RDS")
# Convert dataset to DT
setDT(envDat)
# Obtain first six rows
head(envDat)
```

    ##    STAID SOUID     DATE  RR Q_RR
    ## 1:   229   709 19550101  35    0
    ## 2:   229   709 19550102 194    0
    ## 3:   229   709 19550103   0    0
    ## 4:   229   709 19550104 168    0
    ## 5:   229   709 19550105  61    0
    ## 6:   229   709 19550106   0    0

``` r
# Obtain column formats
str(envDat)
```

    ## Classes 'data.table' and 'data.frame':   3351644 obs. of  5 variables:
    ##  $ STAID: int  229 229 229 229 229 229 229 229 229 229 ...
    ##  $ SOUID: int  709 709 709 709 709 709 709 709 709 709 ...
    ##  $ DATE : int  19550101 19550102 19550103 19550104 19550105 19550106 19550107 19550108 19550109 19550110 ...
    ##  $ RR   : int  35 194 0 168 61 0 0 82 72 0 ...
    ##  $ Q_RR : int  0 0 0 0 0 0 0 0 0 0 ...
    ##  - attr(*, ".internal.selfref")=<externalptr>

Create new variables
--------------------

Managing formats
----------------

In the previous section we used the `str` function to obtain the dataset formats and it seems that the `DATE` column is a vector of integers. The following script converts `DATE` in date format (`as.Date`):

``` r
envDat[,DATE:=as.Date(as.character(DATE), format("%Y%m%d"))]
```

    ##          STAID SOUID       DATE    RR Q_RR
    ##       1:   229   709 1955-01-01    35    0
    ##       2:   229   709 1955-01-02   194    0
    ##       3:   229   709 1955-01-03     0    0
    ##       4:   229   709 1955-01-04   168    0
    ##       5:   229   709 1955-01-05    61    0
    ##      ---                                  
    ## 3351640: 11383 56288 2017-02-24 -9999    9
    ## 3351641: 11383 56288 2017-02-25 -9999    9
    ## 3351642: 11383 56288 2017-02-26 -9999    9
    ## 3351643: 11383 56288 2017-02-27 -9999    9
    ## 3351644: 11383 56288 2017-02-28 -9999    9

`:=` is used in order to create a new column or update an existing one.

Subsetting
----------

In this section, we describe how to select specific rows and columns of a dataset and also make computations based on the subsets:

``` r
# Select the first 3 columns
envDat[, .(STAID, SOUID, DATE)]
```

    ##          STAID SOUID       DATE
    ##       1:   229   709 1955-01-01
    ##       2:   229   709 1955-01-02
    ##       3:   229   709 1955-01-03
    ##       4:   229   709 1955-01-04
    ##       5:   229   709 1955-01-05
    ##      ---                       
    ## 3351640: 11383 56288 2017-02-24
    ## 3351641: 11383 56288 2017-02-25
    ## 3351642: 11383 56288 2017-02-26
    ## 3351643: 11383 56288 2017-02-27
    ## 3351644: 11383 56288 2017-02-28

``` r
# Select records where precipitation amount is equal to zero
envDat[RR == 0]
```

    ##          STAID SOUID       DATE RR Q_RR
    ##       1:   229   709 1955-01-03  0    0
    ##       2:   229   709 1955-01-06  0    0
    ##       3:   229   709 1955-01-07  0    0
    ##       4:   229   709 1955-01-10  0    0
    ##       5:   229   709 1955-01-12  0    0
    ##      ---                               
    ## 2293354: 11383 75568 2016-12-27  0    0
    ## 2293355: 11383 75568 2016-12-28  0    0
    ## 2293356: 11383 75568 2016-12-29  0    0
    ## 2293357: 11383 75568 2016-12-30  0    0
    ## 2293358: 11383 75568 2016-12-31  0    0

``` r
# Compute number of rows where precipitation amount is equal to zero
envDat[RR == 0, .N]
```

    ## [1] 2293358

``` r
# Select specific rows and columns
envDat[RR == 0, .(STAID, SOUID, DATE)]
```

    ##          STAID SOUID       DATE
    ##       1:   229   709 1955-01-03
    ##       2:   229   709 1955-01-06
    ##       3:   229   709 1955-01-07
    ##       4:   229   709 1955-01-10
    ##       5:   229   709 1955-01-12
    ##      ---                       
    ## 2293354: 11383 75568 2016-12-27
    ## 2293355: 11383 75568 2016-12-28
    ## 2293356: 11383 75568 2016-12-29
    ## 2293357: 11383 75568 2016-12-30
    ## 2293358: 11383 75568 2016-12-31

``` r
# Find number of records where Q_RR is equal to 9
envDat[Q_RR == 9, .N]
```

    ## [1] 260169

``` r
# Find number of records where Q_RR is equal to 0 or 1 and RR > 0 
envDat[Q_RR != 9 & RR >=0, .N]
```

    ## [1] 3091475

``` r
# Find number of stations with at least one missing record
envDat[Q_RR == 9, uniqueN(STAID)]
```

    ## [1] 172

Group by
--------

``` r
# Count the number of records by station
envDat[, .N, by = STAID]
```

    ##      STAID     N
    ##   1:   229 22736
    ##   2:   230 35520
    ##   3:   231 27484
    ##   4:   232 26023
    ##   5:   233 26388
    ##  ---            
    ## 196: 11346   425
    ## 197: 11347   425
    ## 198: 11348   425
    ## 199: 11382  3347
    ## 200: 11383  3347

``` r
# Count the number of records where precipitation amount is greater than 100 mm
# by station
envDat[RR >100, .N, by = STAID]
```

    ##      STAID    N
    ##   1:   229  956
    ##   2:   230 1236
    ##   3:   231 1206
    ##   4:   232 2979
    ##   5:   233  676
    ##  ---           
    ## 196: 11346   23
    ## 197: 11347   17
    ## 198: 11348   14
    ## 199: 11382  268
    ## 200: 11383  170

``` r
# Count the number of records where precipitation amount is greater than 100 mm
# by station and available year
envDat[RR >100, .N, by = list(STAID,year(DATE))]
```

    ##       STAID year  N
    ##    1:   229 1955 19
    ##    2:   229 1956 14
    ##    3:   229 1957 10
    ##    4:   229 1958 16
    ##    5:   229 1959 16
    ##   ---              
    ## 8631: 11383 2012 14
    ## 8632: 11383 2013 23
    ## 8633: 11383 2014 23
    ## 8634: 11383 2015 19
    ## 8635: 11383 2016 18

``` r
# Find the annual precipitation amount by station where missing records are omitted
envDat[Q_RR !=9, list(N = sum(RR)), by = list(STAID,year(DATE))]
```

    ##       STAID year    N
    ##    1:   229 1955 5735
    ##    2:   229 1956 5274
    ##    3:   229 1957 4121
    ##    4:   229 1958 4666
    ##    5:   229 1959 4552
    ##   ---                
    ## 8687: 11383 2012 4024
    ## 8688: 11383 2013 7336
    ## 8689: 11383 2014 7615
    ## 8690: 11383 2015 5092
    ## 8691: 11383 2016 5911

``` r
# Perform more than one computations
envDat[Q_RR !=9, list(Total = sum(RR), Mean  = mean(RR)), by = list(STAID,year(DATE))]
```

    ##       STAID year Total     Mean
    ##    1:   229 1955  5735 15.71233
    ##    2:   229 1956  5274 14.40984
    ##    3:   229 1957  4121 11.29041
    ##    4:   229 1958  4666 12.78356
    ##    5:   229 1959  4552 12.47123
    ##   ---                          
    ## 8687: 11383 2012  4024 10.99454
    ## 8688: 11383 2013  7336 20.09863
    ## 8689: 11383 2014  7615 20.86301
    ## 8690: 11383 2015  5092 13.95068
    ## 8691: 11383 2016  5911 16.15027

Working with `shift`
--------------------

You can obtain the next or the previous rainfall record by using the `shift` function:

``` r
# Order rainfall records by station and date
envDat <- envDat[order(STAID,DATE)]
# Obtain DATE lag(1) for each station and fill missing values with -9999
envDat[, shift(x = DATE, fill = NA, n = 1, type = "lag"), by = STAID]
# Obtain RR lag(1) for each station and fill missing values with -9999
envDat[, shift(x = RR, fill = -9999, n = 1, type = "lag"), by = STAID]
# Obtain RR lag(2) for each station and fill missing values with -9999
envDat[, shift(x = RR, fill = -9999, n = 2, type = "lag"), by = STAID]
# Create new columns of lag(1,2) for each station and fill onobserved values
# with -9999
envDat[,`:=` (lag1 = shift(x = RR, fill = -9999, n = 1, type = "lag"),
              lag2 = shift(x = RR, fill = -9999, n = 2, type = "lag")),
       by = STAID]
```

Creating temporary variables
----------------------------

With `data.table` you can create temporary variables and based on their values you can further compute variables in just one step. In the following example, we create a lag(1) of the daily precipitation record per station and then we compute the mean and minimum precipitation by omitting missing records:

``` r
# Create a temporary variable of lag1 and compute the mean/min of lag1
envDat[Q_RR !=9, { lag1 =  shift(x = RR, fill = NA, n = 1, type = "lag")
                   list( MeanLag1 = mean(lag1, na.rm = T),
                         MinLag1  = min(lag1, na.rm = T))},
       by = STAID]
```

    ##      STAID MeanLag1 MinLag1
    ##   1:   229 12.98324       0
    ##   2:   230 11.92158       0
    ##   3:   231 14.87026       0
    ##   4:   232 36.25256       0
    ##   5:   233 10.39550       0
    ##  ---                       
    ## 196: 11346 20.47945       0
    ## 197: 11347 18.57419       0
    ## 198: 11348 14.28493       0
    ## 199: 11382 26.30940       0
    ## 200: 11383 16.11104       0

Special Symbols
---------------

### `SD`

`SD` is one of `data.table`'s special symbols and contains a subset of columns.

``` r
# Return all columns and all rows
envDat[, .SD]
```

    ##          STAID SOUID       DATE    RR Q_RR
    ##       1:   229   709 1955-01-01    35    0
    ##       2:   229   709 1955-01-02   194    0
    ##       3:   229   709 1955-01-03     0    0
    ##       4:   229   709 1955-01-04   168    0
    ##       5:   229   709 1955-01-05    61    0
    ##      ---                                  
    ## 3351640: 11383 56288 2017-02-24 -9999    9
    ## 3351641: 11383 56288 2017-02-25 -9999    9
    ## 3351642: 11383 56288 2017-02-26 -9999    9
    ## 3351643: 11383 56288 2017-02-27 -9999    9
    ## 3351644: 11383 56288 2017-02-28 -9999    9

``` r
# Return all columns and first row
envDat[, .SD[1]]
```

    ##    STAID SOUID       DATE RR Q_RR
    ## 1:   229   709 1955-01-01 35    0

``` r
# Return all columns and the first record of each meteorological station
envDat[, .SD[1], by = STAID]
```

    ##      STAID SOUID       DATE    RR Q_RR
    ##   1:   229   709 1955-01-01    35    0
    ##   2:   230   710 1920-01-01     0    0
    ##   3:   231   713 1942-01-01 -9999    9
    ##   4:   232   716 1946-01-01    10    0
    ##   5:   233   719 1945-01-01     0    0
    ##  ---                                  
    ## 196: 11346 73105 2016-01-01     0    0
    ## 197: 11347 73114 2016-01-01 -9999    9
    ## 198: 11348 73123 2016-01-01     0    0
    ## 199: 11382 56405 2008-01-01     0    0
    ## 200: 11383 56288 2008-01-01     0    0

``` r
# Return all columns and the first non-missing record of each meteorological station
envDat[Q_RR != 9, .SD[1], by = STAID]
```

    ##      STAID SOUID       DATE RR Q_RR
    ##   1:   229   709 1955-01-01 35    0
    ##   2:   230   710 1920-01-01  0    0
    ##   3:   231   713 1942-05-01  9    0
    ##   4:   232   716 1946-01-01 10    0
    ##   5:   233   719 1945-01-01  0    0
    ##  ---                               
    ## 196: 11346 73105 2016-01-01  0    0
    ## 197: 11347 73114 2016-01-04  2    0
    ## 198: 11348 73123 2016-01-01  0    0
    ## 199: 11382 56405 2008-01-01  0    0
    ## 200: 11383 56288 2008-01-01  0    0

``` r
# Return specific columns (station id, date and rainfall record)
envDat[,.SD, .SDcols = c("STAID","DATE", "RR")]
```

    ##          STAID       DATE    RR
    ##       1:   229 1955-01-01    35
    ##       2:   229 1955-01-02   194
    ##       3:   229 1955-01-03     0
    ##       4:   229 1955-01-04   168
    ##       5:   229 1955-01-05    61
    ##      ---                       
    ## 3351640: 11383 2017-02-24 -9999
    ## 3351641: 11383 2017-02-25 -9999
    ## 3351642: 11383 2017-02-26 -9999
    ## 3351643: 11383 2017-02-27 -9999
    ## 3351644: 11383 2017-02-28 -9999

It is very convenient to perform dynamic computations across many variables:

``` r
# Perform dynamic computations accross variables
envDat[, lapply(.SD, min), .SDcols = c("RR")]
```

    ##       RR
    ## 1: -9999

``` r
# Perform dynamic computations accross variables and by station
envDat[, lapply(.SD, min), .SDcols = c("RR"), by = "STAID"]
```

    ##      STAID    RR
    ##   1:   229     0
    ##   2:   230 -9999
    ##   3:   231 -9999
    ##   4:   232     0
    ##   5:   233     0
    ##  ---            
    ## 196: 11346 -9999
    ## 197: 11347 -9999
    ## 198: 11348 -9999
    ## 199: 11382 -9999
    ## 200: 11383 -9999

``` r
# Perform dynamic computations accross variables and by station
# where rainfall records are non missing
envDat[Q_RR !=9, lapply(.SD, min), .SDcols = c("RR"), by = "STAID"]
```

    ##      STAID RR
    ##   1:   229  0
    ##   2:   230  0
    ##   3:   231  0
    ##   4:   232  0
    ##   5:   233  0
    ##  ---         
    ## 196: 11346  0
    ## 197: 11347  0
    ## 198: 11348  0
    ## 199: 11382  0
    ## 200: 11383  0

``` r
# More variables can be added in SD
envDat[Q_RR !=9, lapply(.SD, min), .SDcols = c("RR", "Q_RR"), by = "STAID"]
```

    ##      STAID RR Q_RR
    ##   1:   229  0    0
    ##   2:   230  0    0
    ##   3:   231  0    0
    ##   4:   232  0    0
    ##   5:   233  0    0
    ##  ---              
    ## 196: 11346  0    0
    ## 197: 11347  0    0
    ## 198: 11348  0    0
    ## 199: 11382  0    0
    ## 200: 11383  0    0

### `.N`

`.N` is a special in-built variable that holds the number of observations in the current group. When we group by`origin`, `.N` returns the number of rows of the dataset:

``` r
# Return the number of records per station
envDat[, .N, by = "STAID"]
# Create a counter variable per station
envDat[, 1:.N, by = "STAID"]
```

`SD` can be combined with `.N` to access specific rows of the dataset:

``` r
# Return last record of each one of the three variables
envDat[,.SD[.N], .SDcols = c("STAID","DATE", "RR")]
# Return all but the last record for the selected columns
envDat[,.SD[1:(.N-1)], .SDcols = c("STAID","DATE", "RR")]
# Return all but the last record for the selected columns by station
envDat[,.SD[1:(.N-1)], .SDcols = c("STAID","DATE", "RR"), by = "STAID"]
```

### Exercise 1: Summary statistics

As a first task you will have to pick randomly 10 meteorological stations and compute the following metrics:

-   Mean, Min, Max, Median and Total rainfall amount (missing records are omitted)
-   Compute the number of missing records per station
-   Which is the month with the highest number of missing values per station?

Environmental indices with `data.table`
---------------------------------------

### Number of days with "extreme" rainfall events

Extreme rainfall event is defined as a daily rainfall record exceeding a specific rainfall amount. In this case, we calculate the probability distribution of the daily rainfall series and we define extreme records those which exceed the 90% of the values.

``` r
# Calculate extreme rainfall events
# - Calculate the 90% of the values of the probability 
#   distribution of daily rainfall
# - Find the records who exceed this threshold
# - Count the records who exceed this threshold
# - Make this computation for each station and each available year
envDat[Q_RR != 9, {extrVal     = quantile(RR, probs = 0.9)[[1]]
                   ExtrEv      = RR[RR > extrVal]
                   list(N = length(ExtrEv))
                   },
       by = list(STAID, year(DATE))]
```

    ##       STAID year  N
    ##    1:   229 1955 36
    ##    2:   229 1956 36
    ##    3:   229 1957 37
    ##    4:   229 1958 36
    ##    5:   229 1959 36
    ##   ---              
    ## 8687: 11383 2012 35
    ## 8688: 11383 2013 37
    ## 8689: 11383 2014 37
    ## 8690: 11383 2015 37
    ## 8691: 11383 2016 36

In the previous example we included also the days with no rainfall amount. We can calculate the 90% of the probability distribution for the days with rainfall amount greater than zero:

``` r
# Calculate extreme rainfall events
# - Calculate the 90% of the values of the probability 
#   distribution of daily rainfall
# - Find the records who exceed this threshold
# - Count the records who exceed this threshold
# - Make this computation for each station and each available year
envDat[Q_RR != 9, {extrVal     = quantile(RR[RR>0], probs = 0.9)[[1]]
                   ExtrEv      = RR[RR > extrVal]
                   list(N = length(ExtrEv))
                   },
       by = list(STAID, year(DATE))]
```

    ##       STAID year  N
    ##    1:   229 1955  9
    ##    2:   229 1956  7
    ##    3:   229 1957  8
    ##    4:   229 1958  9
    ##    5:   229 1959  9
    ##   ---              
    ## 8687: 11383 2012  9
    ## 8688: 11383 2013 12
    ## 8689: 11383 2014 13
    ## 8690: 11383 2015  9
    ## 8691: 11383 2016 10

### Maximum number of consecutive rainfall events

In the following example, we compute the maxmimum number of consecutive rainfall days for each station and available year.

``` r
# Compute maximum number of consecutive daily rainfall events per station
# Temporary variables: idx        - indexing days with rainfall
#                      diff       - find if the current day and the next day are days with rainfall
#                      lagdiff    - shift series on position
#                      startPoint - create a starting point
envDat[, {idx        = 1*(RR>0);
          diff       = shift(x = idx, fill = 0, type = "lead", n=1) - idx;
          lagdiff    = c(0,diff[-.N])
          startPoint = 1*(lagdiff<0)
          list(DATE  = DATE,
               RR    = RR,
               group =cumsum(startPoint))},
          by = list(STAID, year(DATE))
      ][RR != 0, .N, by = list(STAID, year, group)][, list(Max = max(N)),
                                                                by = list(STAID, year)]
```

    ##       STAID year Max
    ##    1:   229 1955  10
    ##    2:   229 1956   9
    ##    3:   229 1957   6
    ##    4:   229 1958  13
    ##    5:   229 1959   6
    ##   ---               
    ## 9367: 11383 2013  10
    ## 9368: 11383 2014   7
    ## 9369: 11383 2015   5
    ## 9370: 11383 2016   6
    ## 9371: 11383 2017  59

This example can be easily extended so as to compute the number of consecutive days per station, year and month.

``` r
# Compute maximum number of consecutive daily rainfall events per station
# Temporary variables: idx        - indexing days with rainfall
#                      diff       - find if the current day and the next day are days with rainfall
#                      lagdiff    - shift series one position
#                      startPoint - create a starting point
envDat[, {idx        = 1*(RR>0);
          diff       = shift(x = idx, fill = 0, type = "lead", n=1) - idx;
          lagdiff    = c(0,diff[-.N])
          startPoint = 1*(lagdiff<0)
          list(DATE  = DATE,
               RR    = RR,
               group =cumsum(startPoint))},
          by = list(STAID, year(DATE), month(DATE))
      ][RR > 0, .N, by = list(STAID, year, month, group)][, list(Max = max(N)),
                                                                by = list(STAID, year, month)]
```

    ##        STAID year month Max
    ##     1:   229 1955     1   6
    ##     2:   229 1955     2   5
    ##     3:   229 1955     3   3
    ##     4:   229 1955     4   1
    ##     5:   229 1955     5   4
    ##    ---                     
    ## 95194: 11383 2016     8   1
    ## 95195: 11383 2016     9   2
    ## 95196: 11383 2016    10   2
    ## 95197: 11383 2016    11   6
    ## 95198: 11383 2016    12   1

Also, this example can be easily extended in order to compute the maximum number of consecutive drought days.

### Exercise 2: Compute the maximum number of extreme consecutive rainfall events

You will need to count the maximium number of consecutive extreme rainfall events by station and by year considering that an extreme rainfall event is a record with value greater than the 90% of the distribution of daily rainfall of each station and year.

Lecture 2: Visualization of environmental rainfall series
=========================================================

Visualization of rainfall series
--------------------------------

In the following example we compute the annual rainfall amount for a specific meteorological station:

``` r
# Load dygraphs
library(dygraphs)
statID    <- envDat[,unique(STAID)][1]
annualSer <- envDat[STAID == statID & Q_RR != 9, list(N = sum(RR)), by = year(DATE)]
# Prodice interactive plot of annual rainfall series
dygraph(annualSer, main = paste0("Annual rainfall series of station: ",statID)) %>%
  dyAxis("y", label = "Rainfall amount (mm)") %>% dyAxis("x", label = "Year")
```

<<<<<<< HEAD
=======
    ## PhantomJS not found. You can install it with webshot::install_phantomjs(). If it is installed, please make sure the phantomjs executable can be found via the PATH variable.

<!--html_preserve-->

<script type="application/json" data-for="htmlwidget-9d9923b83d7416c92d8d">{"x":{"attrs":{"axes":{"x":{"pixelsPerLabel":60},"y":[]},"title":"Annual rainfall series of station: 229","labels":["year","N"],"legend":"auto","retainDateWindow":false,"ylabel":"Rainfall amount (mm)","xlabel":"Year"},"annotations":[],"shadings":[],"events":[],"format":"numeric","data":[[1955,1956,1957,1958,1959,1960,1961,1962,1963,1964,1965,1966,1967,1968,1969,1970,1971,1972,1973,1974,1975,1976,1977,1978,1979,1980,1981,1982,1983,1984,1985,1986,1987,1988,1989,1990,1991,1992,1993,1994,1995,1996,1997,1998,1999,2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017],[5735,5274,4121,4666,4552,7180,5403,5991,7171,3717,5538,5265,4561,4907,7322,4301,4825,5405,2804,2743,4497,6433,5510,5840,7194,3540,3681,3086,4686,5124,4262,3985,5414,4441,7505,3085,3028,3873,4047,3269,4140,6352,7369,3341,3866,5640,4911,4615,4761,3281,2288,4521,3148,4310,4360,7743,4766,3176,5124,4589,3093,4483,1316]]},"evals":[],"jsHooks":[]}</script>
<!--/html_preserve-->
>>>>>>> 2549fc2665737742fa55fb74f75697d2278c6410
We can add more features in the previous plot:

``` r
# Produce interactive plot of annual rainfall series
dygraph(annualSer, main = paste0("Annual rainfall series of station: ",statID)) %>%
  dyAxis("y", label = "Rainfall amount (mm)") %>% dyAxis("x", label = "Year") %>% 
  dyRangeSelector() %>% dyOptions(fillGraph = TRUE, fillAlpha = 0.4)
```

<<<<<<< HEAD
=======
<!--html_preserve-->

<script type="application/json" data-for="htmlwidget-1ee469ea86bfa305804e">{"x":{"attrs":{"axes":{"x":{"pixelsPerLabel":60,"drawAxis":true},"y":{"drawAxis":true}},"title":"Annual rainfall series of station: 229","labels":["year","N"],"legend":"auto","retainDateWindow":false,"ylabel":"Rainfall amount (mm)","xlabel":"Year","showRangeSelector":true,"rangeSelectorHeight":40,"rangeSelectorPlotFillColor":" #A7B1C4","rangeSelectorPlotStrokeColor":"#808FAB","interactionModel":"Dygraph.Interaction.defaultModel","stackedGraph":false,"fillGraph":true,"fillAlpha":0.4,"stepPlot":false,"drawPoints":false,"pointSize":1,"drawGapEdgePoints":false,"connectSeparatedPoints":false,"strokeWidth":1,"strokeBorderColor":"white","colorValue":0.5,"colorSaturation":1,"includeZero":false,"drawAxesAtZero":false,"logscale":false,"axisTickSize":3,"axisLineColor":"black","axisLineWidth":0.3,"axisLabelColor":"black","axisLabelFontSize":14,"axisLabelWidth":60,"drawGrid":true,"gridLineWidth":0.3,"rightGap":5,"digitsAfterDecimal":2,"labelsKMB":false,"labelsKMG2":false,"labelsUTC":false,"maxNumberWidth":6,"animatedZooms":false,"mobileDisableYTouch":true},"annotations":[],"shadings":[],"events":[],"format":"numeric","data":[[1955,1956,1957,1958,1959,1960,1961,1962,1963,1964,1965,1966,1967,1968,1969,1970,1971,1972,1973,1974,1975,1976,1977,1978,1979,1980,1981,1982,1983,1984,1985,1986,1987,1988,1989,1990,1991,1992,1993,1994,1995,1996,1997,1998,1999,2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017],[5735,5274,4121,4666,4552,7180,5403,5991,7171,3717,5538,5265,4561,4907,7322,4301,4825,5405,2804,2743,4497,6433,5510,5840,7194,3540,3681,3086,4686,5124,4262,3985,5414,4441,7505,3085,3028,3873,4047,3269,4140,6352,7369,3341,3866,5640,4911,4615,4761,3281,2288,4521,3148,4310,4360,7743,4766,3176,5124,4589,3093,4483,1316]],"fixedtz":false,"tzone":""},"evals":["attrs.interactionModel"],"jsHooks":[]}</script>
<!--/html_preserve-->
>>>>>>> 2549fc2665737742fa55fb74f75697d2278c6410
In the following example we will compute a chart for each meteorological station using `data.table`:

``` r
# Function to produce plot of annual rainfall based on the station ID, year and rainfall amount
annualPlot <- function(year, N, ID){
  
  # function name: annualPlot
  #       purpose: to create annual rainfall series plots for each meteorological station
  #        inputs: year   - a vector with the available years
  #                N      - a vector with the annual rainfall series
  #                ID     - the station ID
  metDat <- data.table(year, N)
  p <- dygraph(metDat, main = paste0("Annual rainfall series of station: ",ID)) %>%
        dyAxis("y", label = "Rainfall amount (mm)") %>% dyAxis("x", label = "Year") %>% 
        dyRangeSelector() %>% dyOptions(fillGraph = TRUE, fillAlpha = 0.4)
  
  return(p)
}

# Produce annual rainfall series
anRainfall <- envDat[Q_RR != 9, list(N = sum(RR)), by = list(STAID, year(DATE))]
# Produce all the available plots
anRainfall[, list(Plot = list(annualPlot(year, N, STAID))), by = STAID]
```
<<<<<<< HEAD
=======

    ##      STAID       Plot
    ##   1:   229 <dygraphs>
    ##   2:   230 <dygraphs>
    ##   3:   231 <dygraphs>
    ##   4:   232 <dygraphs>
    ##   5:   233 <dygraphs>
    ##  ---                 
    ## 196: 11346 <dygraphs>
    ## 197: 11347 <dygraphs>
    ## 198: 11348 <dygraphs>
    ## 199: 11382 <dygraphs>
    ## 200: 11383 <dygraphs>
>>>>>>> 2549fc2665737742fa55fb74f75697d2278c6410
