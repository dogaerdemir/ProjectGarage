# Project Garage

## iOS Ürün ve Teknik Özellik Dokümanı

Platform: iOS  
İlk hedef cihaz: iPhone  
Minimum sürüm: iOS 18  
Arayüz: UIKit  
Arayüz geliştirme yöntemi: Storyboard ve XIB  
Dil: Türkçe  
Geçici proje adı: Project Garage

# 1. Ürün Tanımı

Project Garage, bireysel araç sahiplerinin araç bakımını, masraflarını, yakıt alımlarını, kilometre geçmişini, sigorta ve muayene tarihlerini, servis kayıtlarını ve belgelerini tek yerde yönetmesini sağlayan iOS uygulamasıdır.

Uygulamanın temel amacı, araç sahibinin şu sorulara kolayca cevap verebilmesidir:

“Aracıma en son ne zaman bakım yaptırdım?”

“Bir sonraki bakım ne zaman?”

“Bu yıl araca ne kadar para harcadım?”

“Sigorta veya muayene ne zaman bitiyor?”

“Geçen bakımın faturası nerede?”

Uygulama arıza teşhisi koymaz, aracın güvenli olup olmadığına karar vermez ve servis yerine geçmez. Kullanıcının araç geçmişini düzenleyen kişisel bir araç yönetim aracıdır.

# 2. Hedef Kullanıcı

Birincil hedef kullanıcı, kendi otomobilini kullanan ve aracının bakım, masraf ve belge geçmişini düzenli tutmak isteyen bireysel araç sahibidir.

Kullanıcının otomobil konusunda uzman olması beklenmez. Uygulama hem yalnızca temel kayıt tutmak isteyen kullanıcıya hem de ayrıntılı bakım geçmişi oluşturmak isteyen kullanıcıya uygun olmalıdır.

Kurumsal filo yönetimi, servis işletmeleri, araç kiralama şirketleri ve ticari araç filoları kapsam dışıdır.

# 3. Temel Ürün İlkeleri

Uygulama iOS’a özel geliştirilecektir. Android, web veya çapraz platform desteği planlanmayacaktır.

Temel kayıt akışları yerel öncelikli çalışacaktır. Kullanıcı hesabı bulunmaz; katalog ve araç görseli için kişisel veri almayan sınırlı bir HTTPS proxy, açık kullanıcı onayıyla da private iCloud eşitlemesi kullanılabilir.

Temel işlemler internet bağlantısı olmadan çalışmalıdır.

Veri girişi mümkün olduğunca hızlı olmalıdır. Kullanıcı zorunlu olmayan teknik alanlarla karşılaştırılmamalıdır.

Araç bilgileri, belgeler ve kayıtlar kullanıcıya ait olmalıdır. Reklam veya kullanıcı takibi bulunmamalıdır.

Uygulama otomobil göstergesi taklit eden karmaşık ve gösterişli bir tasarım yerine standart iOS tasarım dilini kullanmalıdır.

# 4. MVP Kapsamı

İlk sürümde aşağıdaki özellikler bulunmalıdır:

Birden fazla araç ekleme ve yönetme.

Güncel kilometre takibi.

Bakım ve onarım kaydı.

Yakıt alımı kaydı.

Genel masraf kaydı.

Sigorta ve kasko kaydı.

Araç muayenesi ve kontrol kaydı.

Not kaydı.

Kayıtlara fotoğraf veya PDF belge ekleme.

Tarih ve kilometre bazlı hatırlatma oluşturma.

Araç geçmişini zaman çizelgesinde görüntüleme.

Aylık ve yıllık araç maliyetlerini görüntüleme.

Kayıtları düzenleme ve silme.

Türkçe arayüz.

Dark Mode, Dynamic Type ve VoiceOver desteği.

Sürümlü Türkiye araç kataloğu ve isteğe bağlı internet araç görseli.

MapKit ile yakındaki araç işletmelerini bulma ve kayıt formuna aktarma.

Açık onaya bağlı private iCloud eşitlemesi ve yerel fallback.

