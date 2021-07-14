#!/usr/bin/env bash
#shellcheck shell=bash disable=SC2207

SRCROOT=$(pwd)/data/archives
DSTROOT=$(pwd)/data/sources

for record in $(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' source-manifest.json); do
    entry=($(echo "$record" | tr '=' ' '))
    srcfile=${SRCROOT}/${entry[1]}
    destdir=${DSTROOT}/${entry[0]}
    echo "Unpacking ${entry[0]} ..."
    mkdir -p "${destdir}"
    unzip -q -j -o "${srcfile}" -d "${destdir}"
done
