# OtoHafıza

OtoHafıza; araç bakımını, masraflarını, yakıt alımlarını, kilometre geçmişini, hatırlatmaları ve belgeleri yerel öncelikli yöneten iOS uygulamasıdır. Marka ve model verilerini uygulamayla birlikte gelen JSON kataloğundan okur; MapKit tabanlı Yakındakiler özelliğini ve kullanıcının açıkça etkinleştirdiği özel iCloud eşitlemesini destekler.

- Minimum iOS: 18.0
- Arayüz: UIKit, Storyboard ve XIB
- Mimari: MVVM-C + Use Case + Repository
- Veri: Versioned Core Data + isteğe bağlı private CloudKit eşitlemesi
- Dil: Türkçe
- Üçüncü taraf bağımlılık: Yok
- App bundle ID: `com.dogaerdemir.otohafiza`
- iCloud container: `iCloud.com.dogaerdemir.otohafiza`

Ana ürün kaynağı `GarageApp/Docs/ProjectGarage-Product-Technical-Spec.md`, tamamlanan MVP kapsamı ve doğrulama sonuçları ise `GarageApp/Docs/ImplementationStatus.md` dosyasındadır.

App Store metadata, gizlilik yanıt taslağı, yayın kontrol listesi ve ekran görüntüleri `AppStore/` klasöründedir. GitHub Pages üzerinden yayımlanabilecek tanıtım, gizlilik ve destek sayfaları `docs/` klasöründedir.
