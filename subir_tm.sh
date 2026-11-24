#!/bin/bash
# Daily copy of the archive to GitHub (Fozzy3/parallel-computing-final). Runs from cron after service ends.
# Needs the deploy key ~/.ssh/tm_deploy (write access) and the ssh alias github-tm (see crontab_tm.txt).
# GTFS_*.zip stays on the VM only: ~118 MB, over GitHub's 100 MB per file limit (.gitignore).
cd "${TM_BASE:-$HOME/bog}" || exit 1
git add raw eventos.log fail.log
git diff --cached --quiet && exit 0
git commit -q -m "data: add TransMilenio GTFS-RT snapshots up to $(date -u +%FT%TZ)" &&
    git push -q origin main 2>>.push.err ||
    echo "$(date -u +%FT%TZ) github push fail $(tail -c 200 .push.err)" >> eventos.log
