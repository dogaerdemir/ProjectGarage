# OtoHafıza — CloudKit Yayın Kontrol Listesi

Uygulama kodu local-first ve açık kullanıcı onaylı private CloudKit eşitlemesine hazırdır. Aşağıdaki hesap/dağıtım adımları TestFlight veya App Store arşivinden önce tamamlanmalıdır.

## Apple Developer ve imzalama

- `iCloud.com.dogaerdemir.otohafiza` container’ını ilgili Apple Developer Team altında oluştur veya mevcut container’ı seç.
- GarageApp App ID için iCloud/CloudKit ve Push Notifications yeteneklerini etkinleştir.
- Xcode’da Automatically Manage Signing ile provisioning profile’ı yenile.
- Fiziksel cihaz için imzalanmış uygulamanın effective entitlements çıktısında iCloud container, CloudKit service ve profile tarafından eklenen `aps-environment` değerlerini doğrula.
- Background Modes içinde Remote notifications seçimini koru.

## CloudKit şeması

- Development ortamında güncel Core Data modelini `initializeCloudKitSchema(options: [.dryRun])` ile doğrula.
- Dry-run temizse Development şemasını initialize et.
- CloudKit Console’da record type ve index’leri incele.
- TestFlight/App Store öncesinde Development şemasını Production ortamına deploy et. Production şeması uygulama içinden otomatik oluşturulmaz.

## Uygulama konfigürasyonu

- Araç kataloğunun bundle içindeki `vehicle_catalog_tr.json` dosyasından yüklendiğini doğrula; uzak servis ayarı gerekmez.
- Katalog manifest/hash sözleşmesini `VehicleCatalogService.md` ile aynı sürümde tut.

## Yayın öncesi cihaz doğrulaması

- iCloud kapalı, hesap yok ve çevrimdışı senaryolarda yerel kullanımın sürdüğünü doğrula.
- Açık onay, yeniden başlatma, ilk import/export ve Ayarlar durumlarını iki fiziksel cihazda doğrula.
- Fotoğraf/PDF migration retry, 20 MB asset sınırı ve diğer cihazdan dosya açma akışını doğrula.
- Asset migration v2’nin daha önce mirror edilmiş belge asset’lerinde `recordID` alanını backfill ettiğini doğrula.
- Aynı araç, kayıt veya hatırlatmayı iki cihazda düzenleme/silme yarışına sok; silinen verinin diğer cihazdaki geç import ile geri gelmediğini doğrula.
- Araç/kayıt silme işaretleyicisinin ilişkili child, asset metadata ve yerel dosya temizliğini tekrar tekrar güvenle yaptığını doğrula. İşaretleyiciler senkronizasyon güvenliği için silinmez; genel bir “parent yoksa sil” taraması çalıştırılmaz.
- Development ve Production container verilerini birbirine karıştırmadan ayrı sürüm senaryolarını kontrol et.
