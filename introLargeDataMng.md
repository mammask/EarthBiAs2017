Introduction to large data management using `data.table` <br>
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
    -   [Creating environmental indices with `data.table`](#creating-environmental-indices-with-data.table)
        -   [Number of days with "extreme" rainfall events](#number-of-days-with-extreme-rainfall-events)

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

It is very convenient to perform dynamic computations accross many variables:

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

`.N` is an integer, length 1, containing the number of rows in the group. The column that is named as N and not as .NL

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

Exercise 1: Summary statistics
------------------------------

As a first task you will have to pick randomly 10 meteorological stations and compute the following metrics:

-   Mean, Min, Max, Median and Total rainfall amount (missing records are omitted)
-   Compute the number of missing records per station
-   Which is the month with the highest number of missing values per station?

Creating environmental indices with `data.table`
------------------------------------------------

### Number of days with "extreme" rainfall events

Extreme rainfall event is defined a daily rainfall record that exceeds a specific rainfall amount. In this case, we calculate the probability distribution of the daily rainfall series and we define extreme records those who exceed the 90% of the values.
