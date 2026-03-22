# ESP32 Audio Bridge — Proje Belgeleri

> **Okuyucuya not:** Bu dosya, projeyi ilk kez (veya uzun süre sonra) açan birinin
> hiçbir şeyi hatırlamasa bile sistemi bütünüyle anlayabilmesi için yazılmıştır.
> Kod değişince bu dosyayı da güncelle.

---

## 1. Ne Yapıyor Bu Uygulama?

**İki farklı ses kaynağından** gerçek zamanlı ses verisi alarak
**UDP paketleri halinde bir ESP32 cihazına gönderir**.

### Kaynak 1: Sistem Sesi (MediaProjection)

```
Android Sistem Sesi (müzik, video, oyun, …)
      │
      ▼
MediaProjection API (izin → sistem sesi erişimi)
      │
      ▼
AudioRecord (PCM16 formatında byte dizisi)
      │  (Platform Channel — EventChannel)
      ▼
Flutter Dart tarafı
      │
      ├─► [İsteğe bağlı] WAV header (44 byte) ekle
      │
      ▼
UDP Soketi → ESP32 IP:Port
```

### Kaynak 2: WAV Dosyası

```
Cihaz depolama → FilePicker → .wav dosyası yolu
      │
      ▼
WavFileStreamer (Dart — native kod yok)
  ├── WAV header parse (format, sampleRate, byteRate, dataOffset)
  ├── RandomAccessFile ile chunk okuma (RAM'e tam yükleme yok)
  └── byteRate'e göre chunk'lar arası gecikme (gerçek zamanlı hız)
      │
      ▼
UDP Soketi → ESP32 IP:Port
```

**Veri formatı:** PCM 16-bit, little-endian, mono veya stereo
**Protokol:** UDP (bağlantısız, düşük gecikme)
**Min. Android:** API 29 (Android 10) — sistem sesi modu için
**Dosya modu:** API 29 şartı yok, sadece dosya okuma izni gerekli

---

## 2. Proje Adı Neden "akillisletme"?

Dart paket adı (`name: akillisletme` — pubspec.yaml) değiştirilmedi çünkü
tüm `package:akillisletme/...` importları kırılırdı.

