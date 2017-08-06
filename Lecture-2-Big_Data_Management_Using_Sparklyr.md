Big data analysis using `sparklyr` <br>
================
Kostas Mammas, Statistical Programmer <br> mail: <mammaskon@gmail.com> <br>
EarthBiAs2017, Rhodes Island, Greece

-   [Introduction to `sparklyr`](#introduction-to-sparklyr)
    -   [Installation - Local Remote Apache Spark cluster](#installation---local-remote-apache-spark-cluster)
    -   [`sdf_` family functions](#sdf_-family-functions)
        -   [`sdf_copy_to`](#sdf_copy_to)
        -   [`sdf_num_partitions`](#sdf_num_partitions)
        -   [`sdf_pivot`](#sdf_pivot)
        -   [`sdf_quantile`](#sdf_quantile)
        -   [`sdf_sort`](#sdf_sort)
    -   [`ft_` family functions](#ft_-family-functions)
        -   [`ft_binarizer`](#ft_binarizer)
        -   [`ft_bucketizer`](#ft_bucketizer)
        -   [`ft_quantile_discretizer`](#ft_quantile_discretizer)
        -   [`ft_sql_transformer`](#ft_sql_transformer)
    -   [Environmental rainfall indices using `sparklyr`](#environmental-rainfall-indices-using-sparklyr)
        -   [Number of consecutive rainfall events for all European stations](#number-of-consecutive-rainfall-events-for-all-european-stations)
        -   [Number of extreme consecutive rainfall events for all European stations](#number-of-extreme-consecutive-rainfall-events-for-all-european-stations)
    -   [Useful functions](#useful-functions)
        -   [Read Spark DataFrame](#read-spark-dataframe)
    -   [Appendix](#appendix)
        -   [Date manipulation on **spark** using **HIVE-SQL**](#date-manipulation-on-spark-using-hive-sql)

Introduction to `sparklyr`
==========================

**Apache Spark** is an open source parallel processing framework for running large-scale data analytics applications across clustered computers. It can handle both batch and real-time analytics and data processing workloads.

**sparklyr** is an R interface to Apache Spark, a fast and general engine for big data processing. This package supports connecting to local and remote Apache Spark clusters, provides a **dplyr** compatible back-end, and provides an interface to Spark's built-in machine learning algorithms

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

### `sdf_num_partitions`

Gets number of partitions of a Spark DataFrame:

``` r
# Obtain number of partitions
numPart <- sdf_num_partitions(tbl)
numPart
```

### `sdf_pivot`

Perform **reshape2::dcast** using Spark DataFrame:

``` r
# Compute the number of of missing and non-missing rainfall records per station
tbl %>% group_by(STAID, Q_RR) %>% summarise(N = n()) %>%
  # Create a pivot table
  sdf_pivot(STAID ~ Q_RR, list(N = "sum"))
```

### `sdf_quantile`

Compute the approximate quantiles for a continuous variable to some relative error. In the following example we compute the quantiles of the daily rainfall amount for a specific station:

``` r
# Filters station 229
tbl %>% filter(staid == 229 & rr != -9999) %>% group_by(STAID, Q_RR) %>%
  # Compute quantile
  sdf_quantile(rr, probabilities = c(0, 0.25, 0.5, 0.75, 0.90,  1))
```

### `sdf_sort`

Sort a Spark DataFrame by one or more columns, with each column sorted in ascending order.

``` r
tbl %>% sdf_sort(columns = c("staid","date"))
```

`ft_` family functions
----------------------

The family of functions prefixed with ft\_ work as feature transformer functions.

### `ft_binarizer`

Apply thresholding to a column, such that values less than or equal to the threshold are assigned the value 0.0, and values greater than the threshold are assigned the value 1.0.

In the following example we will create a column which is set to 1 in cases where rainfall records have values greater than 0 mm:

``` r
# Filter out missing records
tbl %>% filter(q_rr != 9) %>% 
  # Convert variable to numeric
  mutate(rr = as.numeric(rr)) %>%
    # Perform binarizer
    sdf_mutate(Event = ft_binarizer(rr, 0))
```

### `ft_bucketizer`

### `ft_quantile_discretizer`

### `ft_sql_transformer`

Environmental rainfall indices using `sparklyr`
-----------------------------------------------

### Number of consecutive rainfall events for all European stations

### Number of extreme consecutive rainfall events for all European stations

Useful functions
----------------

### Read Spark DataFrame

Appendix
--------

#### Date manipulation on **spark** using **HIVE-SQL**

The current version of `sparklyr: 0.6.0` does not allow date manipulation using `dplyr`. In our case we can directly modify date using native **HIVE-SQL** functions. The following example converts date from integer format to date:

``` r
# Perform date manipulation on Spark using HIVE-SQL 
# (HIVE does not allow direct table update so we create a new table and drop the old one)

# Drop HIVE table if exists
dbExecute(sc, "DROP TABLE IF EXISTS envSparlTblUpd")

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

# Drop old table
dbExecute(sc, "DROP TABLE IF EXISTS envSparlTbl")

# Read Spark DataFrame
tbl <- spark_read_table(sc = sc, name = "envSparlTblUpd")
```
