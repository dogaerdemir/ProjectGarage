# Dağıtım paketi

## Güncel doğrulama — 1.0 (4)

Build `4`, Xcode 27 beta ile Automatic Signing kullanılarak arşivlendi ve App Store Connect dağıtımına uygun IPA olarak export edildi.

Doğrulanan dağıtım özellikleri:

- Bundle ID: `com.dogaerdemir.otohafiza`
- Sürüm: `1.0`
- Build: `4`
- Team ID: `D7PK4RX7HQ`
- Push ortamı: `production`
- CloudKit ortamı: `Production`
- `beta-reports-active`: `true`
- `get-task-allow`: `false`
- Dağıtım imzalama: Xcode Automatic Signing
- Provisioning profile: `iOS Team Store Provisioning Profile: com.dogaerdemir.otohafiza`
- SHA-256: `884086955f9d047b2dce2d4935e665b305cf4c97ba79b00be47cd8e66d658e9c`
- Organizer sonucu: `Validation succeeded`
- App Store Connect upload: yapılmadı

Organizer doğrulamasının sonucu: `Your app successfully passed all validation checks.`

IPA dosyaları kök `.gitignore` tarafından Git dışında tutulur.

## Önceki TestFlight paketi — 1.0 (1)

`OtoHafiza-1.0-1.ipa` daha önce App Store Connect’e başarıyla yüklenmiş, işlenmiş ve TestFlight’ta `Testing` durumuna gelmiştir.

## İmzalama notu

Güncel proje belirli bir Distribution sertifikasına veya provisioning profile adına bağlı değildir:

- `CODE_SIGN_STYLE = Automatic`
- Team ID: `D7PK4RX7HQ`
- `AppStore/ExportOptions.plist`: Automatic Signing ile yerel App Store Connect export
- `AppStore/UploadOptions.plist`: Automatic Signing ile doğrudan App Store Connect upload

Yeni bir Mac’te yalnızca aynı Apple Developer hesabıyla Xcode’a giriş yapılmalı ve `Automatically manage signing` açık tutulmalıdır. `.p12`, `.cer` veya `.mobileprovision` taşınmamalıdır.
