# Paperwise TODO

New features and fixes planned for Paperwise, grouped by version. Paperwise stays **Android only, fully offline, no ads, no account**. The only network use is the manual "Check for updates" button.

Effort: **S** = a few hours, **M** = about a day, **L** = several days.
Package: a new dependency is named when one is needed. Everything else uses what the app already has (`pdfrx`, `pdf`, `image`, `pointycastle`, ML Kit).

## Already done

- [x] v1.0: merge, split, page tools, PDF to image, scan to PDF, image to PDF, image privacy, compress, protect, edit and sign, markup, search, files list, favorites
- [x] v1.1: text from scans (OCR, English), dark mode, Hindi/English, backup and restore, in-app update check
- [x] v1.1.3: PDF viewer crash fixed
- [x] v1.1.4: neumorphic look and micro-animations
- [x] v1.1.5: Reduce effects setting
- [x] Already in the app: page numbers (Edit & sign), header and footer, extract pages (Page tools)
- [x] v1.2.0: PDF info and metadata cleaner
- [x] v1.2.1: Reader night mode (zoom and last page were already remembered or built in)
- [x] v1.3.0: Share to Paperwise
- [x] v1.3.1: New flat Clean list look (replaces neumorphic and Reduce effects)
- [x] v1.4.0: Images from PDF
- [x] v1.5.0: Pages per sheet
- [x] v1.6.0: ID card to PDF

## v1.2: Everyday polish (small, high value)

- [ ] **Page numbers: start number** (S): number from any value (for example start at 5). Position, size, first page and style already exist.
- [ ] **Reader: outline and bookmarks** (M): show the PDF's table of contents and let people add their own bookmarks.
- [ ] **Files: select many** (M): long press to select, then share, delete or merge together.
- [ ] **Hindi for all tool screens** (M): today only the main screens are translated.

## v1.3: More PDF tools

- [ ] **Scan filters** (M): Original, Grayscale, Black and white, Enhanced. Plus manual crop and straighten after each scan.
- [ ] **Crop and resize pages** (M): trim margins, or fit pages to A4 or Letter.
- [ ] **Flatten PDF** (S): make notes and stamps part of the page so they cannot be moved.
- [ ] **Signature upgrades** (M): several saved signatures and initials, add today's date next to a signature.
- [ ] **Compress presets** (S): "Under 1 MB", "Under 200 KB" targets for forms and uploads.

## v1.4: Text and languages

- [ ] **OCR in more scripts** (L): Hindi (Devanagari), Chinese, Japanese, Korean. Package: the matching ML Kit text recognition models. Each one makes the app bigger, so offer them as separate choices and show the size cost.
- [ ] **Export text** (S): save recognized or existing text as a `.txt` file.
- [ ] **Search all my PDFs** (L): an offline index of the text in every PDF inside Paperwise, with results that jump to the page.
- [ ] **More app languages** (M): Armenian, Tamil, Bengali, Marathi and others. The `.tr` map in `strings.dart` may be worth replacing with `.arb` files (`flutter gen-l10n`) as the list grows.

## v1.5: Privacy and safety

- [ ] **App lock** (M): fingerprint or face unlock when opening Paperwise. Package: `local_auth`.
- [ ] **Safe redaction** (M): finish and expose the redact tool so text under a black box is really removed, not only covered. Add "Find and redact" for words like phone numbers.
- [ ] **Verify updates** (S): check the downloaded APK against the SHA-256 that GitHub shows for the release file before installing.
- [ ] **Smaller APK** (M): the APK is about 108 MB because it carries every CPU type. Publish a smaller arm64 APK and teach "Check for updates" to pick the right file for the phone.
- [ ] **Clean temporary files** (S): a storage screen that shows what Paperwise uses and clears temporary copies.

## v1.6: Workflow

- [ ] **Folders and tags** (L): organize files inside Paperwise, with a filter row on the Files page.
- [ ] **App shortcuts** (S): long press the app icon for Scan, Merge, Compress.
- [ ] **Quick tile and home widget** (M): one tap to scan.
- [ ] **Save location** (M): choose a folder on the phone for results instead of only "Save to phone".
- [ ] **Batch compress and batch protect** (M): run one tool on many files.

## v2.0: Bigger ideas (research first)

- [ ] **Fill PDF forms** (L): tap fields in forms and type. Needs a check of what `pdfrx` supports.
- [ ] **Edit stamps and notes after saving** (L): move, resize or delete things added earlier with Edit and sign or Markup.
- [ ] **Compare two PDFs** (L): show what changed between two versions.
- [ ] **Digital signatures with a certificate** (L): sign with a `.p12` file and show if a signature is valid.
- [ ] **PDF/A export** (L): archive format for official use.
- [ ] **Tablet layout** (M): two columns and a side rail for big screens.

## Housekeeping

- [ ] Remove the `docs/play-store/` folder (Paperwise is GitHub only).
- [ ] Remove the leftover `.aab` file from the v1.1.0 release on GitHub.
- [ ] Take new README screenshots in the neumorphic look (light, dark and Reduce effects).
- [ ] Remove the unused `plannedUpdates` list in `lib/tools.dart`.
- [ ] Add `flutter test` to CI, starting with tests for page ranges, the PDF stamper and backup files.
- [ ] Check the app with TalkBack: labels on icon buttons, tap sizes, and contrast in both looks.

## Suggested order

1. **v1.2** first: reader bookmarks, many-file selection, share to Paperwise. All small, all visible.
2. **v1.3** next: ID card to PDF and scan filters are the features most people ask for.
3. **v1.5** before bigger work: verified updates and the smaller APK make updating safer and faster.

Ideas are welcome: [open an issue](https://github.com/lumio-apps/paperwise/issues).