MVP’de kullanıcı hesabı, araç paylaşımı, OBD bağlantısı, CarPlay, Apple Watch, AI sohbeti, otomatik arıza teşhisi veya işletmelerle rezervasyon/hesap entegrasyonu bulunmayacaktır.

# 5. Ana Navigasyon

Uygulama bir `UITabBarController` üzerinden dört ana sekmeden oluşmalıdır:

Ana Sayfa.

Geçmiş.

Belgeler.

İstatistikler.

Her sekme kendi `UINavigationController` yapısına sahip olmalıdır.

Ayarlar ekranı, Ana Sayfa navigasyon çubuğundaki ayarlar butonundan açılmalıdır.

Araç ekleme ve kayıt oluşturma akışları modal olarak sunulmalıdır.

# 6. Onboarding ve Araç Ekleme

İlk açılışta en fazla üç sayfalık kısa bir onboarding gösterilmelidir.

Onboarding, araç geçmişinin tek yerde tutulmasını, bakım tarihlerinin hatırlatılmasını ve belgelerin kayıtlarla ilişkilendirilmesini anlatmalıdır.

Son eylem “İlk Aracımı Ekle” olmalıdır.

Araç ekleme formunda şu temel alanlar bulunmalıdır:

Araç takma adı.

Marka.

Model.

Model yılı.

Yakıt türü.

Şanzıman türü.

Plaka.

Güncel kilometre.

Araç fotoğrafı.

Marka → model → yıl alanları bundled ve sürümlü Türkiye kataloğundan bağımlı olarak seçilmelidir. Marka ve model alanlarında “Diğer / Manuel Gir” fallback’i bulunmalıdır.

Plaka, şasi numarası, motor açıklaması ve satın alma bilgileri isteğe bağlı olmalıdır.

# 7. Ana Sayfa

Ana Sayfa seçili araçla ilgili en önemli bilgileri göstermelidir.

Ekranda şu alanlar bulunmalıdır:

Araç özeti.

Güncel kilometre.

Yaklaşan işlemler.

Hızlı işlem butonları.

Bu ay ve bu yıl toplam harcama.

Son kayıtlar.

Hızlı işlemler şunlardır:

Bakım Ekle.

Yakıt Ekle.

Masraf Ekle.

Kilometre Güncelle.

Birden fazla araç varsa ekranın üst kısmında araç seçici bulunmalıdır.

Kilometre güncellenirken mevcut değerden daha düşük bir değer girilirse kullanıcı açıkça uyarılmalıdır.

# 8. Kayıt Türleri

## Bakım ve Onarım

Bakım kaydında tarih, kilometre, servis adı, toplam tutar, açıklama, işlem kalemleri, belgeler ve sonraki bakım bilgileri bulunmalıdır.

Bakım işlem kalemleri dinamik olarak eklenebilmelidir.

Örnek kategoriler:

Motor yağı.

Filtreler.

Fren sistemi.

Lastik.

Akü.

Şanzıman.

Süspansiyon.

Elektrik.

Kaporta.

Diğer.

Sonraki bakım tarihi veya kilometresi girildiğinde hatırlatma oluşturulması önerilmelidir.

## Yakıt Alımı

Yakıt kaydında tarih, kilometre, litre, litre fiyatı, toplam tutar, istasyon ve tam depo bilgisi bulunmalıdır.

Litre, litre fiyatı ve toplam tutar alanlarından ikisi girildiğinde üçüncü değer otomatik hesaplanabilmelidir.

Yakıt tüketimi yalnızca yeterli ve güvenilir veri bulunduğunda hesaplanmalıdır.

## Genel Masraf

Masraf kaydında tarih, kategori, açıklama, tutar, işletme, kilometre, not ve belge bulunmalıdır.

Örnek kategoriler:

Otopark.

Otoyol.

Yıkama.

Aksesuar.

Vergi.

Ceza.

Çekici.

Ekspertiz.

Diğer.

## Sigorta ve Kasko

Sigorta kaydında sigorta türü, şirket, poliçe numarası, başlangıç tarihi, bitiş tarihi, tutar ve belge bulunmalıdır.

Bitiş tarihi girildiğinde hatırlatma oluşturulması önerilmelidir.

## Muayene ve Kontrol

