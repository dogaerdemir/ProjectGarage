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
- Provisioning profile: `OtoHafiza App Store Manual 2026`
- SHA-256: `467e708ef3379f3e6f85887219ac35a4c3e3c3a232892d8a58ef709b3a888403`
- App Store Connect upload: başarılı
- TestFlight build durumu: `Testing`

IPA dosyaları kök `.gitignore` tarafından Git dışında tutulur. Yeni bir build alınca eski IPA’yı sürüm ve build numarası güncel adıyla değiştirin.

## İmzalama notu

Önceki Xcode-managed Distribution sertifikasında Türkçe `İ` karakterinin Unicode gösterimi designated requirement doğrulamasını bozuyordu. Yeni manuel Apple Distribution sertifikası ve provisioning profile ile bu sorun giderildi. Depodaki IPA hem yerel `codesign --verify --deep --strict` kontrolünden hem de App Store Connect upload doğrulamasından geçmiştir.

Bir sonraki build için `AppStore/ManualExportOptions.plist` yerel export, `AppStore/UploadOptions.plist` ise doğrudan App Store Connect upload akışını tanımlar.
