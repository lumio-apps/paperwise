# The text recognition plugin mentions the Chinese, Devanagari, Japanese and
# Korean recognizers, but Paperwise only bundles the Latin (English) one.
# Tell R8 that those missing classes are fine.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