Muayene kaydında kontrol türü, işlem tarihi, geçerlilik tarihi, kilometre, sonuç, tutar ve belge bulunmalıdır.

Kontrol türleri araç muayenesi, egzoz ölçümü, ekspertiz, servis kontrolü ve diğer olarak başlayabilir.

## Kilometre

Kilometre kaydı yalnızca tarih, kilometre ve isteğe bağlı not içermelidir.

Bakım veya yakıt kaydında daha yüksek kilometre girildiğinde aracın güncel kilometresi de güncellenmelidir.

## Not

Diğer kayıt türlerine uymayan bilgiler için başlık, tarih, kilometre, açıklama ve belge içeren not kaydı bulunmalıdır.

# 9. Geçmiş Ekranı

Geçmiş ekranı seçili araca ait bütün kayıtları ters kronolojik sırayla göstermelidir.

Kayıtlar ay ve yıl bazında gruplanmalıdır.

Arama şu alanlarda çalışmalıdır:

Başlık.

Servis veya işletme adı.

Notlar.

Bakım işlem kalemleri.

Kullanıcı kayıt türüne göre filtreleme yapabilmelidir.

Her kayıt hücresinde kayıt türü, başlık, tarih, kilometre, tutar ve belge göstergesi bulunmalıdır.

Kayıt detay ekranından kayıt düzenlenebilmeli veya silinebilmelidir.

# 10. Belgeler

Kullanıcı fotoğraf kütüphanesinden görsel, kameradan tarama veya Dosyalar uygulamasından PDF ekleyebilmelidir.

Belgeler şu türlerde sınıflandırılabilir:

Servis faturası.

Yakıt fişi.

Sigorta poliçesi.

Muayene belgesi.

Garanti belgesi.

Araç fotoğrafı.

Diğer.

Fotoğraf ve belge binary verileri external storage etkin `AssetEntity.data` alanında tutulmalıdır. Belge metadatası ve göreli dosya yolu kendi entity’sinde kalmalıdır.

Eski `Application Support` dosyaları idempotent migration ile asset entity’sine kopyalanmalı; doğrulanmış yerel fallback dosyaları migration sırasında silinmemelidir.

Dosya adları UUID tabanlı oluşturulmalıdır.

Belge silindiğinde hem Core Data kaydı hem de fiziksel dosya silinmelidir.

# 11. Hatırlatmalar

Hatırlatmalar tarih bazlı, kilometre bazlı veya her iki koşulu birlikte içerebilir.

Tarih bazlı bildirimler `UserNotifications` kullanılarak yerel olarak planlanmalıdır.

Bildirim izni uygulama ilk açıldığında değil, kullanıcı ilk hatırlatmasını oluştururken istenmelidir.

Kullanıcı bildirim izni vermezse hatırlatmalar uygulama içinde görünmeye devam etmelidir.

Kilometre bazlı hatırlatmalar, uygulama aracın gerçek kilometresini otomatik bilemeyeceği için kilometre güncellendiğinde yeniden değerlendirilmelidir.

Hatırlatma durumları şunlardır:

Aktif.

Yaklaşıyor.

Gecikmiş.

Tamamlandı.

İptal edildi.

# 12. İstatistikler

MVP’de şu metrikler gösterilmelidir:

Bu ay toplam harcama.

Bu yıl toplam harcama.

Toplam yakıt gideri.

Toplam bakım gideri.

Diğer giderler.

Kilometre başına maliyet.

Son 12 ayın aylık giderleri.

Yeterli veri yoksa tahmini veya yanıltıcı sonuç gösterilmemelidir.

Grafikler UIKit ile oluşturulmalıdır. SwiftUI veya Apple Charts kullanılmamalıdır.

# 13. Tasarım

Uygulama sade, güvenilir ve modern bir iOS uygulaması gibi görünmelidir.

Karbon fiber arka planlar, hız göstergesi benzeri görseller, neon renkler ve ağır otomobil temaları kullanılmamalıdır.

Sistem yazı tipi ve SF Symbols kullanılmalıdır.

Bütün renkler Asset Catalog içinde semantik olarak tanımlanmalıdır.

