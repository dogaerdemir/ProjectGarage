# OtoHafıza — App Privacy yanıt taslağı

App Store Connect’te **Data Not Collected / Veri Toplanmıyor** seçilmesi önerilir.

Bu yanıtın dayanakları:

- Uygulamanın geliştiriciye ait bir backend’i, kullanıcı hesabı, reklamı veya analiz SDK’sı yoktur.
- Araçlar, kayıtlar, hatırlatmalar ve belgeler cihazdaki Core Data/file storage alanında tutulur.
- Kullanıcı isterse verilerini kendi private iCloud/CloudKit veritabanına eşitler. Geliştiricinin private database içeriğine erişimi yoktur.
- Konum yalnızca kullanıcı Yakındakiler ekranını açtığında MapKit sorgusu için anlık kullanılır; uygulama konumu saklamaz.
- Kamera ve fotoğraf arşivi yalnızca kullanıcının seçtiği araç fotoğrafı veya belgeyi uygulamaya eklemek için kullanılır.
- Bildirim verileri yalnızca cihazdaki yerel bildirimleri planlamak için kullanılır.

Bu taslak, yayımlanacak binary’de sonradan reklam, analiz, crash reporting, özel backend veya başka bir üçüncü taraf SDK eklenmediği sürece geçerlidir. Böyle bir servis eklenirse App Privacy yanıtları yeniden değerlendirilmelidir.

Önerilen diğer mağaza seçimleri:

- Birincil kategori: Utilities
- İkincil kategori: Productivity
- Yaş derecelendirmesi: İçerik sorularının tamamı “Hayır”; beklenen sonuç 4+
- Uygulama ücret modeli: Free
- Tracking: Hayır
