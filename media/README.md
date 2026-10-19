# media/

Images for the README, the GitHub page and the store listings. Nothing here is
bundled into the app (app assets live in `assets/`).

The files in `screenshots/` are **placeholders**. Replace each one with a real
screenshot using the **same file name**, and the README picks it up.

| File | Show | Used in |
|---|---|---|
| `screenshots/home.png` | Home with Recent Reading filled | README, Play |
| `screenshots/library.png` | Library › All Books | README, Play |
| `screenshots/shelves.png` | Library › Shelves with 2–3 shelves (ideally mid-drag) | README, Play |
| `screenshots/reader.png` | A book page, bars hidden | README, Play |
| `screenshots/reader-controls.png` | Reader with top/bottom bars and the page strip | README, Play |
| `screenshots/highlights.png` | Selected text with the colour/Define menu | README, Play |
| `screenshots/saved.png` | Saved › Quotes or Notes | README |
| `screenshots/settings.png` | Settings (top of the page) | README |
| `banner.png` | 1280×640, GitHub social preview (repo Settings › Social preview) | GitHub |
| `feature-graphic.png` | 1024×500, Play Store feature graphic | Play |
| `icon-512.png` | 512×512, Play Store app icon | Play |

## Capturing screenshots

Use public-domain books (e.g. from Standard Ebooks or Project Gutenberg) so the
images can be published.

```sh
adb shell screencap -p /sdcard/shot.png && adb pull /sdcard/shot.png media/screenshots/home.png
```

Keep them portrait, from one phone, in the dark theme (matches the banner).
Shrink before committing, e.g. `magick home.png -resize 540x home.png`, to keep
the repo small.