Önerilen renk isimleri:

`AppAccent`

`AppBackground`

`CardBackground`

`PrimaryText`

`SecondaryText`

`Success`

`Warning`

`Danger`

Kartlar 14 veya 16 punto köşe yarıçapına sahip olabilir.

Ana yatay boşluk 16 veya 20 punto olmalıdır.

Formlar grouped `UITableView` veya `UICollectionView` ile hazırlanmalıdır.

Tekrar kullanılabilir form hücreleri XIB olarak oluşturulmalıdır.

Örnek hücreler:

`TextInputCell`

`DecimalInputCell`

`DatePickerCell`

`SelectionCell`

`ToggleCell`

`MultilineTextCell`

`AttachmentPickerCell`

Bütün etkileşimli alanlar en az 44 x 44 punto dokunma alanına sahip olmalıdır.

# 14. Teknik Mimari

Uygulama MVVM-C yaklaşımıyla geliştirilmelidir.

Temel katmanlar şunlardır:

Application.

Presentation.

Domain.

Data.

Services.

Navigasyon Coordinator yapısıyla yönetilmelidir.

Ana coordinator’lar:

`AppCoordinator`

`OnboardingCoordinator`

`HomeCoordinator`

`TimelineCoordinator`

`DocumentsCoordinator`

`InsightsCoordinator`

`RecordEditorCoordinator`

View controller iş mantığı veya Core Data işlemi içermemelidir.

ViewModel ekran durumunu hazırlamalı ve kullanıcı eylemlerini use case’lere yönlendirmelidir.

Domain katmanı UIKit ve Core Data bilmemelidir.

Core Data nesneleri presentation katmanına çıkarılmamalıdır.

Async işlemlerde async/await kullanılmalıdır.

UI güncellemeleri `@MainActor` üzerinde yapılmalıdır.

# 15. Önerilen Proje Yapısı

```text
GarageApp/
├── Application/
├── Presentation/
│   ├── Onboarding/
│   ├── Home/
│   ├── Vehicles/
│   ├── Timeline/
│   ├── RecordEditor/
│   ├── Documents/
│   ├── Insights/
│   ├── Reminders/
│   └── Settings/
├── Domain/
│   ├── Models/
│   ├── Repositories/
│   ├── UseCases/
│   └── Errors/
├── Data/
│   ├── CoreData/
│   ├── Repositories/
│   ├── Mappers/
│   └── FileStorage/
├── Services/
│   ├── Notifications/
│   ├── Documents/
│   ├── Formatting/
│   └── OCR/
├── DesignSystem/
├── Resources/
├── GarageAppTests/
├── GarageAppUITests/
└── Docs/
```

# 16. Temel Veri Modeli

Ana entity’ler şunlardır:

`VehicleEntity`

`RecordEntity`

`RecordLineItemEntity`

`ReminderEntity`

`DocumentEntity`

`AssetEntity`

`AppPreferenceEntity`

`DeletionMarkerEntity`

Kalıcı içerik entity’lerinde UUID ve uygun oluşturma/güncelleme zamanları bulunmalıdır.

Para değerleri `Decimal` olarak saklanmalıdır.

Kilometre değerleri `Int64` olmalıdır.

Enum değerleri raw string olarak saklanmalıdır.

## Vehicle

```text
id
nickname
make
model
modelYear
fuelType
transmissionType
plateNumber
vin
currentMileage
photoIdentifier
catalogMakeID
catalogModelID
isArchived
createdAt
updatedAt
```

## Record

```text
id
vehicleID
recordType
title
eventDate
odometer
totalAmount
currencyCode
vendorName
notes
source
createdAt
updatedAt
```

Kayıt türüne özel yakıt, sigorta veya muayene alanları aynı entity üzerinde isteğe bağlı alanlar olarak tutulabilir.

## RecordLineItem

```text
id
recordID
name
category
brand
partNumber
amount
warrantyEndDate
notes
sortOrder
```

## Reminder

```text
id
vehicleID
recordID
title
dueDate
dueMileage
status
isEnabled
notificationIdentifier
createdAt
updatedAt
completedAt
```

## Document

