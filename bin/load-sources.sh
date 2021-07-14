#!/usr/bin/env bash
# shellcheck shell=bash

function nameify {
    local fullpath="${1}"
    local nameandext="${fullpath##*/}"
    local nameonly="${nameandext%.*}"
    echo "${nameonly}"
}

if [[ ! -f "$(pwd)/.env" ]]; then
    echo >&2 "ERROR: Couldn't find a .env file; try copying .env.sample and editing it"
    exit 1
fi

# shellcheck disable=SC2046
export $(sed 's/#.*//g' <"$(pwd)/.env" | xargs)

DSN="dbname=${POSTGRES_DB} host=${POSTGRES_HOST} port=${POSTGRES_PORT} user=${POSTGRES_USER} password=${POSTGRES_PASSWD}"
CONNSTR="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
DATAROOT=${REPO_ROOT}/data/sources

# psql custom command line options:
#   -X, --no-psqlrc : ignore system wide psqlrc and ~/.psqlrc
#   -c client_min_messages=warning: don't display NOTICE messages (via PGOPTIONS)
#   -1, --single-transaction : wrap up script execution in a single transaction
#   -v ON_ERROR_STOP=1 : stop execution if a transaction fails
#   -P/--pset pager=off : turn off output pager (when running in a script)

# shellcheck disable=SC2034
export PGOPTIONS="-c client_min_messages=warning"
PSQL="psql -X -1 -v ON_ERROR_STOP=1 -P pager=off"

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(PRD_CHD%2CJUN_2021)
# https://www.arcgis.com/sharing/rest/content/items/db8e133607244b58a1e2e5dca433391e/data

SRCDIR="ons-chd"
SRCFILE="${DATAROOT}/${SRCDIR}/ChangeHistory.csv"
CSVTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -overwrite \
    -nln "${SRCDIR//-/_}" \
    -gt 10000 \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco COLUMN_TYPES=oper_date=timestamp,term_date=timestamp \
    -oo EMPTY_STRING_AS_NULL=YES \
    -sql "SELECT geogcd AS gsscode, geognm AS name, geognmw AS name_cym, oper_date, term_date, parentcd AS parent_gsscode, entitycd,owner,status FROM \"${CSVTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(PRD_RGC%2CJUN_2021)
# https://geoportal.statistics.gov.uk/datasets/register-of-geographic-codes-june-2021-for-the-united-kingdom/about
# https://www.arcgis.com/sharing/rest/content/items/600c58982a21459bb2e1c635f8312feb/data

SRCDIR="ons-rgc"
# FFS ... the Register of Geographic Codes *should* be a CSV but now seems to be in Excel format
SRCFILE="${DATAROOT}/${SRCDIR}/RGC_JUNE_2021_UK.xlsx"
CSVTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."
# fp="${SRCFILE##*/}"
# src="${fp%.*}"

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -overwrite \
    -nln "${SRCDIR//-/_}" \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -oo EMPTY_STRING_AS_NULL=YES \
    -sql "SELECT \"entity code\" AS entity, \"entity name\" AS name, \"entity abbreviation\" AS abbr, \"entity theme\" AS theme, \"entity coverage\" AS coverage, \"related entity codes\" AS related, status, CAST(\"number of live instances\" AS integer) AS live_count, CAST(\"number of archived instances\" AS integer) AS archived_count, \"number of cross-border instances\" AS xborder_count, \"date of last instance change\" AS change_date, \"current code (first in range)\" AS first_code, \"current code (last in range)\" AS last_code, \"reserved code (for chd use)\" AS reserved_code, \"entity owner abbreviation\" AS owner_abbr, \"date entity introduced on rgc\" AS intro_date, \"entity start date\" AS start_date FROM \"RGC\""

