Big data analysis using `sparklyr` <br>
================
Kostas Mammas, Statistical Programmer <br> mail: <mammaskon@gmail.com> <br>
EarthBiAs2017, Rhodes Island, Greece

-   [Introduction to `sparklyr`](#introduction-to-sparklyr)
-   [What is the benefit of using `sparklyr`?](#what-is-the-benefit-of-using-sparklyr)
-   [Installation - Local Remote Apache Spark cluster](#installation---local-remote-apache-spark-cluster)
-   [`sdf_` family functions](#sdf_-family-functions)
    -   [`sdf_copy_to`](#sdf_copy_to)
    -   [`sdf_num_partitions`](#sdf_num_partitions)
    -   [`sdf_pivot`](#sdf_pivot)
-   [Date manipulation on **spark** using **HIVE-SQL**](#date-manipulation-on-spark-using-hive-sql)
    -   [`sdf_quantile`](#sdf_quantile)
    -   [`sdf_sort`](#sdf_sort)
-   [`ft_` family functions](#ft_-family-functions)
    -   [`ft_binarizer`](#ft_binarizer)
    -   [`ft_bucketizer`](#ft_bucketizer)
-   [Environmental rainfall indices using `sparklyr`](#environmental-rainfall-indices-using-sparklyr)
    -   [Annual rainfall amount](#annual-rainfall-amount)
        -   [Visualize annual rainfall amount](#visualize-annual-rainfall-amount)
        -   [Exercise 3 - Number of days with "extreme" rainfall events](#exercise-3---number-of-days-with-extreme-rainfall-events)
    -   [Number of consecutive rainfall events for all European stations](#number-of-consecutive-rainfall-events-for-all-european-stations)
    -   [Number of extreme consecutive rainfall events for all European stations](#number-of-extreme-consecutive-rainfall-events-for-all-european-stations)
-   [Useful functions](#useful-functions)
    -   [Read Spark DataFrame](#read-spark-dataframe)

Introduction to `sparklyr`
--------------------------

**Apache Spark** is an open source parallel processing framework for running large-scale data analytics applications across clustered computers. It can handle both batch and real-time analytics and data processing workloads.

**sparklyr** is an R interface to Apache Spark, a fast and general engine for big data processing. This package supports connecting to local and remote Apache Spark clusters, provides a **dplyr** compatible back-end, and provides an interface to Spark's built-in machine learning algorithms

What is the benefit of using `sparklyr`?
----------------------------------------

Installation - Local Remote Apache Spark cluster
------------------------------------------------

As a first step you need to install **sparklyr** package from CRAN as follows:

``` r
# Install sparklyr package
install.packages("sparklyr")
```

You need to install also **spark** to set up a Local Remote Apache Spark cluster:

``` r
# Load sparklyr
library("sparklyr")
# Obtain available versions of spark
allVer <- spark_available_versions()
# Obtain latest version
latVer <- allVer[nrow(allVer),"spark"]
# Install latest version of spark
spark_install(version = latVer)
```

`sdf_` family functions
-----------------------

The family of functions prefixed with sdf\_ generally access the Scala Spark DataFrame API directly, as opposed to the dplyr interface which uses Spark SQL. These functions will ’force’ any pending SQL in a dplyr pipeline, such that the resulting tbl\_spark object returned will no longer have the attached ’lazy’ SQL operations

### `sdf_copy_to`

`sdf_copy_to`: Copy an object into Spark, and return an R object wrapping the copied object (typically, a Spark DataFrame).

``` r
# Load sparklyr
library(sparklyr)
# Connect to Local Remote Apache Spark cluster
sc      <- spark_connect(master = "local")
```

    ## * Using Spark: 2.0.2

``` r
# Load environmental data
envData <- readRDS("/Users/mammask/Documents/Summer_School_2017/EarthBiAs2017/data/spanishPrecipRecords.RDS")
# Copy R object into spark
tbl <- sparklyr::sdf_copy_to(sc          = sc,
                             x           = envData,
                             name        = "envSparlTbl",
                             memory      = TRUE,
                             repartition = 0L,
                             overwrite   = TRUE)
tbl
```

    ## # Source:   table<envSparlTbl> [?? x 5]
    ## # Database: spark_connection
    ##    STAID SOUID     DATE    RR  Q_RR
    ##    <int> <int>    <int> <int> <int>
    ##  1   229   709 19550101    35     0
    ##  2   229   709 19550102   194     0
    ##  3   229   709 19550103     0     0
    ##  4   229   709 19550104   168     0
    ##  5   229   709 19550105    61     0
    ##  6   229   709 19550106     0     0
    ##  7   229   709 19550107     0     0
    ##  8   229   709 19550108    82     0
    ##  9   229   709 19550109    72     0
    ## 10   229   709 19550110     0     0
    ## # ... with 3.352e+06 more rows

### `sdf_num_partitions`

Gets number of partitions of a Spark DataFrame:

``` r
# Obtain number of partitions
numPart <- sparklyr::sdf_num_partitions(tbl)
numPart
```

    ## [1] 4

### `sdf_pivot`

Perform **reshape2::dcast** using Spark DataFrame:

``` r
# Compute the number of of missing and non-missing rainfall records per station
tbl %>% dplyr::group_by(STAID, Q_RR) %>% dplyr::summarise(N = n()) %>%
  # Create a pivot table
  sparklyr::sdf_pivot(STAID ~ Q_RR, list(N = "sum"))
```

    ## # Source:   table<sparklyr_tmp_15e743c330ae> [?? x 4]
    ## # Database: spark_connection
    ##    STAID   `0`   `1`   `9`
    ##    <int> <dbl> <dbl> <dbl>
    ##  1   416 34540   NaN   980
    ##  2   418 35476   NaN    44
    ##  3   455 27152   NaN   485
    ##  4  1396 24197   NaN   NaN
    ##  5  2969 31763   NaN  2236
    ##  6  3903 16481   NaN    77
    ##  7  3913 16192   NaN   NaN
    ##  8  3960 13420   NaN     3
    ##  9 11026  3212   NaN   135
    ## 10 11033  3288   NaN    59
    ## # ... with 190 more rows

Date manipulation on **spark** using **HIVE-SQL**
-------------------------------------------------

The current version of `sparklyr: 0.6.0` does not allow date manipulation using `dplyr`. In our case we can directly modify date using native **HIVE-SQL** functions. The following example converts date from integer format to date:

``` r
library(DBI)
# Perform date manipulation on Spark using HIVE-SQL 
# (HIVE does not allow direct table update so we create a new table and drop the old one)

# Drop HIVE table if exists
dbExecute(sc, "DROP TABLE IF EXISTS envSparlTblUpd")
```

    ## [1] 0

``` r
# Create hive table with updated column
dbExecute(sc, "CREATE TABLE  envSparlTblUpd AS
                (SELECT STAID,
                        SOUID,
                        date_format(CONCAT(SUBSTR(DATE,1,4),
                                    '-',
                                    SUBSTR(DATE,5,2),
                                    '-',
                                    SUBSTR(DATE,7,2)), 'yyyy-MM-dd') AS DATE,
                                    RR,
                                    Q_RR
                        FROM envSparlTbl
                )
                "
          )
```

    ## [1] 0

``` r
# Drop old table
dbExecute(sc, "DROP TABLE IF EXISTS envSparlTbl")
```

    ## [1] 0

``` r
# Read Spark DataFrame
tbl <- spark_read_table(sc = sc, name = "envSparlTblUpd")
```

### `sdf_quantile`

Compute the approximate quantiles for a continuous variable to some relative error. In the following example we compute the quantiles of the daily rainfall amount for a specific station:

``` r
# Filters station 229
tbl %>% dplyr::filter(staid == 229 & rr != -9999) %>% dplyr::group_by(staid) %>%
  # Compute quantile
  sparklyr::sdf_quantile("rr", probabilities = c(0, 0.25, 0.5, 0.75, 0.90,  1))
```

    ##   0%  25%  50%  75%  90% 100% 
    ##    0    0    0    0   38 1191

### `sdf_sort`

Sort a Spark DataFrame by one or more columns, with each column sorted in ascending order.

``` r
tbl %>% sparklyr::sdf_sort(columns = c("staid","date"))
```

    ## # Source:   table<sparklyr_tmp_15e73a686f0e> [?? x 5]
    ## # Database: spark_connection
    ##    staid souid       date    rr  q_rr
    ##    <int> <int>      <chr> <int> <int>
    ##  1   229   709 1955-01-01    35     0
    ##  2   229   709 1955-01-02   194     0
    ##  3   229   709 1955-01-03     0     0
    ##  4   229   709 1955-01-04   168     0
    ##  5   229   709 1955-01-05    61     0
    ##  6   229   709 1955-01-06     0     0
    ##  7   229   709 1955-01-07     0     0
    ##  8   229   709 1955-01-08    82     0
    ##  9   229   709 1955-01-09    72     0
    ## 10   229   709 1955-01-10     0     0
    ## # ... with 3.352e+06 more rows

`ft_` family functions
----------------------

The family of functions prefixed with ft\_ work as feature transformer functions.

### `ft_binarizer`

Apply thresholding to a column, such that values less than or equal to the threshold are assigned the value 0.0, and values greater than the threshold are assigned the value 1.0.

In the following example we will create a column which is set to 1 in cases where rainfall records have values greater than 0 mm:

``` r
# Filter out missing records
tbl %>% dplyr::filter(q_rr != 9L) %>% 
  # Convert variable to numeric
  dplyr::mutate(rr = as.numeric(rr)) %>%
    # Perform binarizer
    sparklyr::sdf_mutate(Event = ft_binarizer(rr, 0))
```

    ## # Source:   table<sparklyr_tmp_15e77c47ae56> [?? x 6]
    ## # Database: spark_connection
    ##    staid souid       date  q_rr    rr Event
    ##    <int> <int>      <chr> <int> <dbl> <dbl>
    ##  1   229   709 1955-01-01     0    35     1
    ##  2   229   709 1955-01-02     0   194     1
    ##  3   229   709 1955-01-03     0     0     0
    ##  4   229   709 1955-01-04     0   168     1
    ##  5   229   709 1955-01-05     0    61     1
    ##  6   229   709 1955-01-06     0     0     0
    ##  7   229   709 1955-01-07     0     0     0
    ##  8   229   709 1955-01-08     0    82     1
    ##  9   229   709 1955-01-09     0    72     1
    ## 10   229   709 1955-01-10     0     0     0
    ## # ... with 3.091e+06 more rows

### `ft_bucketizer`

Divides the range of x into intervals and codes the values in x according to which interval they fall. In the following example we compute range intervals of monthly rainfall amount:

``` r
# Filter out non-missing records
tbl %>% dplyr::filter(q_rr != 9L) %>%
  # Group by station year, month
  dplyr::group_by(staid, year(date), month(date)) %>%
    # Sum the monthly rainfall amount per station and year
    dplyr::summarise(rr = as.numeric(sum(rr))) %>%
      # Compute buckets of total rainfall distribution
      sparklyr::ft_bucketizer(input.col = "rr", output.col = "Bucket",
                              splits = c(0, 100, 200, 300, 400, Inf)
                              )
```

    ## # Source:   table<sparklyr_tmp_15e7693791d2> [?? x 5]
    ## # Database: spark_connection
    ##    staid `year(date)` `month(date)`    rr Bucket
    ##    <int>        <int>         <int> <dbl>  <dbl>
    ##  1   229         1955             9     2      0
    ##  2   229         1955            11   750      4
    ##  3   229         1955            12  1536      4
    ##  4   229         1956             3  1277      4
    ##  5   229         1956             7     0      0
    ##  6   229         1956             9   655      4
    ##  7   229         1957             4   505      4
    ##  8   229         1957             7     0      0
    ##  9   229         1958             5   221      2
    ## 10   229         1958             8    57      0
    ## # ... with 1.018e+05 more rows

The resulting `data.frame` contains one column named bucket with the user defined intervasls.

Environmental rainfall indices using `sparklyr`
===============================================

In the following sections we will calculate a number of environmental rainfall indices for a big number of meteorological stations accross Europe.

### Annual rainfall amount

In the following example, the annual rainfall amount is calculated for station 229. Missing rainfall records are excluded:

``` r
# Select station 229 and filter out missing records
tbl %>% dplyr::filter(staid == 229 & rr != -9999L) %>%
  # Group by year
  dplyr::group_by(year(date)) %>% 
    # Sum the daily rainfall records
    dplyr::summarise(N = sum(rr)) %>%
      # Order records
      sparklyr::sdf_sort(columns = c("year(date)"))
```

    ## # Source:   table<sparklyr_tmp_15e737bce647> [?? x 2]
    ## # Database: spark_connection
    ##    `year(date)`     N
    ##           <int> <dbl>
    ##  1         1955  5735
    ##  2         1956  5274
    ##  3         1957  4121
    ##  4         1958  4666
    ##  5         1959  4552
    ##  6         1960  7180
    ##  7         1961  5403
    ##  8         1962  5991
    ##  9         1963  7171
    ## 10         1964  3717
    ## # ... with 53 more rows

#### Visualize annual rainfall amount

We can extend the previous script by adding a time series chart of the annual rainfall series directly:

``` r
library(dygraphs)
# Select station 229 and filter out missing records
tbl %>% dplyr::filter(staid == 229 & rr != -9999L) %>%
    # Group by year
   dplyr::group_by(year(date)) %>%
      # Sum the daily rainfall records
      dplyr::summarise(N = sum(rr)) %>%
        # Order records
        sparklyr::sdf_sort(columns = c("year(date)")) %>% dplyr::collect() %>%
            # Create plot using dygraph
            dygraph(main = paste0("Annual rainfall series of station: 229")) %>%
                dyAxis("y", label = "N") %>% dyAxis("x", label = "year(date)") %>%
                    dyRangeSelector() %>% dyOptions(fillGraph = TRUE, fillAlpha = 0.4)
```

The same example can be implemented using `ggplot2`:

``` r
library(ggplot2)
# Select station 229 and filter out missing records
tbl %>% dplyr::filter(staid == 229 & rr != -9999L) %>%
    # Group by year
   dplyr::group_by(year(date)) %>%
      # Sum the daily rainfall records
      dplyr::summarise(N = sum(rr)) %>%
        # Order records
        sparklyr::sdf_sort(columns = c("year(date)")) %>% dplyr::collect() %>%
          # Create plot using ggplot2
          ggplot2::ggplot(aes(x = `year(date)`, y = N)) + geom_line() + 
            ggtitle("Annual Rainfall series of station: 229") + xlab("Year") +
              ylab("Annual Rainfall Amount (mm)")
```

#### Exercise 3 - Number of days with "extreme" rainfall events

Calculate the annual number of days of extreme rainfall events per station and year using `sparklyr` and `dplyr` for all the Greek meteorological stations.

### Number of consecutive rainfall events for all European stations

### Number of extreme consecutive rainfall events for all European stations

Useful functions
================

### Read Spark DataFrame
