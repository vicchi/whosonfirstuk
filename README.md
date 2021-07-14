# whosonfirstuk

Early stages of creating a set of [Who's On First](https://whosonfirst.org) data for the United Kingdom based on open data sources.

Right now, this repo contains scripts to normalise and merge data sets into a single PostGIS table, creating parent and child relationships for administrative, census and electoral hierarchies.

## Supported Environments

The scripts and pipeline in this repository have been run and tested on both macOS 11.4 Big Sur and on Ubuntu 20.04 LTS and should, in theory, work just fine on other Linux distros too. YMMV of course.

## Prerequisites

* Python v3 or higher (`3.8` recommended), including `pip` and `virtualenv`
* GDAL
* JQ
* PostgreSQL v12 / PostGIS v3

## Dependencies

Install Python dependencies into a _virtual environment_ via `pip` (you _can_ install Python dependencies into the system Python packages directory but this can cause problems with version number clashes with other previously installed packages, including `pip` itself, so a virtual environment is really _strongly_ recommended. Because Python's packaging system is one of the less lovely aspects of the language, so we'll just overlook this and use a virtual environment).

```
$ virtualenv -p $(which python3) ./venv
$ source ./venv/bin/activate
$ pip install -r requirements.txt
```

## Setup

Make a local copy of `.env.sample` as `.env`.

```
$ cp .env.sample .env
```

You'll more than likely need to make changes to most settings, including:

1. `REPO_ROOT` - the absolute path to the root of this repo
1. `POSTGRES_USER` - your PostgreSQL user name
1. `POSTGRES_PASSWD` - your PostgreSQL user's password
1. `POSTGRES_HOST` - the FQDN of your PostgreSQL instance, or `localhost`
1. `POSTGRES_DB` - the database name all of this geodata goodness will reside in, defaults to `whosonfirstuk`

### Database Setup

You'll need to create the database you set as `POSTGRES_DB` if it doesn't already exist and load the PostGIS and LTRee extensions. Assuming the default database name of `whosonfirstuk` ...

```
$ sudo -u postgres createdb whosonfirstuk
$ sudo -u postgres psql whosonfirstuk -c 'CREATE EXTENSION postgis;'
$ sudo -u postgres psql whosonfirstuk -c 'CREATE EXTENSION ltree;'
```

## Data Preparation

You'll now need to download the latest data sources and move them into the directories under `${REPO_ROOT}/data/archives` as detailed at the end of this `README`. Yes, there's a lot. Yes, this should be scripted.

The names of each download should match the corresponding entry in `source-manifest.json` but if more recent versions have been released, this file will need to be updated.

At the time of writing, the resultant directory tree will look something like this ...

```
$ ls -R1 data/archives/
data/archives/:
mgs
nisra
nrs
ons
os
osni

data/archives/mgs:
SG_DataZoneBdry_2011.zip
SG_IntermediateZoneBdry_2011.zip

data/archives/nisra:
OA_ni_ESRI.zip
SA2011_Esri_Shapefile_0.zip
SOA2011_Esri_Shapefile_0.zip

data/archives/nrs:
output-area-2011-mhw.zip

data/archives/ons:
'Code_History_Database_(June_2021)_UK.zip'
'Combined_Authorities_(December_2020)_EN_BFC.zip'
'Counties_and_Unitary_Authorities_(December_2020)_UK_BFC.zip'
'Countries_(December_2020)_UK_BFC.zip'
'European_Electoral_Regions_(December_2018)_Boundaries_UK_BFC.zip'
'Local_Authority_Districts_(December_2020)_UK_BFC.zip'
'London_Assembly_Constituencies_(December_2018)_Boundaries_EN_BFC.zip'
Lower_Layer_Super_Output_Areas__December_2011__Boundaries_Full_Clipped__BFC__EW_V3-shp.zip
'Metropolitan_Counties_(December_2018)_EN_BFC.zip'
Middle_Layer_Super_Output_Areas__December_2011__Boundaries_Full_Clipped__BFC__EW_V3-shp.zip
'National_Assembly_for_Wales_Constituencies_(December_2018)_WA_BFC.zip'
'National_Assembly_for_Wales_Electoral_Regions_(December_2018)_Boundaries_WA_BFC.zip'
Output_Areas__December_2011__Boundaries_EW_BFC-shp.zip
Parishes_and_Non_Civil_Parished_Areas__December_2020__EW_BFC_V2-shp.zip
'Regions_(December_2020)_EN_BFC.zip'
'Register_of_Geographic_Codes_(June_2021)_UK.zip'
'Scottish_Parliamentary_Constituencies_(May_2016)_Boundaries.zip'
'Scottish_Parliamentary_Regions_(May_2016)_Boundaries.zip'
'Wards_(December_2020)_UK_BFC_V2.zip'
'Westminster_Parliamentary_Constituencies_(December_2019)_Boundaries_UK_BFC.zip'

data/archives/os:
bdline_gpkg_gb.zip

data/archives/osni:
'OSNI_Open_Data_-_Largescale_Boundaries_-_District_Electoral_Areas_(2012).zip'
'OSNI_Open_Data_-_Largescale_Boundaries_-_Local_Government_Districts_(2012).zip'
OSNI_Open_Data_-_Largescale_Boundaries_-_NI_Outline.zip
'OSNI_Open_Data_-_Largescale_Boundaries_-_Wards_(2012)-shp.zip'
```

Next, all the ZIP archives will need to be unpacked and moved into the directory tree under `${REPO_ROOT}/data/sources`. Thankfully everything from this point on _is_ scripted.

```
./bin/unpack.sh
```

## Data Loading

The last stage, for now at least, is to normalise and merge all the data sources into a single table called `places`.

```
./bin/load-sources.sh
```

For completeness, one data set, containing the census Super Output Areas, Upper Layer (USOAs) for Wales, is not publicly available, but geometry and boundary definitions of these can be generated from their constituent Super Output Areas, Middle Layer (MSOAs).

```
./bin/backfill-usoas.py
```

Next, each place's parent need to be determined, either from the ONS Change History Database or derived by a point-in-polygon calculation for each of the three hierarchies; adminstrative, census and electoral. The output of this step, `parents.json` is required for the final step in the pipeline.

```
./bin/build-parents.py --config ${REPO_ROOT}/etc/config.json --parents ${REPO_ROOT}/parents.json
```

And finally, the full parent child hierarchy for all three types are rebuilt. This is both written to the `places` table in PostgreSQL _and_ to a final output JSON file for quick and easy(er) spelunking.

```
./bin/build-hierarchy.py --config ${REPO_ROOT}/etc/config.json --parents ${REPO_ROOT}/parents.json --output ${REPO_ROOT}/hierarchy.json
```

Timings to load the data and rebuild and generation the hierarchies will vary, but on an AMD Ryzen 7 machine with 64 GB of memory running Ubuntu 20.04 LTS will take around 45 minutes for the whole process.

## Data Download Sources

### Office for National Statistics Code History Database
* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(PRD_CHD%2CJUN_2021)
* https://www.arcgis.com/sharing/rest/content/items/db8e133607244b58a1e2e5dca433391e/data

### Office for National Statistics Register of Geographic Codes
*  https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(PRD_RGC%2CJUN_2021)
* https://geoportal.statistics.gov.uk/datasets/register-of-geographic-codes-june-2021-for-the-united-kingdom/about
* https://www.arcgis.com/sharing/rest/content/items/600c58982a21459bb2e1c635f8312feb/data

### OS BoundaryLine

* https://osdatahub.os.uk/downloads/open/BoundaryLine
* https://api.os.uk/downloads/v1/products/BoundaryLine/downloads?area=GB&format=GeoPackage&redirect
* https://omseprd1stdstordownload.blob.core.windows.net/downloads/BoundaryLine/2021-05/allGB/GeoPackage/bdline_gpkg_gb.zip?sv=2020-04-08&spr=https&se=2021-07-10T11%3A26%3A52Z&sr=b&sp=r&sig=8CBHZ%2FU851EVa9czDfK7Kpu917dyGYTqJNPqPcUab6c%3D

### OS Northern Ireland Local Government Districts

* https://data.gov.uk/dataset/8c954c51-9310-4cb5-b528-f8735fc16b0c/osni-open-data-largescale-boundaries-local-government-districts-2012
* https://osni-spatialni.opendata.arcgis.com/datasets/eaa08860c50045deb8c4fdc7fa3dac87_2.zip?outSR=%7B%22latestWkid%22%3A29902%2C%22wkid%22%3A29900%7D

### OS Northern Ireland District Electoral Areas

* https://data.gov.uk/dataset/d3f17ee3-a537-4908-b2ff-207f22d0dd98/osni-open-data-largescale-boundaries-district-electoral-areas-2012
* https://osni-spatialni.opendata.arcgis.com/datasets/bc01e8fe0f4e440ab3a7fc3949ae0fa2_4.zip

### OS Northern Ireland Wards

* https://data.gov.uk/dataset/a7802ada-9d95-4f37-bc40-1063b5bc4506/osni-open-data-largescale-boundaries-wards-2012
* http://osni-spatialni.opendata.arcgis.com/datasets/59cb3fa5880f4e0aa1ecb0749c6bc078_9.zip

### OS Northern Ireland Countries

* https://data.gov.uk/dataset/d3ca9d44-a7eb-4380-86cb-0cc28e1f1b27/osni-open-data-largescale-boundaries-ni-outline
* http://osni-spatialni.opendata.arcgis.com/datasets/159c80fe1ad54140b429f8799f624962_0.zip

### Office for National Statistics Countries

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=-modified&tags=all(BDY_CTRY%2CDEC_2020)
* https://geoportal.statistics.gov.uk/datasets/countries-december-2020-uk-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/99d27c909afe421a942fa36f11261b0e_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Regions

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_RGN%2CDEC_2020)
* https://geoportal.statistics.gov.uk/datasets/regions-december-2020-en-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/6985f8fe929c4ec2b86e47a412e93952_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Counties and Unitary Authorities

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_CTYUA%2CDEC_2020)
* https://geoportal.statistics.gov.uk/datasets/counties-and-unitary-authorities-december-2020-uk-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/b09f446bb2954951844172fb8de4ef54_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Combined Authorities

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_CAUTH%2CDEC_2020)
* https://geoportal.statistics.gov.uk/datasets/combined-authorities-december-2020-en-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/183ca07d2fd54662bf5ede4b8e33b445_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Local Authority Districts

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_LAD%2CDEC_2020)
* https://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2020-uk-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/bc2820b03de244698c0b0771ae4f345f_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Metropolitan Counties

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_MCTY%2CDEC_2018)
* https://geoportal.statistics.gov.uk/datasets/metropolitan-counties-december-2018-en-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/389f538f35ef4eeb84965dfd7c0a0b47_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Parishes and Non Civil Parished Areas

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_PARNCP%2CDEC_2020)
* https://geoportal.statistics.gov.uk/datasets/parishes-and-non-civil-parished-areas-december-2020-ew-bfc-v2/explore
* https://opendata.arcgis.com/api/v3/datasets/1515010e748b452f9d888e588ea86bfa_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Westminster Parliamentary Constituencies

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_PCON%2CDEC_2019)
* https://geoportal.statistics.gov.uk/datasets/westminster-parliamentary-constituencies-december-2019-boundaries-uk-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/26ea865b037249b7a1bbc3ad72275f24_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics London Assembly Constituencies

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_LAC%2CDEC_2018)
* https://geoportal.statistics.gov.uk/datasets/london-assembly-constituencies-december-2018-boundaries-en-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/f49599068a7c4226bf6d48ec6c8a353a_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Wards and Electoral Regions

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_WD%2CDEC_2020)
* https://geoportal.statistics.gov.uk/datasets/wards-december-2020-uk-bfc-v2/explore
* https://opendata.arcgis.com/api/v3/datasets/5c11da1763024bd59ef0b6beafa59ae6_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Scottish Parliamentary Constituencies

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_SPC)
* https://geoportal.statistics.gov.uk/datasets/scottish-parliamentary-constituencies-may-2016-full-clipped-boundaries-in-scotland/explore?location=57.650000%2C-4.150000%2C7.22
* https://opendata.arcgis.com/api/v3/datasets/00436d85fa664f0fb7dce4a1aff83f27_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Scottish Parliamentary Regions

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_SPR)
* https://geoportal.statistics.gov.uk/datasets/scottish-parliamentary-regions-may-2016-full-clipped-boundaries-in-scotland/explore
* https://opendata.arcgis.com/api/v3/datasets/c890fc7b1ad14311bb71660ec6524c9e_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics National Assembly for Wales Constituencies

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_NAWC%2CDEC_2018)
* https://geoportal.statistics.gov.uk/datasets/national-assembly-for-wales-constituencies-december-2018-wa-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/36e5d6e6db0643e19371a13a80b9b6c5_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics National Assembly for Wales Electoral Regions

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_NAWER%2CDEC_2018)
* https://geoportal.statistics.gov.uk/datasets/national-assembly-for-wales-electoral-regions-december-2018-boundaries-wa-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/62b530024ca549b9863e6d27f9bc48ed_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics European Electoral Regions

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_EER%2CDEC_2018)
* https://geoportal.statistics.gov.uk/datasets/european-electoral-regions-december-2018-boundaries-uk-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/678a7ee62d844a5488036626eb713aa1_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Lower Layer Super Output Areas

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_LSOA%2CDEC_2011)
* https://geoportal.statistics.gov.uk/datasets/lower-layer-super-output-areas-december-2011-boundaries-full-clipped-bfc-ew-v3/explore
* https://opendata.arcgis.com/api/v3/datasets/1f23484eafea45f98485ef816e4fee2d_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Middle Layer Super Output Areas

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_MSOA%2CDEC_2011)
* https://geoportal.statistics.gov.uk/datasets/middle-layer-super-output-areas-december-2011-boundaries-full-clipped-bfc-ew-v3/explore
* https://opendata.arcgis.com/api/v3/datasets/1382f390c22f4bed89ce11f2a9207ff0_0/downloads/data?format=shp&spatialRefId=27700

