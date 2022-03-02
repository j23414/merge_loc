# Processing new locations

```
NEW_RUN=mergeloc_Feb28

# Setup Repos
[[ -d Ingest_Locations ]] || mkdir Ingest_Locations
cd Ingest_Locations

git clone https://github.com/j23414/merge_loc.git  # For manual annotation, but remove later

git clone https://github.com/nextstrain/ncov-ingest.git
git clone https://github.com/nextstrain/ncov.git
cd ncov-ingest
git branch ${NEW_RUN}      # For gisaid/genbank_annotations.txt
git checkout ${NEW_RUN}
cd ../ncov
git branch ${NEW_RUN}       # For defaults/colors lat_long.txt
git checkout ${NEW_RUN}

# Pull existing s3 datasets
nextstrain remote download s3://nextstrain-ncov-private/metadata.tsv.gz /dev/stdout | gunzip > data/downloaded_gisaid.tsv
nextstrain remote download s3://nextstrain-data/files/ncov/open/metadata.tsv.gz /dev/stdout | gunzip > data/metadata_genbank.tsv

# Pull data from slack
mkdir -p scripts/curate_metadata/inputs_new_sequences
```

## For new locations, download from slack:

From the `#ncov-gisaid-updates` slack channel, download:

* `additional-info-changes.txt`
* (download all or in batches of 10) or rename 10> with a 9 prefix

Place the above files in `ncov/scripts/curate_metadata/inputs_new_sequences`.

Tag with Greenbox emoji to indicate it's been downloaded. Will replace with Greencheckmark emoji to indicate it's been merged.

## Run parse additional info

From the `ncov` folder, run:

```
python scripts/curate_metadata/parse_additional_info.py --auto 

ls -l scripts/curate_metadata/outputs_new_sequences  # View output files
#> -rw-r--r--  1 jenchang  staff    59K Jan 12 12:18 omicron_additional_info.txt # don't worry
#> -rw-r--r--  1 jenchang  staff    51K Jan 12 12:18 additional_info_annotations.tsv # added to top of files
```

Add to top of gisaid_annotations

```
cat scripts/curate_metadata/outputs_new_sequences/additional_info_annotations.tsv > temp.txt
echo "" >> temp.txt
cat ../ncov-ingest/source-data/gisaid_annotations.tsv >> temp.txt
cat temp.txt | grep "^$" > a.txt # Remove empty lines
mv a.txt ../ncov-ingest/source-data/gisaid_annotations.tsv
```

## Run curate metadata

```
cp ../merge_loc/manualAnnotationRules.txt scripts/curate_metadata/config_curate_metadata/manualAnnotationRules.txt
python scripts/curate_metadata/curate_metadata.py 
```

In top, at division region, may need to add manual annotation rules. Quit and rerun after editing file.

```
# Fix Delimiters errors (Austrian case)
vscode scripts/curate_metadata/config_curate_metadata/manualAnnotationRules.txt
```

For example:

```
Europe,Austria,Upper Austria / Voecklabruck / Voecklamarkt,             Europe,Austria,Upper Austria,Voecklamarkt
Europe,Austria,Upper Austria / Voecklabruck / Frankenburg Am Hausruck,  Europe,Austria,Upper Austria,Frankenburg Am Hausruck
```

Notice the middle delimiter ",\t"

```
# Fix other geolocation errors (change spelling, or resolution, or duplicates, missing county, Porto Rico needs to change to USA)
# Save to check.txt (double check later)


grep -i "Unknown location name" defaults/color_ordering.tsv 
less defaults/color_ordering.tsv  # Search for country, might be different spelling

# search country, division (a instead of n/y)
emacs scripts/curate_metadata/config_curate_metadata/geoLocationRules.txt
```
Example

```
Current place for missing division:	Kosice - Okolie, Slovakia
Geopy suggestion: District of Košice - okolie, Region of Košice, Slovakia
Is this the right place (a - alter division level) [y/n/a]? a
Type correct division to produce corrective rule: Kosice
Europe/Slovakia/Kosice - Okolie/	Europe/Slovakia/Kosice/Kosice - Okolie
```

Copy last line to `geoLocationRules.txt`.

