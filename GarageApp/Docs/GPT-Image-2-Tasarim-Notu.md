# Project Garage — Kısa Tasarım Notu

## Proje

Project Garage, bireysel araç sahiplerinin araç bilgilerini, bakım geçmişini, yakıt alımlarını, masraflarını, sigorta ve muayene kayıtlarını, hatırlatmalarını ve belgelerini tek yerde yönetmesini sağlayan Türkçe bir iPhone uygulamasıdır. Uygulama tamamen cihaz üzerinde çalışır; kullanıcı hesabı, reklam ve filo yönetimi yoktur.

Tasarım; modern, güvenilir, sade ve iOS'a özgü hissettirmelidir. Otomobil göstergesi veya yarış uygulaması görünümü yerine, günlük kullanımı kolaylaştıran net bilgi hiyerarşisi, okunaklı kartlar ve sakin bir vurgu rengi tercih edilmelidir. Tüm ekranlar aynı navigasyon, kart, form, ikon ve renk dilini korumalıdır.

## Ekranlar

- **Tanıtım:** Üç kısa sayfada araç geçmişini tek yerde tutma, önemli tarihleri hatırlama ve belgeleri saklama özellikleri anlatılır. Son eylem “İlk Aracımı Ekle”dir.

- **Ana Sayfa:** Seçili aracın adı, marka-modeli, yılı, plakası, güncel kilometresi ve varsa şasi numarası tek bir araç kartında gösterilir. “Araç Değiştir” ve “Kilometre Güncelle” ana eylemleridir. Devamında bakım, yakıt ve masraf hızlı işlemleri; bu ay/bu yıl maliyet özeti; yaklaşan işlemler ve son kayıtlar yer alır.

- **Geçmiş:** Araca ait bakım, yakıt, masraf, sigorta, muayene ve not kayıtları ay-yıl gruplarıyla ters kronolojik listelenir. Arama, kayıt türü filtresi ve yeni kayıt ekleme bulunur. Satırlarda tür, tarih, kilometre, tutar ve belge bilgisi özetlenir.

- **Kayıt Ekle / Düzenle:** Seçilen kayıt türüne göre alanları değişen sade bir formdur. Tarih, kilometre, tutar, işletme, açıklama ve kategori gibi bilgiler girilir; bakım kalemleri, hatırlatma ve fotoğraf/PDF belge eklenebilir.

- **Kayıt Detayı:** Kaydın bütün bilgileri anahtar-değer düzeninde gösterilir. Varsa işlem kalemleri ve bağlı belgeler ayrı bölümlerdedir. Düzenleme, belge önizleme ve kayıt silme eylemleri bulunur.

- **Belgeler:** Fatura, yakıt fişi, poliçe, muayene belgesi, garanti belgesi ve araç fotoğrafları listelenir. Belgenin genel mi yoksa bir işleme bağlı mı olduğu anlaşılır. Dosyalardan, fotoğraflardan veya kamerayla tarayarak belge eklenebilir; PDF ve görseller önizlenebilir.

- **İstatistikler:** Bu ay ve bu yıl toplamı ile bakım, yakıt, masraf, sigorta ve muayene tutarları kartlar halinde gösterilir. Kilometre başına maliyet ve son 12 ayın kategori renklerine ayrılmış yığılmış sütun grafiği bulunur.

- **Araçlarım / Araç Formu:** Birden fazla araç listelenir ve aktif araç seçilir. Araç ekleme-düzenleme formunda araç adı, marka, model, yıl, yakıt, şanzıman, kilometre, plaka, şasi numarası ve fotoğraf alanları vardır.

- **Hatırlatmalar:** Bakım veya diğer işlemler için tarih ve/veya kilometre hedefli hatırlatmalar gösterilir. Aktif, yaklaşan ve gecikmiş durumlar kolay ayırt edilmelidir.

- **Ayarlar:** Araç yönetimi, bildirim izni, seçili aracın verilerini silme, gizlilik bilgisi ve uygulama sürümü bulunur.

- **Seçim Panelleri:** Kayıt türü, kategori, yakıt türü, şanzıman ve belge kaynağı gibi seçimler alttan açılan ortak bir panelde sunulur; “Vazgeç” eylemi görsel olarak ikincildir.

Ana navigasyon dört sekmeden oluşur: **Ana Sayfa, Geçmiş, Belgeler, İstatistikler**.
