#!/bin/bash
# Archives TransMilenio's open GTFS-Realtime feed (https://gtfs.transmilenio.gov.co): one gzip per new snapshot.
# The feed is live only (no history), so every snapshot that is not saved is lost.
# Runs from cron on the PhD VM (see crontab_tm.txt). Stop it: crontab -e, delete the line tagged tm-archive.
# usage: archivar_tm.sh positions|alerts
f=$1
base=$HOME/bog
tmp=$base/.$f.new
last=$base/.$f.last
if ! curl -sfL -m 15 -o "$tmp" "https://gtfs.transmilenio.gov.co/$f.pb"; then
    echo "$(date -u +%FT%TZ) $f fail" >> "$base/fail.log"
    exit 1
fi
cmp -s "$tmp" "$last" && exit 0 # the feed has not been refreshed since the last saved snapshot
d=$base/raw/$(date -u +%Y/%m/%d)
mkdir -p "$d"
cp "$tmp" "$last" && gzip -c "$tmp" > "$d/${f}_$(date -u +%Y%m%dT%H%M%SZ).pb.gz"