# https://osdatahub.os.uk/downloads/open/BoundaryLine
# https://api.os.uk/downloads/v1/products/BoundaryLine/downloads?area=GB&format=GeoPackage&redirect
# https://omseprd1stdstordownload.blob.core.windows.net/downloads/BoundaryLine/2021-05/allGB/GeoPackage/bdline_gpkg_gb.zip?sv=2020-04-08&spr=https&se=2021-07-10T11%3A26%3A52Z&sr=b&sp=r&sig=8CBHZ%2FU851EVa9czDfK7Kpu917dyGYTqJNPqPcUab6c%3D

SRCDIR="os-bdline"
SRCFILE="${DATAROOT}/${SRCDIR}/bdline_gb.gpkg"
echo "${SRCDIR} (boundary_line_ceremonial_counties only) ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "historic" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT Name AS name, geom FROM boundary_line_ceremonial_counties"

SRCDIR="os-bdline"
SRCFILE="${DATAROOT}/${SRCDIR}/bdline_gb.gpkg"
echo "${SRCDIR} (Greater London Authority only) ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "os_gla" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT Census_Code AS gsscode, Name AS name, geom FROM county WHERE Census_Code = 'E61000001'"

# https://data.gov.uk/dataset/8c954c51-9310-4cb5-b528-f8735fc16b0c/osni-open-data-largescale-boundaries-local-government-districts-2012
# https://osni-spatialni.opendata.arcgis.com/datasets/eaa08860c50045deb8c4fdc7fa3dac87_2.zip?outSR=%7B%22latestWkid%22%3A29902%2C%22wkid%22%3A29900%7D

SRCDIR="osni-lgd"
SRCFILE="${DATAROOT}/${SRCDIR}/OSNI_Open_Data_-_Largescale_Boundaries_-_Local_Government_Districts_(2012).shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:29902 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT LGDCode AS gsscode, LGDNAME AS name FROM \"${SHPTABLE}\""

# https://data.gov.uk/dataset/d3f17ee3-a537-4908-b2ff-207f22d0dd98/osni-open-data-largescale-boundaries-district-electoral-areas-2012
# https://osni-spatialni.opendata.arcgis.com/datasets/bc01e8fe0f4e440ab3a7fc3949ae0fa2_4.zip

SRCDIR="osni-dea"
SRCFILE="${DATAROOT}/${SRCDIR}/OSNI_Open_Data_-_Largescale_Boundaries_-_District_Electoral_Areas_(2012).shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:29902 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT FinalR_DEA AS name FROM \"${SHPTABLE}\""

# https://data.gov.uk/dataset/a7802ada-9d95-4f37-bc40-1063b5bc4506/osni-open-data-largescale-boundaries-wards-2012
# http://osni-spatialni.opendata.arcgis.com/datasets/59cb3fa5880f4e0aa1ecb0749c6bc078_9.zip

SRCDIR="osni-wd"
SRCFILE="${DATAROOT}/${SRCDIR}/ce800a0a-cd74-4576-8183-86ebee08e876202044-1-n83mn4.9mdj.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:4326 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT WardCode AS gsscode, WARDNAME AS name FROM \"${SHPTABLE}\""

# https://data.gov.uk/dataset/d3ca9d44-a7eb-4380-86cb-0cc28e1f1b27/osni-open-data-largescale-boundaries-ni-outline
# http://osni-spatialni.opendata.arcgis.com/datasets/159c80fe1ad54140b429f8799f624962_0.zip