```text
id
vehicleID
recordID
documentType
displayName
mimeType
fileSize
localRelativePath
thumbnailRelativePath
checksum
createdAt
```

## Asset

```text
id
vehicleID
recordID
relativePath
data
mimeType
createdAt
updatedAt
```

## DeletionMarker

```text
id
targetType
targetID
createdAt
```

Araç, kayıt ve hatırlatma silmeleri CloudKit’te kalıcı `DeletionMarkerEntity` ile temsil edilmelidir. İşaretleyiciler geç gelen parent/child importlarını idempotent olarak temizlemeli ve yeniden oluşmayı engellemelidir. İşaretleyiciler silinmemeli; import sırası bilinmediği için parent’ı o anda bulunmayan kayıtları topluca silen genel bir tarama yapılmamalıdır.

# 17. Servis ve Repository Yapısı

Domain katmanında şu repository protokolleri bulunmalıdır:

`VehicleRepository`

`VehicleRecordRepository`

`ReminderRepository`

`DocumentRepository`

Önemli use case’ler:

`CreateVehicleUseCase`

`UpdateVehicleUseCase`

`UpdateCurrentMileageUseCase`

`CreateRecordUseCase`

`UpdateRecordUseCase`

`DeleteRecordUseCase`

`FetchTimelineUseCase`

`CreateReminderUseCase`

`EvaluateReminderStatusesUseCase`

`CalculateVehicleCostsUseCase`

`CalculateFuelConsumptionUseCase`

`AttachDocumentUseCase`

Dosya işlemleri ayrı bir `FileStorageService` üzerinden yapılmalıdır.

Bildirim işlemleri ayrı bir `NotificationSchedulingService` üzerinden yapılmalıdır.

# 18. Veri Saklama

MVP’de `NSPersistentCloudKitContainer` tabanlı Core Data kullanılmalıdır. iCloud tercihi varsayılan olarak kapalı olmalı ve iCloud kullanılamadığında aynı store yerel çalışmayı sürdürmelidir.

Core Data modeli ilk sürümden itibaren versioned olmalıdır.

Repository testleri için in-memory store desteklenmelidir.

Ana context yalnızca UI işlemleri için kullanılmalıdır.

Belge işlemleri ve ağır hesaplamalar background context üzerinde yapılmalıdır.

Core Data hataları kullanıcıya teknik hata metni olarak gösterilmemelidir.

# 19. Güvenlik ve Gizlilik

Plaka, şasi numarası, poliçe numarası, belgeler ve kullanıcı notları araç görseli proxy’sine veya analytics hizmetlerine gönderilmemelidir. Kullanıcı iCloud eşitlemesini açıkça etkinleştirirse bu veriler Apple’ın kullanıcıya özel iCloud veritabanına eşitlenebilir.

Yakındakiler için konum yalnız kullanıcı eylemiyle tek seferlik kullanılmalı, Core Data’ya veya başka kalıcı depoya kaydedilmemelidir.

Hassas bilgiler `UserDefaults` içinde saklanmamalıdır.

Belge dosyalarında uygun iOS file protection kullanılmalıdır.

Analytics eklenirse plaka, VIN, tutar, belge içeriği veya kullanıcı notları analytics olaylarına dahil edilmemelidir.

Kullanıcı aracı ve ilişkili bütün verileri kalıcı olarak silebilmelidir.

Face ID uygulama kilidi sonraki iOS sürümlerinde eklenebilir.

# 20. Sonraki iOS Sürümleri

MVP doğrulandıktan sonra yalnızca iOS ekosistemine yönelik şu özellikler değerlendirilebilir:

VisionKit ve Vision ile servis faturası OCR işlemi.

App Intents ve Siri üzerinden kilometre veya yakıt kaydı.

Widget ile yaklaşan bakım ve sigorta bilgileri.

PDF ve CSV araç geçmişi dışa aktarma.

Face ID ile uygulama kilidi.

Araç geçmişi üzerinde cihaz içi akıllı arama ve özetleme.

CarPlay ve Apple Watch ancak ürün kullanımının bunu gerçekten gerektirdiği kanıtlanırsa ayrıca değerlendirilmelidir.