Then skip all check, and rerun to apply new rules:

```
python scripts/curate_metadata/curate_metadata.py 
```

After it's done:

```
ls -ltr scripts/curate_metadata/output_curate_metadata/
total 49040
-rw-r--r--  1 jenchang  staff   622K Jan 12 12:25 lat_longs.tsv # ncov
-rw-r--r--  1 jenchang  staff   486K Jan 12 12:25 color_ordering.tsv #ncov in defaults
-rw-r--r--  1 jenchang  staff    23M Jan 12 12:27 gisaid_annotations.tsv
-rw-r--r--  1 jenchang  staff   124K Jan 12 12:27 genbank_annotations.tsv
```

```
cp scripts/curate_metadata/output_curate_metadata/lat_longs.tsv defaults/.
cp scripts/curate_metadata/output_curate_metadata/color_ordering.tsv defaults/.
cp scripts/curate_metadata/output_curate_metadata/gisaid_annotations.tsv ../ncov-ingest/source-data/.
cp scripts/curate_metadata/output_curate_metadata/genbank_annotations.tsv ../ncov-ingest/source-data/.
```

## geoLocationRules

Add to rules to bottom of the files.

```
echo "" >> ../ncov-ingest/source-data/gisaid_geoLocationRules.tsv 
cat scripts/curate_metadata/config_curate_metadata/geoLocationRules.txt >> ../ncov-ingest/source-data/gisaid_geoLocationRules.tsv
```

> If you ever add rules to the `source-data/gisaid_geoLocationRules.tsv` file, new rules always have to be added to the bottom of the file. Then you can run the following to apply new changes and resolve conflicts

```
cd ../ncov-ingest
bin/check-gisaid-geoRules --geo-location-rules source-data/gisaid_geoLocationRules.tsv --output-file gisaid_geoLocationRules.tsv
```

```
bin/check-gisaid-geoRules \
  --geo-location-rules source-data/gisaid_geoLocationRules.tsv \
 --output-file gisaid_geoLocationRules.tsv

Traceback (most recent call last):
  File "/Users/jenchang/Desktop/2022-02-17/ncov-ingest/bin/check-gisaid-geoRules", line 7, in <module>
    from utils.transform import (
ModuleNotFoundError: No module named 'utils.transform'
```

### Only on MY computer

Since I tried to install `pango` whose `utils` is masking the local one. Create a temporary workaround till I can fix my environment.

```
cd ncov-ingest
cp -r lib/utils lib/utils2
cat bin/check-gisaid-geoRules |\
  sed 's/utils./utils2./g' > \
  bin/jc_check-gisaid-geoRules
  
cat lib/utils2/lib/utils2/transform.py |\
  sed 's/utils./utils2./g' > \
  temp.txt
mv temp.txt lib/utils2/lib/utils2/transform.py
```

Then run:

```
python3 bin/jc_check-gisaid-geoRules \
  --geo-location-rules source-data/gisaid_geoLocationRules.tsv \
 --output-file gisaid_geoLocationRules.tsv
 
mv gisaid_geoLocationRules.tsv source-data

git diff
#>	modified:   source-data/genbank_annotations.tsv
#>	modified:   source-data/gisaid_annotations.tsv
```

rerun curate

```
python scripts/curate_metadata/curate_metadata.py 
```

* Check duplicates
* Check rules

Examples:

```
Iowa found as both division and location within division Wisconsin.

More straightforward:
Jhalokati found as both division and location within division Khulna.
Asia/Bangladesh/Jhalokati/	Asia/Bangladesh/Khulna/Jhalokati
# add to geolocational rules
```

Go back to "curate" rerun to check rules again.


<!-- OLD NOTES

## Pull s3 datasets

From within `ncov`.

```
nextstrain remote download s3://nextstrain-ncov-private/metadata.tsv.gz /dev/stdout | gunzip > data/downloaded_gisaid.tsv
nextstrain remote download s3://nextstrain-data/files/ncov/open/metadata.tsv.gz /dev/stdout | gunzip > data/metadata_genbank.tsv
```

Which sometimes gives me `gunzip: (stdin): trailing garbage ignored` messages.

