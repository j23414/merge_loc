#! /usr/bin/env bash
set -e
set -v
set -u

# === Variables to change each time
export NEW_RUN=mergeloc_Jul5
export INDIR=~/Desktop/Ingest_Locations/Downloads/2022-07-05
export MERGE_LOC=~/Desktop/Ingest_Locations/merge_loc
export DIR="build_rm_additional"

# # # Setup Repos
# # #[[ -d Ingest_Locations ]] || mkdir Ingest_Locations
# # #cd Ingest_Locations
# # #git clone https://github.com/j23414/merge_loc.git  # For manual annotation, but remove later
# # 
mkdir -p ${DIR}
cd ${DIR}
git clone https://github.com/nextstrain/ncov-ingest.git
git clone https://github.com/nextstrain/ncov.git
cd ncov-ingest
git branch ${NEW_RUN}      # For gisaid/genbank_annotations.txt
git checkout ${NEW_RUN}
#git push origin ${NEW_RUN}
cd ../ncov
git branch ${NEW_RUN}       # For defaults/colors lat_long.txt
git checkout ${NEW_RUN}
#git push origin ${NEW_RUN}

# Pull existing s3 datasets
#cd ncov # 
set +e
set +u
nextstrain remote download s3://nextstrain-ncov-private/metadata.tsv.gz /dev/stdout | gunzip > data/downloaded_gisaid.tsv
nextstrain remote download s3://nextstrain-data/files/ncov/open/metadata.tsv.gz /dev/stdout | gunzip > data/metadata_genbank.tsv
set -e
set -u

# Pull data from slack
mkdir -p scripts/curate_metadata/inputs_new_sequences
cp ${INDIR}/* scripts/curate_metadata/inputs_new_sequences/.

exit  # Fix additional_data
# This seems to take several minutes, add a timing command
date
time python scripts/curate_metadata/parse_additional_info.py --auto 
ls -ltrh scripts/curate_metadata/outputs_new_sequences
date

cat scripts/curate_metadata/outputs_new_sequences/additional_info_annotations.tsv > temp.txt
echo "" >> temp.txt
cat ../ncov-ingest/source-data/gisaid_annotations.tsv >> temp.txt
# Remove empty lines
cat temp.txt | grep -v "^$" > a.txt
mv a.txt ../ncov-ingest/source-data/gisaid_annotations.tsv

cp ${MERGE_LOC}/manualAnnotationRules.txt scripts/curate_metadata/config_curate_metadata/manualAnnotationRules.txt
#cp ../merge_loc/temp.txt scripts/curate_metadata/config_curate_metadata/geoLocationRules.txt
# Another one that takes several minutes, might be due to size of metadata though
date
python scripts/curate_metadata/curate_metadata.py