SRCDIR="osni-ctry"
SRCFILE="${DATAROOT}/${SRCDIR}/OSNI_Open_Data_-_Largescale_Boundaries_-_NI_Outline.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:4326 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT 'N92000002' AS gsscode, 'Northern Ireland' AS name, 'Gogledd Iwerddon' AS name_cym FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=-modified&tags=all(BDY_CTRY%2CDEC_2020)
# https://geoportal.statistics.gov.uk/datasets/countries-december-2020-uk-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/99d27c909afe421a942fa36f11261b0e_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-ctry"
SRCFILE="${DATAROOT}/${SRCDIR}/Countries_(December_2020)_UK_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT ctry20cd AS gsscode, ctry20nm AS name, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_RGN%2CDEC_2020)
# https://geoportal.statistics.gov.uk/datasets/regions-december-2020-en-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/6985f8fe929c4ec2b86e47a412e93952_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-rgn"
SRCFILE="${DATAROOT}/${SRCDIR}/Regions_(December_2020)_EN_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT rgn20cd AS gsscode, rgn20nm AS name, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_CTYUA%2CDEC_2020)
# https://geoportal.statistics.gov.uk/datasets/counties-and-unitary-authorities-december-2020-uk-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/b09f446bb2954951844172fb8de4ef54_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-ctyua"
SRCFILE="${DATAROOT}/${SRCDIR}/Counties_and_Unitary_Authorities_(December_2020)_UK_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT ctyua20cd AS gsscode, ctyua20nm AS name, ctyua20nmw AS name_cym, long AS lng, lat AS lat FROM \"${SHPTABLE}\" WHERE ctyua20cd LIKE 'E06%' OR ctyua20cd LIKE 'E10%'"

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_CAUTH%2CDEC_2020)
# https://geoportal.statistics.gov.uk/datasets/combined-authorities-december-2020-en-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/183ca07d2fd54662bf5ede4b8e33b445_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-cauth"
SRCFILE="${DATAROOT}/${SRCDIR}/Combined_Authorities_(December_2020)_EN_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT cauth20cd AS gsscode, cauth20nm AS name, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_LAD%2CDEC_2020)
# https://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2020-uk-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/bc2820b03de244698c0b0771ae4f345f_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-lad"
SRCFILE="${DATAROOT}/${SRCDIR}/Local_Authority_Districts_(December_2020)_UK_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT lad20cd AS gsscode, lad20nm AS name, lad20nmw AS name_cym, long AS lng, lat AS lat FROM \"${SHPTABLE}\" WHERE lad20cd NOT LIKE 'E06%'" # -progress \

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_MCTY%2CDEC_2018)
# https://geoportal.statistics.gov.uk/datasets/metropolitan-counties-december-2018-en-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/389f538f35ef4eeb84965dfd7c0a0b47_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-mcty"
SRCFILE="${DATAROOT}/${SRCDIR}/Metropolitan_Counties_(December_2018)_EN_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT mcty18cd AS gsscode, mcty18nm AS name, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_PARNCP%2CDEC_2020)
# https://geoportal.statistics.gov.uk/datasets/parishes-and-non-civil-parished-areas-december-2020-ew-bfc-v2/explore
# https://opendata.arcgis.com/api/v3/datasets/1515010e748b452f9d888e588ea86bfa_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-parncp"
SRCFILE="${DATAROOT}/${SRCDIR}/Parishes_and_Non_Civil_Parished_Areas__December_2020__EW_BFC_V2.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT parncp20cd AS gsscode, parncp20nm AS name, parncp20nw AS name_cym, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_PCON%2CDEC_2019)
# https://geoportal.statistics.gov.uk/datasets/westminster-parliamentary-constituencies-december-2019-boundaries-uk-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/26ea865b037249b7a1bbc3ad72275f24_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-pcon"
SRCFILE="${DATAROOT}/${SRCDIR}/Westminster_Parliamentary_Constituencies_(December_2019)_Boundaries_UK_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT pcon19cd AS gsscode, pcon19nm AS name, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_LAC%2CDEC_2018)
# https://geoportal.statistics.gov.uk/datasets/london-assembly-constituencies-december-2018-boundaries-en-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/f49599068a7c4226bf6d48ec6c8a353a_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-lac"
SRCFILE="${DATAROOT}/${SRCDIR}/London_Assembly_Constituencies_(December_2018)_Boundaries_EN_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT lac18cd AS gsscode, lac18nm AS name, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_WD%2CDEC_2020)
# https://geoportal.statistics.gov.uk/datasets/wards-december-2020-uk-bfc-v2/explore
# https://opendata.arcgis.com/api/v3/datasets/5c11da1763024bd59ef0b6beafa59ae6_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-wd"
SRCFILE="${DATAROOT}/${SRCDIR}/Wards_(December_2020)_UK_BFC_V2.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT wd20cd AS gsscode, wd20nm AS name, wd20nmw AS name_cym, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_SPC)
# https://geoportal.statistics.gov.uk/datasets/scottish-parliamentary-constituencies-may-2016-full-clipped-boundaries-in-scotland/explore?location=57.650000%2C-4.150000%2C7.22
# https://opendata.arcgis.com/api/v3/datasets/00436d85fa664f0fb7dce4a1aff83f27_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-spc"
SRCFILE="${DATAROOT}/${SRCDIR}/Scottish_Parliamentary_Constituencies_(May_2016)_Boundaries.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT spc16cd AS gsscode, spc16nm AS name FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_SPR)
# https://geoportal.statistics.gov.uk/datasets/scottish-parliamentary-regions-may-2016-full-clipped-boundaries-in-scotland/explore
# https://opendata.arcgis.com/api/v3/datasets/c890fc7b1ad14311bb71660ec6524c9e_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-spr"
SRCFILE="${DATAROOT}/${SRCDIR}/Scottish_Parliamentary_Regions_(May_2016)_Boundaries.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT spr16cd AS gsscode, spr16nm AS name FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_NAWC%2CDEC_2018)
# https://geoportal.statistics.gov.uk/datasets/national-assembly-for-wales-constituencies-december-2018-wa-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/36e5d6e6db0643e19371a13a80b9b6c5_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-nawc"
SRCFILE="${DATAROOT}/${SRCDIR}/National_Assembly_for_Wales_Constituencies_(December_2018)_WA_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT nawc18cd AS gsscode, nawc18nm AS name, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_NAWER%2CDEC_2018)
# https://geoportal.statistics.gov.uk/datasets/national-assembly-for-wales-electoral-regions-december-2018-boundaries-wa-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/62b530024ca549b9863e6d27f9bc48ed_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-nawer"
SRCFILE="${DATAROOT}/${SRCDIR}/National_Assembly_for_Wales_Electoral_Regions_(December_2018)_Boundaries_WA_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT nawer18cd AS gsscode, nawer18nm AS name, nawer18nmw AS name_cym, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_EER%2CDEC_2018)
# https://geoportal.statistics.gov.uk/datasets/european-electoral-regions-december-2018-boundaries-uk-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/678a7ee62d844a5488036626eb713aa1_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-eer"
SRCFILE="${DATAROOT}/${SRCDIR}/European_Electoral_Regions_(December_2018)_Boundaries_UK_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT eer18cd AS gsscode, eer18nm AS name, long AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_LSOA%2CDEC_2011)
# https://geoportal.statistics.gov.uk/datasets/lower-layer-super-output-areas-december-2011-boundaries-full-clipped-bfc-ew-v3/explore
# https://opendata.arcgis.com/api/v3/datasets/1f23484eafea45f98485ef816e4fee2d_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-lsoa"
SRCFILE="${DATAROOT}/${SRCDIR}/Lower_Layer_Super_Output_Areas__December_2011__Boundaries_Full_Clipped__BFC__EW_V3.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT lsoa11cd AS gsscode, lsoa11nm AS name, long_ AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_MSOA%2CDEC_2011)
# https://geoportal.statistics.gov.uk/datasets/middle-layer-super-output-areas-december-2011-boundaries-full-clipped-bfc-ew-v3/explore
# https://opendata.arcgis.com/api/v3/datasets/1382f390c22f4bed89ce11f2a9207ff0_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-msoa"
SRCFILE="${DATAROOT}/${SRCDIR}/Middle_Layer_Super_Output_Areas__December_2011__Boundaries_Full_Clipped__BFC__EW_V3.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT msoa11cd AS gsscode, msoa11nm AS name, long_ AS lng, lat AS lat FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=name&tags=all(BDY_OA%2CDEC_2011)
# https://geoportal.statistics.gov.uk/datasets/output-areas-december-2011-boundaries-ew-bfc/explore
# https://opendata.arcgis.com/api/v3/datasets/09b58d063d4e421a9cad16ba5419a6bd_0/downloads/data?format=shp&spatialRefId=27700

