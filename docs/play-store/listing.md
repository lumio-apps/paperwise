# Google Play listing for Paperwise

Everything you need to paste into Play Console. Text is in English.

## Store listing

**App name** (max 30): `Paperwise: Offline PDF Tools`

**Short description** (max 80):
`Merge, split, sign and scan PDFs. 100% offline. No ads, no account.`

**Full description** (max 4000):

```
Paperwise is a private PDF toolkit that works fully offline. Every tool runs on your phone, so your files never leave it. No ads, no tracking, no account, and no internet permission at all.

WHAT YOU CAN DO
• Merge PDF: join several PDFs into one and reorder them
• Split PDF: cut a PDF into parts, or pull out the pages you need
• Page tools: reorder, rotate, delete and extract pages on a visual grid
• Image to PDF: turn photos into a PDF
• PDF to image: save pages as JPG or PNG
• Scan to PDF: scan paper with your camera, crop and clean it up
• Compress: make big PDFs smaller for sharing, with a size preview
• Protect: lock a PDF with a password, unlock one you know the password for, add a text or image watermark
• Edit & sign: type text anywhere, draw and place your signature, add page numbers, headers and footers
• Markup: highlight, draw with a pen, add boxes, ovals, lines and arrows
• Search in PDF: find words inside a PDF
• Text from scans (OCR): make scanned PDFs searchable, or copy their text. Works offline, English text
• Image privacy: remove hidden location and device data from photos, blur or hide parts of a picture

MADE FOR PRIVACY
• Works without internet, always
• No ads, no analytics, no account
• Your originals are never changed
• Open source, so you can check it yourself

YOUR WAY
• Light, dark or system look
• English and Hindi
• Search and sort your files, mark favorites, continue where you stopped reading
• Back up your files and restore them on a new phone

Paperwise is made by Lumio Apps: simple, private, open source apps.
Source code: https://github.com/lumio-apps/paperwise
```

**Category:** Tools (alternative: Productivity)
**Tags:** PDF tools, Document scanner
**Contact email:** your developer email (shown publicly on the store page)
**Website:** https://github.com/lumio-apps/paperwise
**Privacy policy URL:** https://github.com/lumio-apps/paperwise/blob/main/PRIVACY.md

## Graphics

| What | File | Notes |
|---|---|---|
| App icon | `docs/play-store/icon-512.png` | 512 × 512 PNG |
| Feature graphic | `docs/play-store/feature-graphic-1024x500.png` | 1024 × 500 |
| Phone screenshots | take new ones from the latest version | at least 2, up to 8. Use 1080 × 2340 phone screenshots (home, Files, Merge, Edit & sign, Markup, Text from scans, dark mode) |

The screenshots in `docs/screenshots/` come from an older version. Take new ones before you submit.

## App content (Play Console, "Policy and programs")

- **Privacy policy:** the URL above
- **Ads:** No, the app contains no ads
- **App access:** All functionality is available without logging in
- **Target audience:** 18 and over is the simplest answer. It is a general tool and is not made for children
- **Content rating:** answer the questionnaire with "No" to everything (no violence, no user content, no sharing between users). Category: utility
- **News app:** No
- **Government app:** No
- **Financial features:** No
- **Health features:** No
- **Advertising ID:** the app does not use it (it has no ads and no internet permission)

## Data safety form

Answers that match the app:

- Does your app collect or share any of the required user data types? **No**
- Is all of the user data collected by your app encrypted in transit? Not applicable (nothing is collected, and the app has no internet permission)
- Do you provide a way for users to request that their data be deleted? Not applicable. Everything stays on the phone and goes away when the app is uninstalled
- Files and docs, photos: they are read on the phone because the user picks them. They are **not collected** (not sent off the device), so they are not declared

## Release setup

1. Create a Play developer account (one-time US$25 fee) and verify your identity.
2. Create the app: name above, "App", "Free", accept the declarations.
3. Turn on **Play App Signing** when asked. The release key you already have (`paperwise-release.jks`) is your **upload key**. Google keeps the final signing key.
4. Upload `Paperwise-vX.Y.Z.aab` from the GitHub release.
5. Fill in the store listing, graphics, app content and data safety above.
6. **Testing requirement:** personal developer accounts created recently must first run a **closed test** (a group of testers, for a number of days) before they can publish to production. Check the exact numbers in Play Console under "Testing", since Google changes them.
7. After the closed test, apply for production access and publish.

## Good to know

- The app Google Play installs is signed with Google's key, and the APK on GitHub is signed with yours. Android will not update one over the other. Someone who has the GitHub APK must uninstall it before installing from Google Play (their files inside the app will be lost, so use Settings → Back up first).
- Paperwise no longer updates itself. Play Store users get updates from Google Play, and GitHub users download the new APK from Releases.
- Keep the `.jks` file and its passwords safe. If you lose the upload key you can ask Google to reset it, but keep a backup anyway.
