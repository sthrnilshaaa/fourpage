#!/usr/bin/env bash
# Phase 0 measurement run for the native reader spikes (see docs/reader/native-reader/phase0-spike-report.md).
#
# Usage: measure.sh BOOK [BOOK...]     BOOK = asset path in the test APK, e.g. pride.epub or private/x.epub
# Needs: phone connected, unlocked, screen on; test APK installed (./gradlew :reader:installDebugAndroidTest).
# Prints one CSV row per book. Raw logcat for every run goes to $OUT (default ./measure-out).
set -euo pipefail

PKG=com.fourpages.reader.nativereader.test
ENGINE=$PKG/com.fourpages.reader.nativereader.spike.EngineSpikeActivity
READIUM=$PKG/com.fourpages.reader.nativereader.spike.ReadiumSpikeActivity
RUNS=${RUNS:-5}
TURNS=${TURNS:-30}
OUT=${OUT:-./measure-out}
mkdir -p "$OUT"

# Approximate a release build: AOT-compile the debug test APK.
adb shell cmd package compile -m speed -f $PKG >/dev/null
adb shell svc power stayon true

# run NAME COMPONENT WAIT_S EXTRA...  → logcat of one cold launch saved to $OUT/NAME.log
run() {
  local name=$1 comp=$2 wait=$3; shift 3
  adb logcat -c
  adb shell am start -S -W -n "$comp" "$@" >/dev/null
  sleep "$wait"
  adb logcat -d -s ARead-Spike > "$OUT/$name.log"
}

echo "book,engine_first_open_ms,engine_cached_open_ms,engine_warm_cached_open_ms,engine_whole_book_first_ms,engine_jump_ms,engine_janky_pct,engine_p90_frame_ms,engine_pss_mb,total_pages,readium_open_ms,readium_first_page_ms,readium_positions_ms,readium_jump_ms"

for BOOK in "$@"; do
  tag=$(echo "$BOOK" | tr '/.' '__')
  for i in $(seq "$RUNS"); do run "$tag-first-$i" "$ENGINE" ${FIRST_WAIT:-15} --es book "$BOOK" --ez clearCache true; done
  for i in $(seq "$RUNS"); do run "$tag-cached-$i" "$ENGINE" 5 --es book "$BOOK"; done
  for i in $(seq "$RUNS"); do run "$tag-warm-$i" "$ENGINE" 5 --es book "$BOOK" --ez warmup true; done

  # Jumps: volume-down jumps to a random page and logs "jump".
  adb logcat -c
  adb shell am start -S -W -n "$ENGINE" --es book "$BOOK" >/dev/null; sleep 4
  for i in $(seq "$RUNS"); do adb shell input keyevent 25; sleep 1; done
  # Turns: swipes right-to-left, frame stats from gfxinfo.
  adb shell dumpsys gfxinfo $PKG reset >/dev/null
  for i in $(seq "$TURNS"); do adb shell input swipe 900 1200 150 1200 120; sleep 0.4; done
  adb shell dumpsys gfxinfo $PKG > "$OUT/$tag-gfxinfo.txt"
  adb shell dumpsys meminfo $PKG > "$OUT/$tag-meminfo.txt"
  adb logcat -d -s ARead-Spike > "$OUT/$tag-interact.log"

  for i in $(seq "$RUNS"); do run "$tag-readium-$i" "$READIUM" 10 --es book "$BOOK" --ed progression 0.5; done

  python3 - "$OUT" "$tag" "$BOOK" <<'PY'
import glob, re, statistics, sys
out, tag, book = sys.argv[1:]
def vals(pattern, event):
    v = []
    for f in sorted(glob.glob(f"{out}/{tag}-{pattern}-*.log")):
        m = re.findall(rf"ARead-Spike: {re.escape(event)} ([\d.]+)", open(f).read())
        if m: v.append(float(m[-1]))
    return v
def warm():
    v = []
    for f in sorted(glob.glob(f"{out}/{tag}-warm-*.log")):
        s = open(f).read()
        fp = re.findall(r"ARead-Spike: firstPage ([\d.]+)", s); w = re.findall(r"ARead-Spike: warmupOpen ([\d.]+)", s)
        if fp and w: v.append(float(fp[-1]) - float(w[-1]))
    return v
med = lambda v: f"{statistics.median(v):.0f}" if v else "NA"
inter = open(f"{out}/{tag}-interact.log").read()
jumps = [float(x) for x in re.findall(r"ARead-Spike: jump ([\d.]+)", inter)]
gfx = open(f"{out}/{tag}-gfxinfo.txt").read()
janky = re.search(r"Janky frames: \d+ \(([\d.]+)%\)", gfx)
p90 = re.search(r"90th percentile: (\d+)ms", gfx)
mem = re.search(r"TOTAL PSS:\s+(\d+)", open(f"{out}/{tag}-meminfo.txt").read()) or \
      re.search(r"^\s*TOTAL\s+(\d+)", open(f"{out}/{tag}-meminfo.txt").read(), re.M)
pages = re.findall(r"totalPages=(\d+)", open(sorted(glob.glob(f"{out}/{tag}-first-*.log"))[0]).read())
print(",".join([
    book, med(vals("first", "firstPage")), med(vals("cached", "firstPage")), med(warm()),
    med(vals("first", "wholeBook")), med(jumps),
    janky.group(1) if janky else "NA", p90.group(1) if p90 else "NA",
    f"{int(mem.group(1)) / 1024:.0f}" if mem else "NA", pages[-1] if pages else "NA",
    med(vals("readium", "readium:open")), med(vals("readium", "readium:firstPage")),
    med(vals("readium", "readium:positions")), med(vals("readium", "readium:jump")),
]))
PY
done