> Maybe pull all files from a nextstrain remote download s3:XXXXXX` command?
> 
> Right now it's a tmp file: 
> 
> * https://github.com/nextstrain/ncov-ingest/blob/04ca33cbed1f96320035b9f7ebcc6abf4fa25a72/bin/notify-on-additional-info-change#L29
> * https://github.com/nextstrain/ncov-ingest/blob/ac98385fd086dfb977b8ffe77ae7f000f6f398be/Snakefile#L386
> 
> There should be a way to concatinate the last few days into one file, instead of scrolling in slack to download each one/process each one individually (marked with green box/check)



With key messages being:

```
grep "Remember to replace" full_output.txt

New lat_longs written out to scripts/curate_metadata/output_curate_metadata/lat_longs.tsv. Remember to replace the old file in defaults/.
Attention: color_ordering.tsv was altered! Remember to replace the old file in defaults/.
Attention: exclude.txt was altered! Remember to replace the old file in defaults/.
Attention: color_ordering.tsv was altered! Remember to replace the old file in defaults/.

Writing updated annotation files to scripts/curate_metadata/output_curate_metadata/...
Attention: gisaid_annotations.tsv was altered! Remember to replace the old file in ../ncov-ingest/source-data/.
Attention: genbank_annotations.tsv was altered! Remember to replace the old file in ../ncov-ingest/source-data/.
```

* `scripts/curate_metadata/output_curate_metadata/lat_longs.tsv`
* `color_ordering.tsv`
* `exclude.txt` 

```
Attention: gisaid_annotations.tsv was altered! Remember to replace the old file in ../ncov-ingest/source-data/.
Attention: genbank_annotations.tsv was altered! Remember to replace the old file in ../ncov-ingest/source-data/.
```

```
-->

<!--
Compare with `ncov-ingest`

```
 ls -ltr ../ncov-ingest/source-data/
total 174520
-rw-r--r--  1 jenchang  staff    58M Jan 12 12:05 accessions.tsv
-rw-r--r--  1 jenchang  staff   124K Jan 12 12:05 genbank_annotations.tsv
-rw-r--r--  1 jenchang  staff    23M Jan 12 12:05 gisaid_annotations.tsv
-rw-r--r--  1 jenchang  staff   3.1M Jan 12 12:05 gisaid_geoLocationRules.tsv
-rw-r--r--  1 jenchang  staff   830K Jan 12 12:05 location_hierarchy.tsv
-rw-r--r--  1 jenchang  staff   769B Jan 12 12:05 us-state-codes.tsv
```
-->

<!--

**2022-02-14**

```
Writing updated annotation files to scripts/curate_metadata/output_curate_metadata/...
Attention: gisaid_annotations.tsv was altered! Remember to replace the old file in ../ncov-ingest/source-data/.
No changes to genbank_annotations.tsv.
```

Merge files

```
cd ../ncov-ingest
git branch mergeloc_jen
git checkout mergeloc_jen
cp ../ncov/scripts/curate_metadata/output_curate_metadata/gisaid_annotations.tsv source-data/.
cp ../ncov/scripts/curate_metadata/output_curate_metadata/genbank_annotations.tsv source-data/.
git  commit -m "add: annotation updates from Feb 8 2022" source-data/gisaid_annotations.tsv
cd ../ncov

# Archive last run, in separate directory in case ncov has an update
ARCHIVE_DIR="../archive/2022-02-08"
mkdir -p ${ARCHIVE_DIR}
mv scripts/curate_metadata/output_curate_metadata ${ARCHIVE_DIR}/.
mv scripts/curate_metadata/inputs_new_sequences ${ARCHIVE_DIR}/.
# maybe capture log messages (tee?)

# Get ready for next run 
mkdir -p scripts/curate_metadata/inputs_new_sequences
```

```
cp scripts/curate_metadata/output_curate_metadata/gisaid_annotations.tsv ../ncov-ingest/source-data/.
cp scripts/curate_metadata/output_curate_metadata/genbank_annotations.tsv ../ncov-ingest/source-data/.
cp scripts/curate_metadata/output_curate_metadata/lat_longs.tsv defaults/lat_longs.tsv 
```
-->