SRCDIR="ons-oa"
SRCFILE="${DATAROOT}/${SRCDIR}/Output_Areas__December_2011__Boundaries_EW_BFC.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT oa11cd AS gsscode, lad16cd AS lad_gsscode, lad16nm AS lad_name FROM \"${SHPTABLE}\""

SRCDIR="nrs-oa"
SRCFILE="${DATAROOT}/${SRCDIR}/OutputArea2011_MHW.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT code AS gsscode, council AS ca_gsscode, datazone AS dz_gsscode FROM \"${SHPTABLE}\""

# https://data.gov.uk/dataset/ab9f1f20-3b7f-4efa-9bd2-239acf63b540/data-zone-boundaries-2011
# https://maps.gov.scot/ATOM/shapefiles/SG_DataZoneBdry_2011.zip

SRCDIR="mgs-dz"
SRCFILE="${DATAROOT}/${SRCDIR}/SG_DataZone_Bdry_2011.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT DataZone AS gsscode, Name AS name FROM \"${SHPTABLE}\""

# https://data.gov.uk/dataset/133d4983-c57d-4ded-bc59-390c962ea280/intermediate-zone-boundaries-2011
# https://maps.gov.scot/ATOM/shapefiles/SG_IntermediateZoneBdry_2011.zip

SRCDIR="mgs-iz"
SRCFILE="${DATAROOT}/${SRCDIR}/SG_IntermediateZone_Bdry_2011.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:27700 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT InterZone AS gsscode, Name AS name FROM \"${SHPTABLE}\""

