import 'app_settings.dart';

/// Turns an English screen text into the chosen language.
///
/// Texts that have no translation yet stay in English.
extension Translate on String {
  String get tr {
    if (AppSettings.instance.language != AppLanguage.hindi) return this;
    return _hindi[this] ?? this;
  }
}

const _hindi = <String, String>{
  // Navigation and headings
  'Home': 'होम',
  'Files': 'फ़ाइलें',
  'Settings': 'सेटिंग्स',
  'Pick a tool': 'टूल चुनें',
  'Recent files': 'हाल की फ़ाइलें',
  'See all': 'सभी देखें',
  'Offline': 'ऑफ़लाइन',
  'Soon': 'जल्द',
  'Every tool works without internet': 'हर टूल बिना इंटरनेट के चलता है',
  'PDFs you make will show up here, ready to open or share.':
      'आपके बनाए PDF यहाँ दिखेंगे, खोलने या शेयर करने के लिए तैयार।',
  'Could not open the file picker.': 'फ़ाइल चुनने वाली स्क्रीन नहीं खुल सकी।',

  // Tools
  'Merge PDF': 'PDF जोड़ें',
  'Split PDF': 'PDF बाँटें',
  'Page tools': 'पेज टूल',
  'Image to PDF': 'फ़ोटो से PDF',
  'PDF to image': 'PDF से फ़ोटो',
  'Image privacy': 'फ़ोटो की प्राइवेसी',
  'Compress': 'छोटा करें',
  'Scan to PDF': 'स्कैन करके PDF',
  'Protect': 'सुरक्षित करें',
  'Edit & sign': 'एडिट और साइन',
  'Markup': 'मार्कअप',
  'Search in PDF': 'PDF में खोजें',
  'PDF info': 'PDF की जानकारी',
  'Images from PDF': 'PDF से तस्वीरें',
  'Save pictures stored inside': 'PDF के अंदर की तस्वीरें सहेजें',
  'Pages per sheet': 'एक शीट पर कई पेज',
  'Save paper when printing': 'प्रिंट में काग़ज़ बचाएँ',
  'Organize': 'व्यवस्थित करें',
  'Convert and scan': 'बदलें और स्कैन करें',
  'Secure and edit': 'सुरक्षित करें और बदलें',
  'Read and find': 'पढ़ें और खोजें',
  'Join PDFs into one': 'कई PDF को एक बनाएँ',
  'By range or every page': 'रेंज से या हर पेज अलग',
  'Reorder, rotate, delete': 'क्रम बदलें, घुमाएँ, हटाएँ',
  'Photos become pages': 'फ़ोटो से PDF पेज बनाएँ',
  'Save pages as pictures': 'पेज को तस्वीर में सहेजें',
  'Remove location, blur faces': 'लोकेशन हटाएँ, चेहरे धुंधले करें',
  'See the size first': 'पहले साइज़ देखें',
  'Camera, crop, build': 'कैमरा, क्रॉप, PDF बनाएँ',
  'Make scans searchable': 'स्कैन को खोजने लायक बनाएँ',
  'Password and watermark': 'पासवर्ड और वॉटरमार्क',
  'Text, signature, numbers': 'टेक्स्ट, दस्तख़त, पेज नंबर',
  'Highlight and draw': 'हाइलाइट करें और बनाएँ',
  'Find words in a PDF': 'PDF में शब्द खोजें',
  'Author, dates, clean copy': 'लेखक, तारीख़ें, साफ़ कॉपी',

  'Text from scans': 'स्कैन से टेक्स्ट',
  'Choose a scanned PDF': 'स्कैन किया PDF चुनें',
  'Choose PDF': 'PDF चुनें',
  'Read the words on scanned pages. Everything happens on your phone, with no internet.':
      'स्कैन किए पन्नों के शब्द पढ़ें। सब कुछ आपके फ़ोन पर होता है, बिना इंटरनेट के।',
  'Make searchable': 'खोजने लायक बनाएँ',
  'Read text': 'टेक्स्ट पढ़ें',
  'What do you want?': 'आपको क्या चाहिए?',
  'Searchable PDF': 'खोजने लायक PDF',
  'Copy text': 'टेक्स्ट कॉपी करें',
  'Copy': 'कॉपी',
  'Text copied.': 'टेक्स्ट कॉपी हो गया।',
  'Starting…': 'शुरू हो रहा है…',
  'Saving…': 'सेव हो रहा है…',
  'No text was found on these pages.': 'इन पन्नों पर कोई टेक्स्ट नहीं मिला।',

  // Shared buttons
  'Back': 'वापस',
  'Cancel': 'रद्द करें',
  'Delete': 'हटाएँ',
  'Rename': 'नाम बदलें',
  'Share': 'शेयर करें',
  'Share all': 'सब शेयर करें',
  'Open': 'खोलें',
  'Done': 'हो गया',
  'OK': 'ठीक है',
  'Read': 'पढ़ें',
  'Save to phone': 'फ़ोन में सेव करें',
  'Add to favorites': 'पसंदीदा में जोड़ें',
  'Remove from favorites': 'पसंदीदा से हटाएँ',
  'Your PDF is ready': 'आपका PDF तैयार है',
  'Delete this PDF?': 'यह PDF हटाएँ?',
  'Rename PDF': 'PDF का नाम बदलें',
  'New name': 'नया नाम',
  'Could not rename the file. Please try again.': 'नाम नहीं बदल सका। कृपया फिर कोशिश करें।',
  'Could not save the file. Please try again.': 'फ़ाइल सेव नहीं हो सकी। कृपया फिर कोशिश करें।',

  // Files
  'Your files': 'आपकी फ़ाइलें',
  'PDFs made with Paperwise. They stay on this phone.': 'Paperwise से बने PDF। ये इसी फ़ोन में रहते हैं।',
  'All': 'सभी',
  'Favorites': 'पसंदीदा',
  'Open a PDF': 'PDF खोलें',
  'Continue reading': 'पढ़ना जारी रखें',
  'No favorites yet': 'अभी कोई पसंदीदा नहीं',
  'Tap the star when you read a PDF, and it will wait for you here.':
      'PDF पढ़ते समय तारे पर टैप करें, वह यहाँ मिलेगा।',
  'No files yet': 'अभी कोई फ़ाइल नहीं',
  'Merge, split or turn photos into a PDF, and it will show up here.':
      'PDF जोड़ें, बाँटें या फ़ोटो से बनाएँ, वह यहाँ दिखेगा।',
  'Search your files': 'अपनी फ़ाइलें खोजें',
  'Sort': 'क्रम',
  'Newest first': 'नई पहले',
  'Oldest first': 'पुरानी पहले',
  'Name A to Z': 'नाम A से Z',
  'Name Z to A': 'नाम Z से A',
  'Largest first': 'बड़ी पहले',
  'Smallest first': 'छोटी पहले',
  'No matching files': 'कोई फ़ाइल नहीं मिली',
  'Try another word.': 'कोई दूसरा शब्द आज़माएँ।',

  // Settings
  'Look': 'रूप',
  'Light': 'लाइट',
  'Dark': 'डार्क',
  'System': 'सिस्टम',
  'Language': 'भाषा',
  'Check for updates': 'अपडेट जाँचें',
  'Asks GitHub if a newer version exists': 'GitHub से पूछता है कि नया वर्शन है या नहीं',
  "What's coming": 'आगे क्या आ रहा है',
  'The tools in the next updates': 'अगले अपडेट के टूल',
  'Privacy': 'प्राइवेसी',
  'No ads, no tracking, no account': 'कोई विज्ञापन नहीं, कोई ट्रैकिंग नहीं, कोई अकाउंट नहीं',
  'Source code': 'सोर्स कोड',
  'Open source licenses': 'ओपन सोर्स लाइसेंस',
  'Paperwise is free and open source': 'Paperwise मुफ़्त और ओपन सोर्स है',
  'Back up your files': 'फ़ाइलों का बैकअप',
  'Save your PDFs and settings in one file': 'अपने PDF और सेटिंग एक फ़ाइल में सेव करें',
  'Restore from a backup': 'बैकअप से वापस लाएँ',
  'Bring back files from a Paperwise backup': 'Paperwise बैकअप से फ़ाइलें वापस लाएँ',
  'Your data': 'आपका डेटा',
  'Backup is ready': 'बैकअप तैयार है',
  'Keep it somewhere safe, like Drive or your computer.': 'इसे सुरक्षित जगह रखें, जैसे Drive या कंप्यूटर।',
  'Nothing to back up yet.': 'अभी बैकअप के लिए कुछ नहीं है।',
  'Could not make the backup. Please try again.': 'बैकअप नहीं बन सका। कृपया फिर कोशिश करें।',
  'That is not a Paperwise backup.': 'यह Paperwise का बैकअप नहीं है।',
  'Could not restore the backup. Please try again.': 'बैकअप वापस नहीं आ सका। कृपया फिर कोशिश करें।',
  'Simple, private, open source apps by Lumio Apps': 'Lumio Apps के सरल, निजी, ओपन सोर्स ऐप',
  'Your privacy': 'आपकी प्राइवेसी',
  'Link copied.': 'लिंक कॉपी हो गया।',
};

/// "3 files restored" in the chosen language.
String restoredMessage(int restored, int skipped) {
  final hindi = AppSettings.instance.language == AppLanguage.hindi;
  if (restored == 0 && skipped == 0) return hindi ? 'बैकअप में कोई PDF नहीं मिला।' : 'That backup has no PDFs in it.';
  if (restored == 0) return hindi ? 'सभी फ़ाइलें पहले से यहाँ हैं।' : 'All of those files are already here.';
  return hindi ? '$restored फ़ाइलें वापस आ गईं।' : (restored == 1 ? '1 file restored.' : '$restored files restored.');
}
