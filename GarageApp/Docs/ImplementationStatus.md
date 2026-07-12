# Project Garage — Uygulama Durumu

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
- Belge binary’lerini Core Data dışında, UUID isimleri ve complete file protection ile saklama
- Tarih/kilometre hatırlatmaları, uygulama içi durum değerlendirmesi ve yerel bildirim planlama
- Aylık/yıllık, yakıt, bakım, diğer ve kilometre başına maliyet metrikleri
- UIKit/Core Graphics ile son 12 aylık gider grafiği
- Türkçe String Catalog, semantik Dark Mode renkleri, Dynamic Type ve temel VoiceOver tanımları
- Versioned Core Data modeli, async repository/use case katmanları ve in-memory test store
- Üçüncü taraf bağımlılık bulunmaması

## Doğrulama

- iOS Simulator Debug build: başarılı
- Unit test: 8/8 başarılı
- UI test: 3/3 başarılı
- Doğrulama cihazı: iPhone 17 Pro, iOS 26.5 Simulator
- Uçtan uca doğrulanan akış: onboarding → araç oluşturma → bakım kaydı oluşturma → ana sayfada kaydı görüntüleme

## Sonraki sürüm fikirleri

Dokümanda MVP sonrası olarak belirtilen OCR metin çıkarma, CloudKit/iCloud senkronizasyonu, App Intents/Siri, widget, PDF/CSV dışa aktarma, Face ID kilidi ve cihaz içi akıllı arama bu sürüme bilinçli olarak dahil edilmemiştir.

CarPlay ve Apple Watch ancak gerçek kullanım ihtiyacı doğrulandıktan sonra değerlendirilmelidir.

## Projeyi açma

Finder’dan `ProjectGarage.xcodeproj` dosyasını Xcode ile açın. Fiziksel cihaz veya dağıtım için GarageApp target’ında kendi Apple Development Team’inizi seçin.
