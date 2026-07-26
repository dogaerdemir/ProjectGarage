# OtoHafıza — Uygulama Durumu

Bu Xcode projesi, ürün ve teknik özellik dokümanındaki Milestone 1–8 MVP kapsamını uygular.

## Tamamlanan MVP kapsamı

- iOS 18+, iPhone, UIKit, Storyboard ve XIB tabanlı uygulama
- Modern `UIScene` yaşam döngüsü, MVVM-C, `AppCoordinator` ve `DependencyContainer`
- Üç sayfalık onboarding ve ilk araç ekleme akışı
- Çoklu araç ekleme, düzenleme, seçme, arşivleme, arşivden çıkarma ve ilişkili tüm verilerle kalıcı silme
- Araç fotoğrafı ve düşük kilometre giriş koruması
- Ana sayfada araç, kilometre, hızlı işlemler, yaklaşan hatırlatmalar, maliyet ve son kayıt kartları
- Bakım, yakıt, masraf, sigorta/kasko, muayene/kontrol, kilometre ve not kayıtları
- Dinamik bakım işlem kalemleri ve yakıt değerlerinin iki alandan üçüncü alanı hesaplaması
- Kayıt düzenleme/silme, kilometrenin yüksek kayıtlardan otomatik güncellenmesi
- Ay/yıl gruplu geçmiş, metin ve bakım kalemi araması, kayıt türü filtresi ve belge göstergesi
- Fotoğraf, PDF ve VisionKit kamera taraması ile belge ekleme; PDF/görsel önizleme
- Fotoğraf ve belge binary’lerini external storage destekli `AssetEntity` içinde saklama; mevcut korumalı yerel dosyalar için idempotent migration
- Türkiye odaklı bundled araç kataloğu, sürüm/manifest güncellemesi ve marka → model → yıl bağımlı seçim akışı
- Galeriden yerel araç fotoğrafı seçme ve fotoğraf bulunmadığında placeholder gösterme
- XIB tabanlı Yakındakiler ekranı; MapKit ile servis, yakıt, lastik, yıkama ve muayene araması, Apple Maps yol tarifi ve kayıt işletme adı aktarımı
- Açık kullanıcı onayına bağlı private iCloud eşitlemesi, yerel fallback ve Ayarlar’da eşitleme durumu
- CloudKit event geçmişinden setup/import/export durum takibi, iki cihaz düzenleme çakışması uyarısı ve kalıcı silme işaretleyicileriyle idempotent import reconciliation
- Cloud açılmadan önce tamamlanması gereken versiyonlu legacy asset migration; başarısız dosyalar için Ayarlar’dan retry
- Tarih/kilometre hatırlatmaları, uygulama içi durum değerlendirmesi ve yerel bildirim planlama
- Aylık/yıllık, yakıt, bakım, diğer ve kilometre başına maliyet metrikleri
- UIKit/Core Graphics ile son 12 aylık gider grafiği
- Türkçe String Catalog, semantik Dark Mode renkleri, Dynamic Type ve temel VoiceOver tanımları
- Versioned Core Data modeli, async repository/use case katmanları ve in-memory test store
- Üçüncü taraf bağımlılık bulunmaması

## Doğrulama

- Xcode 27.0 beta 4 (`27A5228h`) ve iOS 27 Simulator derlemesi: başarılı
- Uygulamanın iPhone 17 Pro Max iOS 27 Simulator’a kurulması ve başlatılması: başarılı
- Unit ve UI test bundle’larının Xcode 27 ile derlenmesi: başarılı
- Xcode 27 beta test runner, test yürütme başlarken üç ayrı iOS 27 Simulator örneğini kapattığı için bu ortamda güncel test sonucu üretilemedi
- Önceki kararlı ortam doğrulaması: 8/8 unit test ve 3/3 UI test başarılı
- Debug mağaza veri seeder’ı ile ana sayfa, geçmiş, belgeler, istatistikler ve marka seçimi akışları görsel olarak doğrulandı
- 1320 × 2868 çözünürlükte beş adet 6,9 inç App Store ekran görüntüsü hazırlandı
- Xcode 27 beta ile gerçek cihaz hedefli Release archive: başarılı
- App Store Connect yöntemiyle `1.0 (1)` Apple Distribution IPA export: başarılı
- Export edilen IPA’da production Push/CloudKit, `beta-reports-active` ve dağıtım profile’ı doğrulandı
- macOS 27 beta yerel `codesign --strict`, sertifika sahibinin adındaki Türkçe `İ` karakterinin Unicode normalizasyonunda designated requirement uyarısı üretiyor; sunucu tarafı son kontrol upload sırasında yapılmalı

## Sonraki sürüm fikirleri

Dokümanda MVP sonrası olarak belirtilen OCR metin çıkarma, App Intents/Siri, widget, PDF/CSV dışa aktarma, Face ID kilidi ve cihaz içi akıllı arama bu sürüme bilinçli olarak dahil edilmemiştir.

CarPlay ve Apple Watch ancak gerçek kullanım ihtiyacı doğrulandıktan sonra değerlendirilmelidir.

## Projeyi açma

Finder’dan `ProjectGarage.xcodeproj` dosyasını Xcode ile açın. Fiziksel cihaz veya dağıtım için GarageApp target’ında kendi Apple Development Team’inizi seçin.

Kullanıcıya görünen ürün adı ve dağıtım kimlikleri OtoHafıza olarak güncellenmiştir. Xcode proje/target/module adları, Storyboard ve XIB custom module bağlantılarını kırmamak için dahili olarak `ProjectGarage` ve `GarageApp` kalmıştır.