Görünen ad (cihazda görünen, Store'da görünen) **ESP32 Audio Bridge** olarak
ayarlandı:
- `android/app/src/main/AndroidManifest.xml` → `android:label`
- `assets/translations/tr.json` + `en.json` → `general.appName`
- `pubspec.yaml` → `description`

---

## 3. Katman Mimarisi

```
┌─────────────────────────────────────────────────────┐
│                   FLUTTER (Dart)                    │
│                                                     │
│  AudioStreamCubit                                   │
│    ├── AudioCaptureChannel  (platform channel)      │
│    ├── UdpSenderService     (dart:io UDP soketi)    │
│    └── WavFileStreamer      (WAV dosya akışı)       │
│                                                     │
│  UI: AudioStreamView → SettingsPanel                │
│                      → StatsBar                     │
│                      → LogPanel                     │
└──────────────────────┬──────────────────────────────┘
                       │  MethodChannel / EventChannel
                       │  (sadece sistem sesi modunda)
┌──────────────────────▼──────────────────────────────┐
│               ANDROID NATIVE (Kotlin)               │
│                                                     │
│  MainActivity                                       │
│    ├── MethodChannel handler (startCapture/stop)    │
│    └── EventChannel sink (ses verisi → Flutter)     │
│                                                     │
│  AudioCaptureService (Foreground Service)           │
│    ├── MediaProjection token alır                   │
│    ├── AudioRecord (PCM16) döngüsü                  │
│    └── Her chunk → MainActivity.eventSink.success() │
└─────────────────────────────────────────────────────┘
```

---

## 4. Android Native Katmanı

### 4.1 İzin Akışı

```
Flutter: AudioCaptureChannel.startCapture()
    │
    ▼ MethodChannel "startCapture"
MainActivity.requestMediaProjection(config)
    │
    ▼ projectionManager.createScreenCaptureIntent()
Sistem izin dialogu (kullanıcıya gösterilir)
    │
    ├── KABUL → onActivityResult(RESULT_OK)
    │              → AudioCaptureService.projectionResultCode/Data set
    │              → startForegroundService()
    │              → bindService() → serviceConnection.onServiceConnected()
    │              → AudioCaptureService.startCapture(config)
    │
    └── RET  → eventSink.error("PERMISSION_DENIED", ...)
```

### 4.2 AudioCaptureService.kt

**Dosya:** `android/app/src/main/kotlin/com/cleanstart/akillisletme/AudioCaptureService.kt`

- `startCapture(config: Map<String, Any>)` → config'den sampleRate/channels/bufferSize alır
- `AudioPlaybackCaptureConfiguration` ile USAGE_MEDIA + USAGE_GAME + USAGE_UNKNOWN seslerini yakalar
- İç buffer: `max(bufferSize * 4, minBufSize * 2)` — küçük buffer'da overflow önlemi
- Okuma thread'i (`isDaemon=true`, adı `AudioCaptureThread`): `AudioRecord.READ_BLOCKING`
- Her `read > 0` → `mainHandler.post { eventSink.success(chunk) }` → Flutter'a iletilir
- `stopCapture()`: `isCapturing=false` → thread 2 sn join bekler → AudioRecord release → MediaProjection stop

### 4.3 Channel İsimleri (Dart ve Kotlin'de aynı olmalı)

| Channel | İsim |
|---------|------|
| MethodChannel | `com.cleanstart.akillisletme/audio_capture` |
| EventChannel | `com.cleanstart.akillisletme/audio_stream` |

---

## 5. Flutter Servis Katmanı

### 5.1 AudioCaptureChannel

**Dosya:** `lib/product/service/services/audio_capture_channel.dart`

Platform channel wrapper. Singleton (`AudioCaptureChannel.instance`).

```dart
// Kullanım:
await AudioCaptureChannel.instance.startCapture(
  sampleRate: 44100, channels: 1, bufferSize: 1024,
);
AudioCaptureChannel.instance.audioStream  // Stream<Uint8List>
await AudioCaptureChannel.instance.stopCapture();
```

`audioStream` her dinlemede Android'e yeni bir EventChannel stream açar.
Cubit bu stream'e abone olur, kapatınca iptal eder.

### 5.2 UdpSenderService

**Dosya:** `lib/product/service/services/udp_sender_service.dart`

Singleton (`UdpSenderService.instance`). `RawDatagramSocket` kullanır.

```dart
await UdpSenderService.instance.initialize(ip: '192.168.4.1', port: 4210);
udp.send(Uint8List data);  // true/false döner
await UdpSenderService.instance.close();
```

İstatistikler: `totalBytesSent`, `totalPackets` — cubit bunları saniyede bir okur.

**UDP neden bloklamaz?** `RawDatagramSocket.send()` kernel call'dur, Dart event
loop'unu bloklamaz. İzolat gerekmedi.

### 5.3 WavFileStreamer

**Dosya:** `lib/product/service/services/wav_file_streamer.dart`

Singleton (`WavFileStreamer.instance`). Native kod kullanmaz — tamamen Dart.

```dart
// Kullanım:
final sub = WavFileStreamer.instance
    .stream(filePath: '/sdcard/ses.wav', chunkSize: 1024, loop: false)
    .listen(onData, onDone: onDone, onError: onError);
```

**Nasıl çalışır:**

1. `_parseWavHeader()` → `RandomAccessFile` ile RIFF chunk'larını tarar,
   `fmt ` ve `data` chunk'larını bulur.
2. `AudioFormat == 1` (PCM) kontrolü — MP3/AAC formatlar `FormatException` fırlatır.
3. `byteRate` değerinden chunk arası gecikme hesaplanır:
   `delayUs = chunkSize × 1_000_000 / byteRate` (gerçek zamanlı oynatma hızı).
4. `RandomAccessFile` ile dosya RAM'e tam yüklenmez — büyük dosyalar güvenli.
5. `loop=true` → `do-while` döngüsü ile dosya bitince `dataOffset`'e geri döner.
6. `loop=false` → stream tamamlanır → cubit'in `_onStreamDone()` tetiklenir.

**Desteklenen format:** PCM WAV (AudioFormat=1), 16-bit
**Desteklenmez:** MP3, AAC, FLAC veya WAV container içinde sıkıştırılmış format

---

## 6. Feature Katmanı: audio_stream

**Klasör:** `lib/feature/audio_stream/`

```
audio_stream/
  audio_stream_view.dart         → Ana ekran (StatefulWidget)
  audio_stream_view_model.dart   → ViewModel (controller lifecycle)
  state/
    audio_stream_state.dart      → Freezed state + enum'lar
    audio_stream_cubit.dart      → İş mantığı
  widget/
    stats_bar.dart               → KB/s, Paket/s, Toplam kart satırı
    settings_panel.dart          → Kaynak seçimi + ağ + ses ayarları
    log_panel.dart               → Zaman damgalı scrollable log
```

### 6.1 State: AudioStreamState

```dart
// Kaynak seçimi:
AudioSource audioSource       // system | file
String?     selectedFilePath  // dosya modu: tam yol
String      selectedFileName  // dosya modu: görünen ad ('' = seçilmedi)
bool        loopFile          // dosya bitince baştan başla

// Akış durumu:
bool isStreaming              // aktif yayın var mı
bool isLoading               // izin/bağlantı bekleniyor

// Ağ:
String targetIp               // ESP32 IP (default: 192.168.4.1)
int    targetPort             // UDP port (default: 4210)

// Ses (sistem sesi modunda):
BufferSize bufferSize         // 512/1024/2048/4096 byte enum
SampleRate sampleRate         // 8k/16k/44.1k/48k Hz enum
int        channels           // 1=mono, 2=stereo
bool       addWavHeader       // her pakete 44B WAV header ekle

// İstatistikler:
int    packetsPerSecond       // 1s delta
double kbytesPerSecond        // 1s delta KB/s
int    totalPackets
int    totalBytesSent

// Log:
List<String> logs             // son 150 kayıt, [HH:mm:ss] prefix
String?      error
```

**Enum'lar:**
- `AudioSource`: `system`, `file`
- `BufferSize`: `tiny(512)`, `small(1024)`, `medium(2048)`, `large(4096)`
- `SampleRate`: `phone(8000)`, `voip(16000)`, `cd(44100)`, `studio(48000)`

### 6.2 Cubit: AudioStreamCubit

**Dosya:** `lib/feature/audio_stream/state/audio_stream_cubit.dart`

**Enjekte edilenler:** `AudioCaptureChannel`, `UdpSenderService`, `WavFileStreamer`

**Sistem sesi akışı:**

```
startStreaming() [audioSource == system]
  ├── udp.initialize(ip, port)
  ├── capture.startCapture(sampleRate, channels, bufferSize)
  ├── audioStream.listen(_onAudioData)   ← StreamSubscription
  └── _startStatsTicker()                ← Timer.periodic(1s)
```

**Dosya akışı:**

```
startStreaming() [audioSource == file]
  ├── selectedFilePath null/empty kontrolü → hata mesajı
  ├── udp.initialize(ip, port)
  ├── wav.stream(filePath, chunkSize=bufferSize.bytes, loop=loopFile)
  ├──   .listen(_onAudioData)            ← StreamSubscription
  └── _startStatsTicker()                ← Timer.periodic(1s)
```

**Ortak pipeline:**

```
_onAudioData(Uint8List raw)
  ├── addWavHeader ? _wrapInWav(raw) : raw
  └── udp.send(payload)

stopStreaming()
  ├── statsTicker.cancel()
  ├── audioSub.cancel()
  ├── capture.stopCapture()    ← sadece sistem sesi modunda
  └── udp.close()
```

**Dosya seçimi:**

```dart
pickFile()  // FilePicker → .wav filtresi
  └── emit(state.copyWith(
        selectedFilePath: path,
        selectedFileName: picked.name,
        audioSource: AudioSource.file,
      ))
```

**WAV header (_wrapInWav):** 44 byte header + PCM data. Her paket bağımsız
WAV dosyası gibi davranır. ESP32'de `wav_decoder` kullanıyorsan aç.

> **Not:** `_wrapInWav`, header için `state.sampleRate` ve `state.channels`
> değerlerini kullanır. Dosya modunda bu değerler WAV dosyasının gerçek
> parametrelerini yansıtmaz. Bu nedenle `addWavHeader` toggle'ı dosya modunda
> UI'da gizlenmiştir.

**Stats timer:** Her saniye `udp.totalPackets - prevPackets` ve
`udp.totalBytesSent - prevBytes` ile delta hesaplar → state günceller.

**Log:** `_log()` her çağrıda `[HH:mm:ss] mesaj` formatında ekler,
150'yi geçince baştan kırpar.

### 6.3 View Mimarisi

```
AudioStreamView (StatefulWidget)
  └── _AudioStreamViewState extends AudioStreamViewModel
        build()
          └── BlocProvider<AudioStreamCubit>   ← cubit burada yaratılır
                └── _AudioStreamContent (StatelessWidget)
                      ├── BlocListener → log scroll tetikler
                      ├── BlocListener → error SnackBar
                      └── Scaffold
                            ├── AppBar (başlık + status chip)
                            ├── ListView
                            │     ├── StatsBar
                            │     ├── SettingsPanel
                            │     └── LogPanel
                            └── FloatingActionButton (Başlat / Durdur)
```

**Neden cubit build'de yaratıldı?** Cubit'in sadece bu ekran açıkken yaşaması
için. Ekran kapanınca dispose olur, UDP soketi ve ses kaynakları otomatik serbest
bırakılır. Global state'e eklenmedi.

**ViewModel neden initState'te cubit okumaz?** BlocProvider build metodunda
yaratılıyor, initState sırasında henüz tree'de değil. Controller'lar
`AudioStreamState` default değerleriyle başlatılır (192.168.4.1 / 4210).

### 6.4 SettingsPanel Widget Yapısı

```
SettingsPanel
  ├── _SourceCard
  │     ├── SegmentedButton<AudioSource>  (system / file toggle)
  │     └── [dosya modu seçiliyse:]
  │           ├── Seçili dosya adı (Container + ikon) veya "Henüz seçilmedi"
  │           ├── OutlinedButton.icon → cubit.pickFile()
  │           └── SwitchListTile → cubit.setLoopFile()
  │
  ├── _NetworkCard
  │     ├── IP TextField
  │     ├── Port TextField (sadece rakam)
  │     └── FilledButton.tonal → onApplyNetwork
  │
  └── _AudioCard  [sadece audioSource == system ise gösterilir]
        ├── DropdownMenu<SampleRate>
        ├── DropdownMenu<BufferSize>
        ├── SegmentedButton<int>  (Mono / Stereo)
        └── SwitchListTile → addWavHeader
```

---

## 7. Navigation

**Dosya:** `lib/product/navigation/app_router.dart`

```
/ (HomeRoute)
├── /audio-stream  (AudioStreamRoute)  ← ana feature
└── /settings      (SettingsRoute)
      ├── /settings/about
      └── /settings/language
/onboarding
```

**Home → Audio Stream:** `HomeView`'daki FAB (`Icons.podcasts`, label: `LocaleKeys.home_goToStream.tr()`)
`const AudioStreamRoute().push<void>(context)` çağırır.

---

## 8. Localization

**Dosyalar:** `assets/translations/tr.json`, `en.json`
**Generated:** `lib/product/init/language/locale_keys.g.dart`

Her iki dil dosyasında toplam 99 key bulunur (TR = EN, eşleşiyor ✓).

> **Önemli:** `easy_localization:generate` komutu bu versiyonda (^3.0.1)
> yeni key'leri bazen atlar. `audioStream.*` ve `home.*` key'leri
> locale_keys.g.dart'a elle eklendi. Generator çalıştırılınca bu bölümler
> silinirse tekrar eklemek gerekir.

Localization generate komutu:
```bash
dart run easy_localization:generate \
  -O lib/product/init/language \
  -f keys -o locale_keys.g.dart \
  --source-dir assets/translations
```

---

## 9. Arka Plan Animasyonu

**Dosya:** `lib/feature/home/widget/home_background.dart`

Tüm uygulama genelinde (`AppBuilder` → `Stack`) gösterilen dekoratif animasyon.
12 ses ikonu rastgele konumlarda yavaşça yüzer (40 sn döngü, tersine oynama).

**İkon seti:** `graphic_eq`, `music_note`, `headphones`, `podcasts`, `mic`, `equalizer`
(6 farklı ikon, 12 öğeye sırayla atanır)

**Teknik detay:** CustomPainter içinde `String.fromCharCode(iconData.codePoint)` ile
MaterialIcons fontu kullanılarak ikona çizilir — ayrı bir asset gerekmez.

**Opaklık:** %4–9 (çok ince, içeriğin önünü kesmez)

**Toggle:** `HomeBackground.enabledNotifier` (ValueNotifier) — Settings ekranındaki
"Arka Plan Animasyonu" switch'i ile kontrol edilir, SharedPreferences'a kaydedilir.

---

## 11. Android Manifest Gereksinimleri

```xml
<!-- UDP -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Foreground service -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<!-- Android 14+ mediaProjection foreground service tipi -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />

<!-- Sistem sesi yakalama (API 29+) -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- Dosya modu: ses dosyası okuma — Android 13+ -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<!-- Dosya modu: ses dosyası okuma — Android 12 ve altı -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<service
    android:name=".AudioCaptureService"
    android:foregroundServiceType="mediaProjection"
    android:exported="false" />
```

- `FOREGROUND_SERVICE_MEDIA_PROJECTION` → Android 14+ (API 34) zorunlu
- `foregroundServiceType="mediaProjection"` → Android 10+ zorunlu
- Servis olmadan `AudioPlaybackCaptureConfiguration` kullanılamaz
- `READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE` → FilePicker'ın WAV dosyasına erişmesi için

---

## 12. ESP32 Tarafında Ne Beklenmeli?

ESP32 şu formatta UDP paketi alır:

**WAV header KAPALI (ham PCM):**
```
[PCM16 LE byte dizisi, bufferSize kadar]
Örnek 1024 byte: 512 adet 16-bit örnek
```

**WAV header AÇIK (sadece sistem sesi modunda önerilir):**
```
[44 byte WAV header][PCM16 LE byte dizisi]
Her paket bağımsız bir WAV dosyası gibi parse edilebilir.
```

Tipik akış (44100 Hz, Mono, 1024 buffer):
- ~86 paket/saniye
- ~88 KB/saniye ham veri

**Dosya modu notu:** WAV dosyasındaki gerçek sampleRate ve channel bilgisi
WavFileStreamer tarafından kullanılır (timing için). ESP32'ye giden PCM ham veri
olduğundan, ESP32 tarafında doğru formatı bilmek önemli.

---

## 13. Sık Yapılan Değişiklikler

### Default IP'yi değiştir
`lib/feature/audio_stream/state/audio_stream_state.dart`
```dart
@Default('192.168.4.1') String targetIp,   // ← burası
```
Ve `lib/feature/audio_stream/audio_stream_view_model.dart`
```dart
ipController = TextEditingController(text: '192.168.4.1');  // ← burası
```

### Yeni buffer boyutu ekle
`lib/feature/audio_stream/state/audio_stream_state.dart` → `BufferSize` enum

### Farklı audio usage yakala (ör. voice call)
`android/.../AudioCaptureService.kt` → `addMatchingUsage(...)` satırları

### UDP yerine TCP kullan
`UdpSenderService` yerine `Socket` (dart:io) kullanılabilir; cubit'te
`_udp` referansını değiştirmek yeterli — arayüz aynı kalır.

### Varsayılan kaynağı dosya modu yap
`lib/feature/audio_stream/state/audio_stream_state.dart`
```dart
@Default(AudioSource.file) AudioSource audioSource,  // ← system → file
```

### WAV dışı formatları destekle (ör. raw PCM dosyası)
`WavFileStreamer._parseWavHeader()` içindeki RIFF kontrolünü atla ve
sampleRate/channels/dataOffset parametrelerini dışarıdan al.

---

## 14. Önemli Dosya Haritası

| Dosya | Ne yapar |
|-------|---------|
| `android/.../MainActivity.kt` | Platform channel kurulum + MediaProjection izin akışı |
| `android/.../AudioCaptureService.kt` | Sistem sesi yakalama foreground service |
| `android/.../AndroidManifest.xml` | İzinler + servis tanımı |
| `lib/product/service/services/audio_capture_channel.dart` | Dart ↔ Android köprüsü |
| `lib/product/service/services/udp_sender_service.dart` | UDP soket yönetimi |
| `lib/product/service/services/wav_file_streamer.dart` | WAV dosyası parse + chunk akışı |
| `lib/feature/audio_stream/state/audio_stream_state.dart` | Tüm uygulama state'i + enum'lar |
| `lib/feature/audio_stream/state/audio_stream_cubit.dart` | Ana iş mantığı (her iki kaynak modu) |
| `lib/feature/home/home_view.dart` | Ana ekran: hero, nasıl kullanılır, mod kartları, ağ bilgisi |
| `lib/feature/home/home_view_mode.dart` | ViewModel (sadece ScrollController) |
| `lib/feature/home/widget/home_background.dart` | Arka plan animasyonu (yüzen ses ikonları) |
| `lib/feature/audio_stream/audio_stream_view.dart` | Ekran + FAB |
| `lib/feature/audio_stream/audio_stream_view_model.dart` | Controller lifecycle |
| `lib/feature/audio_stream/widget/settings_panel.dart` | Kaynak + ağ + ses ayar kontrolleri |
| `lib/feature/audio_stream/widget/stats_bar.dart` | KB/s, Paket/s istatistik kartları |
| `lib/feature/audio_stream/widget/log_panel.dart` | Scrollable log paneli |
| `lib/product/navigation/app_router.dart` | Route tanımları |
| `assets/translations/tr.json` | Türkçe string'ler |
| `assets/translations/en.json` | İngilizce string'ler |
| `pubspec.yaml` | `file_picker: ^8.3.7` dahil bağımlılıklar |

---

## 15. Build & Run

```bash
# Bağımlılıklar
flutter pub get

# Code-gen (Freezed + GoRouter + Hive + FlutterGen)
dart run build_runner build --delete-conflicting-outputs

# Localization key dosyası
dart run easy_localization:generate \
  -O lib/product/init/language -f keys \
  -o locale_keys.g.dart --source-dir assets/translations

# Analiz
flutter analyze

# Çalıştır (Android emülatör veya gerçek cihaz)
flutter run
```

> **Not:** `flutter pub run easy_localization:generate` Flutter 3.x'te
> exit 255 ile çökebilir. Bunun yerine `dart run` kullan.

---

## 16. Bilinen Kısıtlamalar

| Konu | Detay |
|------|-------|
| Min. Android (sistem sesi) | API 29 (Android 10) — AudioPlaybackCaptureConfiguration şartı |
| Dosya formatı | Sadece PCM WAV (AudioFormat=1). MP3/AAC/FLAC → FormatException |
| WAV header + dosya modu | `_wrapInWav` state.sampleRate/channels kullanır; dosya gerçek değerleri farklıysa header yanlış olur. Bu nedenle dosya modunda WAV header toggle'ı gizlenmiştir |
| easy_localization generator | v3.0.1'de yeni top-level key'leri atlar. audioStream.* key'leri locale_keys.g.dart'a elle ekli |
| UDP paket boyutu | MTU genellikle 1500 byte. bufferSize=4096 için UDP fragmentation oluşabilir |

---

_Son güncelleme: Claude tarafından — ses dosyası seçme özelliği eklendikten ve tam özellik doğrulama yapıldıktan sonra._
