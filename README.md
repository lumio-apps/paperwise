<h1 align="center">Paperwise</h1>

<p align="center">
  <b>Private PDF tools for Android. Fully offline.</b><br>
  Merge, split, sign, scan, compress, protect, search and clean PDFs, all on your phone.<br>
  No ads. No account. No tracking. Your files never leave your phone.
</p>

<p align="center">
  <a href="https://github.com/lumio-apps/paperwise/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/lumio-apps/paperwise?color=4338CA&label=release"></a>
  <img alt="Android 7.0+" src="https://img.shields.io/badge/Android-7.0%2B-15803D">
  <img alt="Works offline" src="https://img.shields.io/badge/works-offline-0E7490">
  <img alt="No ads" src="https://img.shields.io/badge/ads-none-BE185D">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-334155"></a>
</p>

<p align="center">
  <img src="docs/screenshots/home.jpg" width="190" alt="Home screen with colorful tool tiles">
  &nbsp;
  <img src="docs/screenshots/tools.jpg" width="190" alt="More tools: Text from scans, Protect, Edit and sign, Markup, Search">
  &nbsp;
  <img src="docs/screenshots/files.jpg" width="190" alt="Your files with search and sort">
  &nbsp;
  <img src="docs/screenshots/settings-dark.jpg" width="190" alt="Settings in dark mode">
</p>

## Why Paperwise

Most PDF apps upload your files, show ads or ask you to sign in. Paperwise does none of that. Every tool runs on your phone. The only time the app uses the internet is when you tap **Check for updates**, which asks GitHub for the newest version. Your documents are never uploaded. The code is open, so you can check that for yourself.

## What you can do

| | Tool | What it does |
| --- | --- | --- |
| 🔗 | **Merge PDF** | Join PDFs into one and drag them into the order you want |
| ✂️ | **Split PDF** | Cut by page ranges (`1-4, 5-10`) or make one file per page |
| 🧩 | **Page tools** | Reorder, rotate, delete and extract pages on a visual page grid |
| 🖼️ | **Image to PDF** | Turn photos from the gallery or camera into a PDF (A4, Letter or fit image) |
| 📤 | **PDF to image** | Save pages as JPG or PNG, all pages or just some |
| 📷 | **Scan to PDF** | Photograph paper, straighten it with the four corners, pick a look and build a PDF |
| 🗜️ | **Compress** | Light, Balanced or Strong, with the expected size shown first |
| 🔤 | **Text from scans** | Make scanned PDFs searchable, or copy their text (offline, English) |
| 🔒 | **Protect** | Lock with a password (AES-128), unlock, or add a text or image watermark |
| ✍️ | **Edit & sign** | Type text anywhere, draw and place your signature, add page numbers, headers and footers |
| 🖍️ | **Markup** | Highlighter, pen, boxes, ovals, lines and arrows in six colors |
| 🔎 | **Search in PDF** | Find words inside a PDF and jump between matches |
| 🧾 | **PDF info** | See the author, software and dates inside a PDF and save a clean copy without them |
| 🛡️ | **Image privacy** | Remove hidden location and device info from photos, blur faces or number plates |

**Also built in**

- A PDF reader with zoom, page jump, thumbnails, "Continue reading", favorites and a night reading mode
- Open PDFs straight from your file manager, chat apps or email ("Open with Paperwise")
- Search and sort your files by newest, oldest, name or size
- A soft "neumorphic" look in light, dark or system theme, in English and Hindi (हिन्दी)
- **Reduce effects** switch in Settings: flat panels with no shadows or animations, handy on older phones
- Backup and restore in one `.pwbackup` file (you choose where it goes)

Your original files are never changed. Every tool saves a new copy.

## Install

**From GitHub:** download the latest `.apk` from the [Releases page](https://github.com/lumio-apps/paperwise/releases/latest), open it on your phone and allow installs from your browser or file manager when Android asks. Requires Android 7.0 or newer.

To update later, open **Settings → Check for updates**. Paperwise asks GitHub for the newest release, downloads the APK and hands it to Android to install over the old one. It only does this when you tap the button.

## Good to know

- **Text from scans** reads English text. It adds the words invisibly behind your scan, so the scan looks exactly the same but becomes searchable. Clear, straight scans work best.
- **Lock, Watermark and Compress** redraw each page as a picture. Text in those copies can no longer be selected. Edit & sign, Markup and Unlock keep the text selectable.
- Text you add with **Edit & sign** supports letters, numbers and keyboard symbols (no accents or other scripts yet).
- Hindi covers the main screens. Tool screens are still in English.
- **PDF info** makes a clean copy by rebuilding the PDF page by page. The text stays selectable, but bookmarks, links and form fields are not kept.

## Privacy

- Everything happens on your phone. Files you pick are read locally and results are saved in the app's own storage.
- The internet is used only when you tap Check for updates. No ads, no analytics, no account.
- Passwords are used only to lock the file and are never stored.
- Full policy: [PRIVACY.md](PRIVACY.md)

## Build from source

You need [Flutter](https://docs.flutter.dev/get-started/install) (stable) and the Android SDK.

```sh
flutter pub get
flutter analyze
flutter run                    # on a connected phone or emulator
flutter build apk --release    # signed with the debug key unless android/key.properties exists
```

**Releases:** pushing a tag like `v1.0.0` runs GitHub Actions, which builds the APK, signs it with the Lumio release key from repository secrets and publishes it on the Releases page.

## Built with

- [Flutter](https://flutter.dev) and Material 3
- [PDFium](https://pdfium.googlesource.com/pdfium/) through [`pdfrx`](https://pub.dev/packages/pdfrx) for reading, rendering and page assembly
- [`pdf`](https://pub.dev/packages/pdf) and [`image`](https://pub.dev/packages/image) for creating PDFs and pictures
- [`pointycastle`](https://pub.dev/packages/pointycastle) for PDF encryption
- Google ML Kit text recognition (bundled, runs on the device) for scans
- [Outfit](https://fonts.google.com/specimen/Outfit) font (SIL Open Font License)

## Roadmap

Paperwise has all its core tools and keeps growing, roughly one small update at a time. See [TODO.md](TODO.md) for what is planned next, and the [changelog](CHANGELOG.md) for what changed in each version.

## Contributing

Bug reports and ideas are welcome: [open an issue](https://github.com/lumio-apps/paperwise/issues). Please do not attach private documents to issues.

## License

[MIT](LICENSE) © Lumio Apps. The bundled Outfit font is under the SIL Open Font License (see `assets/fonts/OFL.txt`).

<p align="center"><sub>Made by <a href="https://github.com/lumio-apps">Lumio Apps</a>: simple, private, open source apps.</sub></p>
