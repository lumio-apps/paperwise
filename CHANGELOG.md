# Changelog

What changed in each version of Paperwise, newest first.

## v1.1.0

- **Check for updates is back** (Settings). Paperwise asks GitHub for the newest release, downloads the APK and opens the installer. It only does this when you tap the button. The internet permission is used for nothing else.
- Releases now contain only the `.apk` (no more `.aab`).

## v1.0.1

- A screen that fails to draw now shows what went wrong instead of a blank grey page.
- Clearer message when a PDF search finds nothing.

## v1.0

- Ready for Google Play: the app has no internet permission at all and the in-app updater is gone. Releases now also include a signed `.aab` bundle for Play.
- Privacy policy: [PRIVACY.md](PRIVACY.md). Store listing text and checklist: [docs/play-store/listing.md](docs/play-store/listing.md).

## v0.11

- **Text from scans (OCR)**: read the words on scanned pages, on your phone, with no internet. Text recognition uses the ML Kit model that is bundled inside the app. English only for now.
- **Searchable PDF**: your scan stays exactly as it is, and the words are added invisibly behind it, so you can search and copy from the PDF. Pages that already contain text are skipped.
- **Copy text**: shows the text of the whole PDF so you can copy or share it.

## v0.10

- **Dark mode**: light, dark, or follow the phone. Your choice is remembered.
- **Languages**: English and Hindi (हिन्दी) for the main screens. The tool screens are still English and will follow.
- **Files**: search by name and sort by newest, oldest, name or size.
- **Backup and restore**: save all your PDFs, reading list and signature in one `.pwbackup` file, and bring them back on this or a new phone. Nothing is uploaded; you choose where the file goes.

## v0.9

- **Markup**: highlight text with a see-through marker, draw with a pen, and add boxes, ovals, lines and arrows in six colors and three thicknesses. Marks are written into the PDF page, so the text underneath stays selectable.
- **Search in PDF**: find words inside a PDF. Matches are marked on the page and you can jump to the previous or next one. The search box is also in the viewer (tap the magnifier).
- A scanned PDF has no text to search until OCR arrives in v0.11.

## v0.8

- **Edit & sign**: type text anywhere on a page, or draw your signature with a finger and place it. Drag to move, tap to resize, and the signature can be remembered on your phone for next time.
- **Page numbers**: top or bottom, left, center or right, in three looks (`1`, `Page 1`, `Page 1 of N`). Choose the page to start on, so a cover page can stay clean.
- **Header and footer**: add your own text to every page. Use `{n}` for the page number and `{total}` for the number of pages.
- Text is written straight into the PDF page, so the text that was already there stays selectable and searchable. Originals are never changed.
- For now added text supports letters, numbers and keyboard symbols (no accents or other scripts yet).

## v0.7

- **Lock PDF**: protect a PDF with a password (AES-128). Paperwise checks that the new file opens with your password and not without it before saving. It never stores your password.
- **Unlock PDF**: type the password and get an unlocked copy. Text stays selectable.
- **Watermark**: stamp text or a picture on every page, centered or repeated, in three sizes and strengths.
- Locking and watermarking redraw pages as sharp pictures, so text in those copies can no longer be selected or searched. Originals are never changed.

## v0.6

- **Compress PDF**: choose Light, Balanced or Strong and see the expected size before you start. The new file is saved next to your other files and the original is never changed.
- Pages are redrawn as pictures, so text can no longer be selected or searched in the compressed copy. It works best on scans and photo PDFs. If a PDF would not get smaller, nothing is saved.

## v0.5

- **Image privacy**: pick one or many photos and see what is hidden inside them: location, phone or camera name, date and the app that edited them. Paperwise makes a clean copy that is rebuilt from the pixels only, so all of that is left behind.
- **Resize and compress**: shrink pictures to Large, Medium or Small, and choose how strongly JPG pictures are compressed.
- **Blur or hide**: drag boxes over faces, number plates or text, and choose a strong blur or a solid black box.
- Your original pictures are never changed. Everything stays on your phone.

## v0.4

- **PDF to image**: save the pages of a PDF as JPG or PNG. Choose the quality (standard, high or best) and all pages or only some, like `1-3, 7`.
- **Scan to PDF**: take a photo of a page with the camera (or pick one from the gallery). Drag the four corners onto the page edges, and Paperwise straightens it. Pick a look: Original, Magic color, Black & white or Gray. Add more pages, reorder them, and make one PDF. Nothing leaves your phone.

## v0.3

- **Page tools**: open a PDF as a grid of page previews. Tap pages to select them, then move them earlier or later, rotate left or right, delete them, or extract them into a new PDF. You can also hold a page and drag it to a new place. Save the result as a new file; your original PDF is never changed.

## v0.2

- **PDF viewer**: read any PDF inside Paperwise. Zoom, jump to a page, see page thumbnails, and open locked PDFs with their password.
- **Continue reading**: Paperwise remembers the page you stopped on and shows a "Continue reading" card in Your files.
- **Favorites**: star the PDFs you use most and filter them in Your files.
- **Open from other apps**: choose Paperwise when you tap a PDF in your file manager, a chat app or email. Or tap "Open a PDF" in Your files.

## v0.1

- **Merge PDF**: join two or more PDFs and drag them into the order you want.
- **Split PDF**: cut a PDF by page ranges (like `1-4, 5-10`) or make one file per page. A colored page grid shows which pages go into which file.
- **Image to PDF**: pick photos from the gallery or take new ones with the camera. Reorder them, then choose page size (A4, Letter, fit image), orientation and margin.
- **Your files**: every PDF you make is saved in Paperwise. Open, share, save to your phone, rename or delete it.
- _(The in-app updater was removed in v1.0 and came back in v1.1.0.)_
