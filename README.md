# Paperwise

A private PDF toolkit for Android that works fully offline. Every tool runs on your phone, so your files never leave it. No ads, no tracking, no account.

Made by [Lumio Apps](https://github.com/lumio-apps).

## Download

Get the latest APK from the [Releases page](https://github.com/lumio-apps/paperwise/releases/latest). Requires Android 7.0 or newer.

After that, Paperwise updates itself: open **Settings → Check for updates**.

## Screenshots

<p align="center">
  <img src="docs/screenshots/home.jpg" width="240" alt="Home screen with tool tiles">
  &nbsp;
  <img src="docs/screenshots/files.jpg" width="240" alt="Your files screen">
  &nbsp;
  <img src="docs/screenshots/settings.jpg" width="240" alt="Settings screen">
</p>

## What's in v0.9

- **Markup**: highlight text with a see-through marker, draw with a pen, and add boxes, ovals, lines and arrows in six colors and three thicknesses. Marks are written into the PDF page, so the text underneath stays selectable.
- **Search in PDF**: find words inside a PDF. Matches are marked on the page and you can jump to the previous or next one. The search box is also in the viewer (tap the magnifier).
- A scanned PDF has no text to search until OCR arrives in v0.11.

## What's in v0.8

- **Edit & sign**: type text anywhere on a page, or draw your signature with a finger and place it. Drag to move, tap to resize, and the signature can be remembered on your phone for next time.
- **Page numbers**: top or bottom, left, center or right, in three looks (`1`, `Page 1`, `Page 1 of N`). Choose the page to start on, so a cover page can stay clean.
- **Header and footer**: add your own text to every page. Use `{n}` for the page number and `{total}` for the number of pages.
- Text is written straight into the PDF page, so the text that was already there stays selectable and searchable. Originals are never changed.
- For now added text supports letters, numbers and keyboard symbols (no accents or other scripts yet).

## What's in v0.7

- **Lock PDF**: protect a PDF with a password (AES-128). Paperwise checks that the new file opens with your password and not without it before saving. It never stores your password.
- **Unlock PDF**: type the password and get an unlocked copy. Text stays selectable.
- **Watermark**: stamp text or a picture on every page, centered or repeated, in three sizes and strengths.
- Locking and watermarking redraw pages as sharp pictures, so text in those copies can no longer be selected or searched. Originals are never changed.

## What's in v0.6

- **Compress PDF**: choose Light, Balanced or Strong and see the expected size before you start. The new file is saved next to your other files and the original is never changed.
- Pages are redrawn as pictures, so text can no longer be selected or searched in the compressed copy. It works best on scans and photo PDFs. If a PDF would not get smaller, nothing is saved.

## What's in v0.5

- **Image privacy**: pick one or many photos and see what is hidden inside them: location, phone or camera name, date and the app that edited them. Paperwise makes a clean copy that is rebuilt from the pixels only, so all of that is left behind.
- **Resize and compress**: shrink pictures to Large, Medium or Small, and choose how strongly JPG pictures are compressed.
- **Blur or hide**: drag boxes over faces, number plates or text, and choose a strong blur or a solid black box.
- Your original pictures are never changed. Everything stays on your phone.

## What's in v0.4

- **PDF to image**: save the pages of a PDF as JPG or PNG. Choose the quality (standard, high or best) and all pages or only some, like `1-3, 7`.
- **Scan to PDF**: take a photo of a page with the camera (or pick one from the gallery). Drag the four corners onto the page edges, and Paperwise straightens it. Pick a look: Original, Magic color, Black & white or Gray. Add more pages, reorder them, and make one PDF. Nothing leaves your phone.

## What's in v0.3

- **Page tools**: open a PDF as a grid of page previews. Tap pages to select them, then move them earlier or later, rotate left or right, delete them, or extract them into a new PDF. You can also hold a page and drag it to a new place. Save the result as a new file; your original PDF is never changed.

## What's in v0.2

- **PDF viewer**: read any PDF inside Paperwise. Zoom, jump to a page, see page thumbnails, and open locked PDFs with their password.
- **Continue reading**: Paperwise remembers the page you stopped on and shows a "Continue reading" card in Your files.
- **Favorites**: star the PDFs you use most and filter them in Your files.
- **Open from other apps**: choose Paperwise when you tap a PDF in your file manager, a chat app or email. Or tap "Open a PDF" in Your files.

## What's in v0.1

- **Merge PDF**: join two or more PDFs and drag them into the order you want.
- **Split PDF**: cut a PDF by page ranges (like `1-4, 5-10`) or make one file per page. A colored page grid shows which pages go into which file.
- **Image to PDF**: pick photos from the gallery or take new ones with the camera. Reorder them, then choose page size (A4, Letter, fit image), orientation and margin.
- **Your files**: every PDF you make is saved in Paperwise. Open, share, save to your phone, rename or delete it.
- **Check for updates**: asks GitHub Releases for a newer version and installs it inside the app. This is the only time Paperwise uses the internet.

## Roadmap

Paperwise grows one small update at a time, one group of features per update.

| Update | Theme | Features |
| --- | --- | --- |
| **v0.1** ✅ released | Foundation | Merge, split, image to PDF (gallery and camera), files list with open, share, save, rename and delete, update checker |
| **v0.2** ✅ released | PDF viewer | Built-in reader with zoom, page jump and thumbnails, continue reading, favorites, open PDFs from other apps |
| **v0.3** ✅ released | Page tools | Reorder, rotate, delete and extract pages on a visual page grid |
| **v0.4** ✅ released | Convert and scan | PDF to image (JPG or PNG), scan paper to PDF with the camera, manual crop and filters |
| **v0.5** ✅ released | Image privacy | Remove EXIF data (location, device info), resize, compress, blur or hide parts of a photo, batch processing |
| **v0.6** ✅ released | Compress | Light, balanced and strong PDF compression, image quality control, size estimate before saving |
| **v0.7** ✅ released | Security | Password lock, unlock with the right password, text or image watermark |
| **v0.8** ✅ released | Edit | Add text, signature, page numbers, header and footer |
| **v0.9** 🚧 in progress | Markup and search | Highlight, pen and shapes, search for words inside a PDF |
| **v0.10** | Your way | Dark mode, more languages, sort and search files, local backup and restore |
| **v0.11** | OCR | Offline text recognition for scanned pages, searchable PDFs |
| **v1.0** | Ready for F-Droid | Final polish, then F-Droid and GitHub Releases |

## Privacy

- All PDF work happens on the device with [PDFium](https://pdfium.googlesource.com/pdfium/) (through `pdfrx`) and the `pdf` package.
- Files are stored in the app's own folder until you share or save them.
- The internet permission is used only by **Check for updates**.

## Build

```sh
flutter pub get
flutter analyze
flutter build apk --release
```

Pushing a tag like `v0.1.0` builds a signed APK with GitHub Actions and publishes them on the Releases page.

## License

MIT. The bundled Outfit font is under the SIL Open Font License (see `assets/fonts/OFL.txt`).
