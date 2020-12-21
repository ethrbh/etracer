#!/bin/bash

# This script gives the version of the tool.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILE_TO_CHECK=${SCRIPT_DIR}/../Makefile

version=$(grep "\<PROJECT_VERSION\>" ${FILE_TO_CHECK} | awk -F"=" '{ print $2 }' | sed -e 's/\r//g')
version=$(echo ${version} | tr -d "[:space:]")
echo "${version}"
