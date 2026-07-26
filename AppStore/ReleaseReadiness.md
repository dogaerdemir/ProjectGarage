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
- GitHub Pages yayını etkinleştirildi; tanıtım, destek ve gizlilik bağlantıları herkese açık olarak `200` yanıtı veriyor.
- Xcode 27 beta ile gerçek cihaz hedefli Release archive başarıyla üretildi.
- Apple Developer Team `D7PK4RX7HQ` için App ID, iCloud/CloudKit ve Push yetenekleri doğrulandı.
- Yeni manuel Apple Distribution sertifikası ve `OtoHafiza App Store Manual 2026` provisioning profile oluşturuldu.
- App Store Connect dağıtım imzalı `1.0 (1)` IPA üretildi; imza designated requirement dâhil `codesign --deep --strict` ile doğrulandı.
- App Store Connect uygulama kaydı, Türkçe metadata, ekran görüntüleri, kategori, 4+ yaş derecelendirmesi, ücretsiz fiyatlandırma ve 175 ülke/bölge kullanılabilirliği tamamlandı.
- App Privacy yanıtı `Data Not Collected` olarak yayımlandı.
- `1.0 (1)` build’i App Store Connect’e başarıyla yüklendi, işlendi ve `İç Test` grubunda `Testing` durumuna getirildi.
- TestFlight test açıklaması ve iletişim bilgileri kaydedildi.

## Açık Apple tarafı konuları

1. İsteğe bağlı iCloud eşitlemesi varsayılan olarak kapalıdır. Yaygın kullanıma açılmadan önce Development CloudKit şeması oluşturulup CloudKit Console’dan Production’a deploy edilmelidir.
2. TestFlight build’i `Testing` durumunda ve tester davetleri kabul edilmiş olmasına rağmen iki fiziksel cihazda kurulum Apple tarafından “The requested app is unavailable or does not exist” hatasıyla durduruluyor. Sorun iOS 27 beta ile sınırlı değildir; iOS 26 çalışan iPhone 16’da da tekrarlandı.
3. Free Apps Agreement aktiftir, build imzası/geçerliliği ve TestFlight grup erişimi doğrulanmıştır. Bulgular Apple tarafındaki TestFlight beta-contract ilişkilendirme sorunuyla uyumludur.
4. Apple Developer Support vakası `20000120051734` açıldı ve ikinci cihaz kanıtıyla güncellendi. Apple’ın hesap/app düzeyindeki TestFlight beta sözleşmesini yeniden ilişkilendirmesi bekleniyor.

Projedeki build numarası bir sonraki yükleme için `2` olarak ilerletildi. `UploadOptions.plist`, mevcut manuel sertifika ve provisioning profile ile doğrudan App Store Connect yüklemesi için hazırdır.

TestFlight kurulum hatası uygulama kodu veya iOS sürümü kaynaklı görünmemektedir; Apple Support vakası çözülmeden aynı paketi yeniden yüklemek ya da tester’ı yeniden davet etmek bilinen hesap-arka-uç sorununu gidermeyebilir.
