# Dağıtım paketi

`OtoHafiza-1.0-1.ipa`, Xcode’un `app-store-connect` export yöntemiyle Apple Distribution sertifikası ve App Store provisioning profile kullanılarak üretilmiştir.

Doğrulanan dağıtım özellikleri:

- Bundle ID: `com.dogaerdemir.otohafiza`
- Sürüm: `1.0`
- Build: `1`
- Team ID: `D7PK4RX7HQ`
- Push ortamı: `production`
- CloudKit ortamı: `Production`
- `beta-reports-active`: `true`
- `get-task-allow`: `false`

IPA dosyaları kök `.gitignore` tarafından Git dışında tutulur. Yeni bir build alınca eski IPA’yı sürüm ve build numarası güncel adıyla değiştirin.

## macOS 27 beta notu

Xcode 26.6 ve Xcode 27 beta export işlemleri başarıyla tamamlanmıştır. macOS 27 beta’daki yerel `codesign --strict` doğrulayıcısı, sertifika sahibinin adındaki Türkçe `İ` karakterinin NFC/NFD gösterimleri arasında designated requirement karşılaştırması yaparken hata veriyor. İmzanın kaynak bütünlüğü, Apple sertifika zinciri, provisioning profile ve production entitlement’ları ayrı ayrı geçerlidir. Bu beta işletim sistemi kaynaklı kontrolün son doğrulaması App Store Connect upload sırasında yapılmalıdır.