### Office for National Statistics Output Areas

* https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_OA%2CDEC_2011)
* https://geoportal.statistics.gov.uk/datasets/output-areas-december-2011-boundaries-ew-bfc/explore
* https://opendata.arcgis.com/api/v3/datasets/09b58d063d4e421a9cad16ba5419a6bd_0/downloads/data?format=shp&spatialRefId=27700

### National Register of Scotland Output Areas

* https://www.nrscotland.gov.uk/statistics-and-data/geography/our-products/census-datasets/2011-census/2011-boundaries
* https://www.nrscotland.gov.uk/files/geography/output-area-2011-mhw.zip

### Scottish Government Data Zones

* https://data.gov.uk/dataset/ab9f1f20-3b7f-4efa-9bd2-239acf63b540/data-zone-boundaries-2011
* https://maps.gov.scot/ATOM/shapefiles/SG_DataZoneBdry_2011.zip

### Scottish Government Intermediate Zones

* https://data.gov.uk/dataset/133d4983-c57d-4ded-bc59-390c962ea280/intermediate-zone-boundaries-2011
* https://maps.gov.scot/ATOM/shapefiles/SG_IntermediateZoneBdry_2011.zip

### Northern Ireland Statistics and Research Agency Output Areas

* https://www.nisra.gov.uk/support/geography/northern-ireland-output-areas
* https://www.nisra.gov.uk/sites/nisra.gov.uk/files/publications/OA_ni%20ESRI.zip

### Northern Ireland Statistics and Research Agency Small Areas

* https://www.nisra.gov.uk/support/geography/northern-ireland-small-areas
* https://www.nisra.gov.uk/sites/nisra.gov.uk/files/publications/SA2011_Esri_Shapefile_0.zip

### Northern Ireland Statistics and Research Agency Super Output Areas

* https://www.nisra.gov.uk/support/geography/northern-ireland-super-output-areas
* https://www.nisra.gov.uk/sites/nisra.gov.uk/files/publications/SOA2011_Esri_Shapefile_0.zip
