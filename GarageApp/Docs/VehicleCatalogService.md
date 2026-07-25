# Araç Katalog Servisi

Project Garage çevrimdışıyken bundled araç kataloğuyla çalışır. İsteğe bağlı uzak güncelleme yalnız sürümlü marka ve model verisini yeniler.

## Uygulama konfigürasyonu

`VehicleCatalogBaseURL`, build configuration üzerinden HTTPS bir temel adrese ayarlanabilir. Anahtar yoksa veya geçerli bir HTTPS URL değilse bundled katalog kullanılmaya devam eder.

## Manifest

`GET /v1/vehicle-catalog/manifest.json`

```json
{
  "schemaVersion": 2,
  "catalogVersion": 2,
  "catalogPath": "vehicle-catalog/catalog-v2.json",
  "sha256": "64-karakter-kucuk-harf-hex-sha256"
}
```

- `schemaVersion`, uygulamanın desteklediği şemayla aynı olmalıdır.
- Yalnız mevcut `catalogVersion` değerinden büyük sürümler indirilir.
- `catalogPath` göreli olmalı; `/`, `..`, ters eğik çizgi veya farklı origin içeremez.
- `sha256` varsa indirilen ham JSON kaydedilmeden önce doğrulanır.
- Decode veya doğrulama başarısız olursa mevcut katalog korunur.

## Katalog

`GET /v1/vehicle-catalog/catalog-v2.json`

```json
{
  "schemaVersion": 2,
  "catalogVersion": 2,
  "updatedAt": "2026-07-24T00:00:00Z",
  "makes": [
    {
      "id": "opel",
      "name": "Opel",
      "models": [
        {
          "id": "opel-astra",
          "name": "Astra"
        }
      ]
    }
  ]
}
```

`id` değerleri kalıcı veri anahtarıdır. Görünen ad değişse bile mevcut ID başka bir araca atanmaz; silinen bir kaydın ID’si yeniden kullanılmaz.
