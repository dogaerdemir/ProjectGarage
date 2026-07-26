# OtoHafıza — TestFlight ve App Store hazırlık durumu

## Projede tamamlananlar

- Kullanıcıya görünen ad: `OtoHafıza`
- App bundle ID: `com.dogaerdemir.otohafiza`
- Test bundle ID’leri: `com.dogaerdemir.OtoHafizaTests` ve `com.dogaerdemir.OtoHafizaUITests`
- iCloud container: `iCloud.com.dogaerdemir.otohafiza`
- Türkiye marka/model/yıl kataloğu yalnızca bundle içindeki `vehicle_catalog_tr.json` dosyasından okunuyor.
- Uzak katalog, görsel base URL’leri, ağ konfigürasyonu ve marka logo servisi kaldırıldı.
- Marka listesinde tüm markalar için yerel `VehiclePlaceholder` görseli kullanılıyor.
- Privacy manifest ve export compliance anahtarı eklendi.
- Türkçe App Store metadata taslağı hazırlandı.
- 6,9 inç App Store ekran görüntüleri hazırlandı.
- Gizlilik politikası, destek ve tanıtım sayfaları GitHub Pages için `docs/` altında hazırlandı.
- Xcode 27 beta ile gerçek cihaz hedefli Release archive başarıyla üretildi.
- Apple Developer Team `D7PK4RX7HQ` için App ID, iCloud/CloudKit, Push ve App Store provisioning profile otomatik imzalama akışında doğrulandı.
- App Store Connect dağıtım imzalı `1.0 (1)` IPA üretildi; effective entitlement’larda Push ve CloudKit ortamları `Production`, `beta-reports-active` açık ve `get-task-allow` kapalı.

## Kalan hesap ve yayın adımları

1. Development CloudKit şemasını oluşturup CloudKit Console’dan Production’a deploy edin.
2. GitHub Pages’i repository’nin `main` branch `/docs` klasöründen yayımlayın. Ardından metadata dosyalarındaki üç URL’nin herkese açık açıldığını doğrulayın.
3. App Store Connect’te yeni uygulama kaydı açın ve SKU belirleyin. Bundle ID olarak `com.dogaerdemir.otohafiza` seçin.
4. `Metadata/tr-TR/` içindeki metinleri ve `Screenshots/6.9-inch/` içindeki PNG’leri yükleyin.
5. `AppPrivacyAnswers.md` taslağına göre App Privacy, yaş derecelendirmesi, kategori, fiyat ve iletişim alanlarını tamamlayın.
6. `Distribution/OtoHafiza-1.0-1.ipa` dosyasını yükleyip TestFlight internal testing grubuna atayın.

macOS 27 beta’nın Türkçe `İ` içeren Apple Distribution sertifikalarında oluşturduğu yerel designated requirement doğrulama uyarısı için `Distribution/README.md` notuna bakın. Xcode 26.6 ve Xcode 27 beta export adımları başarılıdır; nihai sunucu doğrulaması upload sırasında yapılmalıdır.

Bu adımlar Apple Developer/App Store Connect hesabında yetki, sözleşme kabulü ve bazı kişisel/kurumsal bilgiler gerektirdiği için kaynak koddan otomatik tamamlanamaz.
