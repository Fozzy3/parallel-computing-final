#!/bin/bash
# Archives TransMilenio's open GTFS-Realtime feed (https://gtfs.transmilenio.gov.co). The feed is live only
# (no history), so every snapshot that is not saved is lost.
# One loop: positions every 10 s, alerts every 60 s, and the static GTFS.zip only when manifest.json says it
# changed. A file is saved only when it differs from the last saved one, written to a .part and then renamed.
# Cron starts it every minute and flock keeps one copy, so after a crash or a reboot it is back within a minute
# (see crontab_tm.txt). Stop it: crontab -e, delete the lines tagged tm-archive, then pkill -f archivar_tm.sh.
# Files in $base: raw/AAAA/MM/DD/<name>_<UTC>.<ext>, eventos.log (failures, feed frozen/back), estado.txt (now).
base=${TM_BASE:-$HOME/bog}
url=https://gtfs.transmilenio.gov.co
cd "$base" || exit 1

log() { echo "$(date -u +%FT%TZ) $*" >> eventos.log; }

# save NAME EXT ZIP: download NAME.EXT; if it changed, keep it in raw/ (gzip it when ZIP=1). 0 = new file saved.
save() {
    local tmp=.$1.new last=.$1.last code rc d out
    code=$(curl -sS -L -m 20 --retry 2 --retry-delay 2 --retry-all-errors -o "$tmp" -w '%{http_code}' \
        "$url/$1.$2" 2>.curl.err)
    rc=$?
    if [ $rc -ne 0 ] || [ "$code" != 200 ]; then
        log "$1 fail curl=$rc http=$code $(tail -n 1 .curl.err | head -c 200)"
        return 1
    fi
    cmp -s "$tmp" "$last" && return 2 # not refreshed since the last saved snapshot
    d=raw/$(date -u +%Y/%m/%d)
    mkdir -p "$d"
    out=$d/$1_$(date -u +%Y%m%dT%H%M%SZ).$2
    if [ "$3" = 1 ]; then
        out=$out.gz
        gzip -c "$tmp" > "$out.part"
    else
        cp "$tmp" "$out.part"
    fi && mv "$out.part" "$out" && cp "$tmp" "$last"
}

# version of GTFS.zip announced in manifest.json (empty if the manifest fails)
gtfs_version() {
    curl -sf -m 20 "$url/manifest.json" | python3 -c \
        'import json,sys; print(next(f["last_modified"] for f in json.load(sys.stdin)["files"] if f["file_name"]=="GTFS.zip"))' \
        2>/dev/null
}

log "start pid $$"
alerts_at=0
manifest_at=0
changed_at=$(date +%s)
frozen=0
while :; do
    t=$(date +%s)
    if save positions pb 1; then
        [ "$(stat -c %s .positions.new)" -lt 20000 ] && log "positions almost empty: $(stat -c %s .positions.new) bytes"
        [ $frozen = 1 ] && log "positions back after $(( (t - changed_at) / 60 )) min frozen"
        changed_at=$t
        frozen=0
    elif [ $frozen = 0 ] && [ $(( t - changed_at )) -ge 300 ]; then
        log "positions frozen since $(date -u -d @$changed_at +%FT%TZ)" # the publisher stopped refreshing
        frozen=1
    fi
    if [ $(( t - alerts_at )) -ge 60 ]; then
        save alerts pb 1
        alerts_at=$t
    fi
    if [ $(( t - manifest_at )) -ge 600 ]; then # GTFS.zip weighs ~118 MB: download it in the background, only when new
        manifest_at=$t
        v=$(gtfs_version)
        if [ -n "$v" ] && [ "$v" != "$(cat .gtfs.version 2>/dev/null)" ]; then # a failed download retries in 10 min
            ( save GTFS zip 0 && echo "$v" > .gtfs.version && log "GTFS.zip saved, version $v" ) &
        fi
    fi
    printf 'last poll       %s\nlast change     %s\nfrozen          %s\npositions today %s\n' \
        "$(date -u -d @$t +%FT%TZ)" "$(date -u -d @$changed_at +%FT%TZ)" $frozen \
        "$(ls raw/$(date -u +%Y/%m/%d) 2>/dev/null | grep -c ^positions)" > estado.txt
    sleep $(( 10 - ($(date +%s) - t) > 1 ? 10 - ($(date +%s) - t) : 1 ))
done
