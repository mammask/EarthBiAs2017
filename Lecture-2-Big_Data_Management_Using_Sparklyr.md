Big data processing using `sparklyr` <br>
================
Kostas Mammas, Statistical Programmer <br> mail <mammaskon@gmail.com> <br>
EarthBiAs2017, Rhodes Island, Greece

-   [Introduction to `sparklyr`](#introduction-to-sparklyr)
    -   [Installation - Local Remote Apache Spark cluster](#installation---local-remote-apache-spark-cluster)
    -   [Useful `sparklyr` functions](#useful-sparklyr-functions)

<style type="text/css">

body{ /* Normal  */
font-size: 14px;
}
td {  /* Table  */
font-size: 12px;
}
h1 { /* Header 1 */
font-size: 24px;
color: DarkBlue;
}
h2 { /* Header 2 */
font-size: 22px;
color: DarkBlue;
}
h3 { /* Header 3 */
font-size: 18px;
color: DarkBlue;
}
code.r{ /* Code block */
font-size: 12px;
}
pre { /* Code block */
font-size: 12px
}

</style>
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

Useful `sparklyr` functions
---------------------------

-   `sdf_copy_to`: Copy an object into Spark, and return an R object wrapping the copied object (typically, a Spark DataFrame).

**Example**

``` r
# Load sparklyr
library("sparklyr")
# Connect to Local Remote Apache Spark cluster
sc <- spark_connect(master = "local")
# Generate a table of radom numebers
cusTabl <- data.frame(matrix(rnorm(100), ncol = 5))
# Copy R object into spark
md <- sparklyr::sdf_copy_to(sc          = sc,
                            x           = cusTabl,
                            name        = "cusTabl",
                            memory      = TRUE,
                            repartition = 0L,
                            overwrite   = TRUE)
```
