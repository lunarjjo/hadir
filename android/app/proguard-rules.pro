# Aturan ProGuard/R8 — minimifikasi nonaktif secara bawaan;
# berkas ini disiapkan untuk build masa depan.
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