# 21. Geliştirme Sırası

## Milestone 1: Proje Temeli

UIKit projesi.

Storyboard tabanlı navigasyon.

AppCoordinator.

Dependency container.

Klasör yapısı.

String Catalog.

Asset Catalog renkleri.

Core Data modelinin ilk sürümü.

## Milestone 2: Domain ve Data

Domain modelleri.

Repository protokolleri.

Use case’ler.

PersistenceController.

Core Data mapper ve repository implementasyonları.

In-memory test store.

## Milestone 3: Araç Yönetimi

Onboarding.

Araç ekleme.

Araç düzenleme.

Araç seçme.

Araç arşivleme ve silme.

## Milestone 4: Ana Sayfa

Araç özeti.

Kilometre kartı.

Hızlı işlemler.

Yaklaşan işlemler.

Maliyet özeti.

Son kayıtlar.

## Milestone 5: Kayıtlar

Bakım.

Yakıt.

Masraf.

Sigorta.

Muayene.

Kilometre.

Not.

Kayıt düzenleme ve silme.

## Milestone 6: Geçmiş ve Belgeler

Zaman çizelgesi.

Arama ve filtreleme.

Kayıt detayı.

Fotoğraf ve PDF ekleme.

Belge listeleme ve önizleme.

## Milestone 7: Hatırlatmalar ve İstatistikler

Yerel bildirimler.

Hatırlatma durumları.

Aylık ve yıllık maliyetler.

Yakıt ve bakım toplamları.

Kilometre başına maliyet.

## Milestone 8: Kalite

Dark Mode.

Dynamic Type.

VoiceOver.

Hata ve boş durumlar.

Unit testler.

UI test iskeleti.

# 22. Codex Talimatları

Bu doküman projenin ana ürün ve teknik kaynağıdır.

Codex bütün uygulamayı tek seferde geliştirmeye çalışmamalıdır. Her çalışmada yalnızca istenen milestone uygulanmalıdır.

Ana ekranlar Storyboard, tekrar kullanılabilir hücreler XIB ile hazırlanmalıdır.

SwiftUI kullanılmamalıdır.

Üçüncü taraf dependency eklenmemelidir.

Kullanıcının staged veya unstaged değişiklikleri geri alınmamalıdır.

İlgisiz dosyalar değiştirilmemelidir.

Yeni Swift dosyalarının başlığında şu ifade kullanılmalıdır:

```swift
//
//  Created by Doğa Erdemir on DD.MM.YYYY.
//
```

“Created by Codex” yazılmamalıdır.

Kullanıcı açıkça istemediği sürece build, test veya simülatör çalıştırılmamalıdır.

# 23. İlk Codex Prompt’u

```text
Bu repository içinde Project Garage ürün ve teknik dokümanını kaynak kabul ederek çalış.

Uygulama yalnızca iOS için geliştirilecek. Android, web veya çapraz platform yapısı oluşturma.

Önce mevcut proje yapısını ve kullanıcı değişikliklerini incele. Staged veya unstaged kullanıcı değişikliklerini geri alma. İlgisiz dosyaları değiştirme.

Şimdilik yalnızca Milestone 1 ve Milestone 2’yi uygula.

UIKit kullan. Ana ekranlar ve navigasyon Storyboard, tekrar kullanılabilir hücreler XIB olmalı. SwiftUI kullanma.

MVVM-C, Coordinator, Use Case ve Repository yaklaşımını kullan. Domain katmanını UIKit ve Core Data’dan bağımsız tut.

MVP’de üçüncü taraf dependency ekleme.

Yeni Swift dosyalarında “Created by Doğa Erdemir” kullan. “Created by Codex” yazma.

Proje temeli, klasör yapısı, AppCoordinator, dependency container, design system temeli, Core Data modeli, domain modelleri, repository protokolleri, mapper’lar, persistence controller ve repository implementasyonlarının iskeletini oluştur.

Kullanıcı açıkça istemediği için build veya test çalıştırma. Simülatör açma.

İşlem sonunda oluşturduğun ve değiştirdiğin dosyaları, verdiğin mimari kararları ve sonraki milestone için kalan işleri açıkla.
```
