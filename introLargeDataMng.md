Introduction to large data management using `data.table` <br>
================
Kostas Mammas, Statistical Programmer <br> mail <mammaskon@gmail.com> <br>
EarthBiAs2017, Rhodes Island, Greece

-   [Introduction](#introduction)
-   [Understanding the data structure](#understanding-the-data-structure)
-   [Introduction to `data.table`](#introduction-to-data.table)
    -   [Data import](#data-import)
    -   [Create new variables](#create-new-variables)
    -   [Managing formats](#managing-formats)
    -   [Subsetting](#subsetting)
    -   [Group by](#group-by)
    -   [Working with `shift`](#working-with-shift)
    -   [Creating temporary variables](#creating-temporary-variables)
    -   [Special Symbols](#special-symbols)
        -   [`SD`](#sd)
    -   [Using custom functions in `data.table`](#using-custom-functions-in-data.table)
-   [Calculation of environmental indices](#calculation-of-environmental-indices)
    -   [SPI-(12) Index](#spi-12-index)
    -   [Visualizing SPI index](#visualizing-spi-index)

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

Introduction to `data.table`
============================

Data import
-----------

``` r
# Load libraries
library(data.table)
# Set working directory
setwd("~/Documents/Summer_School_2017/setupWork")
# Read precipitation data
envDat <- readRDS("./spanishPrecipRecords.RDS")
# Convert dataset to DT
setDT(envDat)
# Obtain first six rows
head(envDat)
# Obtain column formats
str(envDat)
```

Create new variables
--------------------

Managing formats
----------------

In the previous section we used the `str` function to obtain the dataset formats and it seems that the `DATE` column is a vector of integers. The following script converts `DATE` in date format (`as.Date`):

``` r
envDat[,DATE:=as.Date(as.character(DATE), format("%Y%m%d"))]
```

`:=` is used in order to create a new column or update an existing one.

Subsetting
----------

In this section, we describe how to select specific rows and columns of a dataset and also make computations based on the subsets:

``` r
# Select the first 3 columns
envDat[, .(STAID, SOUID, DATE)]
# Select records where precipitation amount is equal to zero
envDat[RR == 0]
# Compute number of rows where precipitation amount is equal to zero
envDat[RR == 0, .N]
# Select specific rows and columns
envDat[RR == 0, .(STAID, SOUID, DATE)]
# Find number of records where Q_RR is equal to 9
envDat[Q_RR == 9, .N]
# Find number of records where Q_RR is equal to 0 or 1 and RR > 0 
envDat[Q_RR != 9 & RR >=0, .N]
# Find number of stations with at least one missing record
envDat[Q_RR == 9, uniqueN(STAID)]
```

Group by
--------

``` r
# Count the number of records by station
envDat[, .N, by = STAID]
# Count the number of records where precipitation amount is greater than 100 mm
# by station
envDat[RR >100, .N, by = STAID]
# Count the number of records where precipitation amount is greater than 100 mm
# by station and available year
envDat[RR >100, .N, by = list(STAID,year(DATE))]
# Find the annual precipitation amount by station where missing records are omitted
envDat[Q_RR !=9, list(N = sum(RR)), by = list(STAID,year(DATE))]
# Perform more than one computations
envDat[Q_RR !=9, list(Total = sum(RR), Mean  = mean(RR)), by = list(STAID,year(DATE))]
```

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

Special Symbols
---------------

### `SD`

`SD` is one of `data.table`'s special symbols and contains a subset of columns.

``` r
# Return all columns and all rows
envDat[, .SD]
# Return all columns and first row
envDat[, .SD[1]]
# Return all columns and the first record of each meteorological station
envDat[, .SD[1], by = STAID]
# Return all columns and the first non-missing record of each meteorological station
envDat[Q_RR != 9, .SD[1], by = STAID]
# Return specific columns (station id, date and rainfall record)
envDat[,.SD, .SDcols = c("STAID","DATE", "RR")]
```

It is very convenient to perform dynamic computations accross many variables:

``` r
# Perform dynamic computations accross variables
envDat[, lapply(.SD, min), .SDcols = c("RR")]
# Perform dynamic computations accross variables and by station
envDat[, lapply(.SD, min), .SDcols = c("RR"), by = "STAID"]
# Perform dynamic computations accross variables and by station
# where rainfall records are non missing
envDat[Q_RR !=9, lapply(.SD, min), .SDcols = c("RR"), by = "STAID"]
# More variables can be added in SD
envDat[Q_RR !=9, lapply(.SD, min), .SDcols = c("RR", "Q_RR"), by = "STAID"]
```

Using custom functions in `data.table`
--------------------------------------

Calculation of environmental indices
====================================

SPI-(12) Index
--------------

Visualizing SPI index
---------------------
