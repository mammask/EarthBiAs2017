Setup working environment - Introduction to large data management using R
================
Kostas Mammas, Statistical Programmer <br> mail <mammaskon@gmail.com> <br>
EarthBiAs2017, Rhodes Island, Greece

-   [Introduction](#introduction)
-   [Useful links](#useful-links)
-   [Software Installation](#software-installation)
-   [Folder setup & package installation](#folder-setup-package-installation)
-   [Download data](#download-data)

### Introduction

The present document provides details about how to setup `R` locally in order to follow the lectures of **Introduction to large data management using `R`**.

For those who are **not** familiar with `R` it is advised to follow the introductory courses presented in section **Useful links**. Please make sure to read and understand the next sessions before you join the sessions.

### Useful links

In order to familiarize yourself with `R` it is advised to go through the following links:

-   Introduction to [`R`](https://cran.r-project.org/doc/manuals/r-release/R-intro.pdf)
-   Introduction to [`data.table`](https://cran.r-project.org/web/packages/data.table/vignettes/datatable-intro.html)

### Software Installation

`R` and `RStudio` need to be installed in the following order:

1.  Latest version of [`R`](https://cran.r-project.org/bin/windows/base/)
2.  Latest version of [`RStudio`](https://www.rstudio.com/products/rstudio/download/)

### Folder setup & package installation

As a first step, you need to create a folder where all the analysis will take place. Please create a folder named **Summer\_School\_2017** locally (i.e. under the Documents area) and run the following script (replace **"~/Documents/Summer\_School\_2017"** with your own path):

``` r
# Folder setup
currPath <- "~/Documents/Summer_School_2017"                        # Current path
setwd(currPath)                                                     # Define working directory

# Package Installation
packToInstall <- c("data.table")                                    # List of packages to install
install.packages(packToInstall, dependencies = T)                   # Install packages
lapply(packToInstall, require, character.only = TRUE)               # Load packages

# Folder creation
outputsFolder <- paste0(currPath,"/Outputs")                        # Define outputs path
dir.create(outputsFolder, showWarnings = FALSE)                     # Create outputs
```

### Download data

For the purposes of the sessions in `R` we use a set of precipitation records from 300 meteorological stations across Europe. Data can be found in the following [link]().