# https://www.nisra.gov.uk/support/geography/northern-ireland-output-areas
# https://www.nisra.gov.uk/sites/nisra.gov.uk/files/publications/OA_ni%20ESRI.zip

SRCDIR="nisra-oa"
SRCFILE="${DATAROOT}/${SRCDIR}/OA_ni.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:29902 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT OA_CODE AS code FROM \"${SHPTABLE}\""

# https://www.nisra.gov.uk/support/geography/northern-ireland-small-areas
# https://www.nisra.gov.uk/sites/nisra.gov.uk/files/publications/SA2011_Esri_Shapefile_0.zip

SRCDIR="nisra-sa"
SRCFILE="${DATAROOT}/${SRCDIR}/SA2011.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:29902 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT SA2011 AS gsscode, SA2011 as soa_code FROM \"${SHPTABLE}\""

# https://www.nisra.gov.uk/support/geography/northern-ireland-super-output-areas
# https://www.nisra.gov.uk/sites/nisra.gov.uk/files/publications/SOA2011_Esri_Shapefile_0.zip

SRCDIR="nisra-soa"
SRCFILE="${DATAROOT}/${SRCDIR}/SOA2011.shp"
SHPTABLE=$(nameify "${SRCFILE}")
echo "${SRCDIR} ..."

ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
    -progress \
    -overwrite \
    -s_srs EPSG:29902 \
    -t_srs EPSG:4326 \
    -nln "${SRCDIR//-/_}" \
    -nlt PROMOTE_TO_MULTI \
    -lco PRECISION=NO \
    -lco FID=rowid \
    -lco FID64=TRUE \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=GIST \
    -sql "SELECT SOA_CODE AS code, SOA_LABEL AS name FROM \"${SHPTABLE}\""

# https://geoportal.statistics.gov.uk/search?q=%22output%20area%20to%20ward%20to%20local%20authority%20district%22%20lookup
# https://opendata.arcgis.com/api/v3/datasets/c6a68d369782417da8d5ee5593e7cf00_0/downloads/data?format=csv&spatialRefId=4326

# SRCDIR="ons-lookups"
# SRCFILE="${DATAROOT}/${SRCDIR}/Output_Areas__December_2011__Boundaries_EW_BFC.shp"
# echo "${SRCDIR} ..."

