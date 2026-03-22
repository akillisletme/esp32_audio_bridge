# Localization (Çoklu Dil Desteği)

Bu proje `easy_localization ^3.0.1` paketini kullanmaktadır.

---

## Desteklenen Diller

| Kod | Dil        |
|-----|------------|
| tr  | Türkçe     |
| en  | English    |
| de  | Deutsch    |
| ar  | العربية    |
| es  | Español    |
| fr  | Français   |
| hi  | हिन्दी     |
| id  | Indonesia  |
| it  | Italiano   |
| ja  | 日本語      |
| ko  | 한국어      |
| pt  | Português  |
| ru  | Русский    |
| zh  | 中文        |

---

## Dosya Yapısı

```
assets/translations/
├── en.json   ← kaynak (referans) dosya
├── tr.json
├── ar.json
├── de.json
├── es.json
├── fr.json
├── hi.json
├── id.json
├── it.json
├── ja.json
├── ko.json
├── pt.json
├── ru.json
└── zh.json

lib/product/init/language/
└── locale_keys.g.dart   ← generator tarafından üretilir, düzenleme yapılmaz
```

---

## Anahtar Grupları

| Grup          | Açıklama                                            |
|---------------|-----------------------------------------------------|
| `general.*`   | Uygulama adı, yükleniyor, tekrar dene              |
| `error.*`     | Hata başlığı                                        |
| `update.*`    | Zorunlu güncelleme ekranı                           |
| `home.*`      | Ana ekran — başlık, kullanım adımları, mod kartları |
| `settings.*`  | Ayarlar ekranı — tüm seçenekler                    |
| `onboarding.*`| Karşılama ekranı — 5 adım                          |
| `language.*`  | Dil seçim ekranı                                    |
| `audioStream.*`| Ses akışı ekranı — tüm UI + log mesajları         |

---

## Yeni Anahtar Ekleme Adımları

1. **`en.json`** dosyasına anahtarı ekle (kaynak dosya).
2. **Diğer 13 dil dosyasının tamamına** aynı anahtarı ekle (generator yalnızca tüm dosyalarda ortak olan anahtarları çıktıya alır; eksik olan dil dosyası anahtarı bastırır).
3. Generator'ı çalıştır:

```bash
dart run easy_localization:generate \
  -O lib/product/init/language \
  -f keys \
  -o locale_keys.g.dart \
  --source-dir assets/translations
```

4. Kodda `LocaleKeys.grupAdi_anahtarAdi.tr()` şeklinde kullan.

> **Önemli:** Generator tüm dil dosyalarının kesişim kümesini alır.
> Herhangi bir dil dosyasında eksik anahtar varsa o anahtar `locale_keys.g.dart`'a eklenmez ve uygulamada "key not found" uyarısı çıkar.

---

## Dart'ta Kullanım

```dart
// Basit anahtar
Text(LocaleKeys.general_appName.tr())

// Named args ile
Text(LocaleKeys.audioStream_logStarted.tr(
  namedArgs: {'ip': '192.168.4.1', 'port': '4210'},
))

// Cubit / servis içinde (BuildContext gerekmez)
_log(LocaleKeys.audioStream_logStopped.tr(
  namedArgs: {'kb': kb, 'packets': packets.toString()},
));
```

---

## Dil Değiştirme (Runtime)

```dart
await context.setLocale(const Locale('tr'));
```

Seçilen dil `SharedPreferences`'a kaydedilir ve uygulama sonraki açılışta hatırlar.

---

## Initialization

`lib/product/init/app_initialization.dart` dosyasında:

```dart
await EasyLocalization.ensureInitialized();
```

`main.dart`'ta `EasyLocalization` widget'ı sarmalayıcı olarak kullanılır:

```dart
EasyLocalization(
  supportedLocales: AppLocales.supportedLocales,
  path: 'assets/translations',
  fallbackLocale: AppLocales.fallbackLocale,  // en
  useOnlyLangCode: true,
  child: const MyApp(),
)
```

`useOnlyLangCode: true` ile `ja_JP` yerine `ja` dosyası kullanılır.