# SRC="Output_Area_to_Ward_to_Local_Authority_District__December_2020__Lookup_in_England_and_Wales_V2"
# SRCFILE="${SRCDIR}/${SRC}.csv"
# echo "${SRC} ..."

# ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
#     -overwrite \
#     -nln "ons_lookups" \
#     -gt 10000 \
#     -lco PRECISION=NO \
#     -lco FID=rowid \
#     -lco FID64=TRUE \
#     -oo EMPTY_STRING_AS_NULL=YES \
#     -sql "SELECT oa11cd AS gsscode, wd20cd AS wd_code, wd20nm AS wd_name, lad20cd AS lad_code, lad20nm AS lad_name FROM \"${SRC}\""

# https://geoportal.statistics.gov.uk/search?q=middle%20layer%20super%20output%20to%20ward%20to%20lad%20lookup
# https://opendata.arcgis.com/api/v3/datasets/a48d2d30b0b346b7a2f1c6d17f9994dd_0/downloads/data?format=csv&spatialRefId=4326

# SRC="Middle_Layer_Super_Output_Area__2011__to_Ward_to_LAD__December_2020__Lookup_in_England_and_Wales_V2"
# SRCFILE="${SRCDIR}/${SRC}.csv"
# echo "${SRC} ..."

# ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
#     -append \
#     -nln "ons_lookups" \
#     -gt 10000 \
#     -oo EMPTY_STRING_AS_NULL=YES \
#     -sql "SELECT msoa11cd AS gsscode, wd20cd AS wd_code, wd20nm AS wd_name, lad20cd AS lad_code, lad20nm AS lad_name FROM \"${SRC}\""

# https://geoportal.statistics.gov.uk/search?q=lower%20layer%20super%20output%20area%20to%20ward%20to%20lad%20lookup
# https://opendata.arcgis.com/api/v3/datasets/6408273b5aff4e01ab540a1b1b95b7a7_0/downloads/data?format=csv&spatialRefId=4326

# SRC="Lower_Layer_Super_Output_Area_(2011)_to_Ward_(2020)_to_LAD_(2020)_Lookup_in_England_and_Wales_V2"
# SRCFILE="${SRCDIR}/${SRC}.csv"
# echo "${SRC} ..."

# ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
#     -append \
#     -nln "ons_lookups" \
#     -gt 10000 \
#     -oo EMPTY_STRING_AS_NULL=YES \
#     -sql "SELECT lsoa11cd AS gsscode, wd20cd AS wd_code, wd20nm AS wd_name, lad20cd AS lad_code, lad20nm AS lad_name FROM \"${SRC}\""

# https://www.nrscotland.gov.uk/statistics-and-data/geography/our-products/census-datasets/2011-census/2011-boundaries
# https://www.nrscotland.gov.uk/files/geography/output-area-2011-mhw.zip

# DSN="${DSN} active_schema=public schemas=public"
# SRCDIR="./data/wof"
# SRC="whosonfirst-data-admin-gb-latest"
# SRCFILE="${SRCDIR}/${SRC}.spatial.db"
# for layer in name place; do
#     echo "${SRC}:${layer} ..."
#     ogr2ogr -f "PostgreSQL" PG:"${DSN}" "${SRCFILE}" \
#         -progress \
#         -overwrite \
#         --config SQLITE_LIST_ALL_TABLES YES \
#         -s_srs EPSG:4326 \
#         -t_srs EPSG:4326 \
#         -nln "wof_${layer}" \
#         -lco FID=rowid \
#         -lco FID64=TRUE \
#         -lco SCHEMA=public \
#         -lco GEOMETRY_NAME=geom \
#         -lco SPATIAL_INDEX=GIST ${layer}
# done

${PSQL} --dbname "${CONNSTR}" --echo-queries -f "${REPO_ROOT}/scripts/fixup-sources.sql"
${PSQL} --dbname "${CONNSTR}" --echo-queries -f "${REPO_ROOT}/scripts/merge-places.sql"
