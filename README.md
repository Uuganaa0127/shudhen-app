# Шүдхэн — хүүхдийн шүд угаалтын апп

Flutter апп (Android, iOS, web). Хүүхэд дөрвөн хэсгийн угаалтаа тэмдэглэж,
эмнэлгээс олгосон урилгаар `hospital-back` руу бүртгэлээ дамжуулна.
Камер нь хөдөлгөөн ажиглах туршилтын туслагч; угаалтын чанарыг баталгаажуулахгүй.
Камерын зураг/видео хадгалахгүй, серверт илгээхгүй.

## Шаардлага

- Dart ≥3.10 дэмждэг Flutter SDK.
- Android SDK 36; iOS build-д Xcode, CocoaPods, iOS ≥15.
- `hospital-back` дээр `2026_11_12_009_shudhen_care`,
  `2026_11_23_010_shudhen_rewards` migration ажилласан байна.
- Эмнэлгийн ажилтан `care.manage` эрхээр enrollment болон нэг удаагийн урилга үүсгэнэ.
  Өмнө тохируулсан эмчийн рольд админ `care.view`, `care.manage` эрхийг олгоно.

Backend гэрээ: [SHUDHEN_API.md](../hospital-back/SHUDHEN_API.md).

## Ажиллуулах

```sh
flutter pub get

# Android emulator → host дээрх backend
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8082/api/v1

# Desktop browser → host дээрх backend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8082/api/v1

# Production/test HTTPS API (Android, iOS, web)
flutter run --dart-define=API_BASE_URL=https://api.oyudent.com/hospital/api/v1
```

`API_BASE_URL` нь `/api/v1` хүртэлх URL; `/shudhen`-ийг client өөрөө нэмнэ.
Анхдагч API нь бүх платформд **https://api.oyudent.com/hospital/api/v1**.
Хаягийг `lib/connection/api.dart` дахь `hospitalApiBase` / `resolveApiBase` шийднэ.
Локал backend ашиглах бол дээрх `--dart-define=API_BASE_URL=...` override-ийг өгнө.
HTTP-г зөвхөн debug горимд зөвшөөрнө. Release/profile нь HTTPS ашиглана.
`--dart-define` өөрчилбөл run/build-ийг дахин эхлүүлнэ. Debug үед зөвшөөрлийн хүсэлт
алдахад ашиглаж буй API хаягийг дэлгэцэд харуулна. Deployed сервер дээр
`GET /hospital/api/v1/shudhen/consent` version/text JSON буцаадаг байх ёстой.

1. Эмнэлэг хүүхдийг өөрийн хяналтад бүртгэж, 24 цагийн нэг удаагийн урилга өгнө.
2. Асран хамгаалагч урилгын код, нэр, хамаарал, төхөөрөмжийн нэрээ оруулна.
3. Серверээс татсан зөвшөөрлийн текстийг уншиж, зөвшөөрсний дараа холбоно.
4. Апп хүүхдийн нэр/насны мэдээллийг API-аас авч, 30 хоногийн төхөөрөмжийн эрхийг хадгална.
5. Угаалтын бүртгэл локал commit болсон дараа дууссанд тооцогдоно; sync автоматаар ажиллана.

`123456` демо нэвтрэлт production урсгалд байхгүй. Хуучин `SharedPreferences`
доторх demo client, signedIn, careEvents-г серверийн хүүхэд гэж үзэхгүй, импортлохгүй.
Legacy demo utility файлууд нь шинэ auth/sync урсгалд ашиглагдахгүй.

## Хадгалалт ба sync

- Token болон cached profile: Android Keystore, iOS Keychain (`flutter_secure_storage`).
  Бичсэн/устгасан credential-ийг дахин уншиж шалгана. Token-ыг prefs/outbox/log-д хийхгүй.
- Android/iOS: SQLite transaction, `synchronous=FULL`; web: IndexedDB transaction.
  Browser credential storage нь тухайн origin-д хамаарах web plugin-ийн хадгалалт;
  native Keychain/Keystore-той адил хамгаалалтын хил гэж үзэхгүй. Web нь secure context
  (HTTPS эсвэл localhost) шаарддаг. Browser storage-г цэвэрлэхэд локал бүртгэл устна.
- UUID нь угаалт эхлэхэд нэг удаа үүснэ. 5 секунд тутам, хэсэг дуусахад, background
  болох үед draft checkpoint хадгална. Процесс гэнэт хаагдвал сүүлийн commit-оос
  хойших хадгалагдаагүй хугацаа алдагдаж болно; draft-ыг дараагийн нээлтээр
  сүүлийн хадгалсан цаг дээр `INTERRUPTED` болгон дамжуулна.
- `draft → pending → synced`; 400/409/413 хариутай бичлэг `blocked` болж хадгалагдана.
  Нэг blocked бичлэг дараагийн бичлэгүүдийг дамжуулахад саад болохгүй.
- Сүлжээ/5xx/429 үед pending хэвээр. 30 секунд тутам, апп resume хийхэд,
  угаалт дуусахад, “Одоо дамжуулах” товчоор дахин оролдоно. Sync single-flight;
  серверийн UUID/enrollment баталгаажуулалтгүйгээр synced гэж тэмдэглэхгүй.
- Сервер хадгалсан ч хариу тасарвал яг ижил UUID/payload-ыг дахин илгээнэ.
  SQLite ack commit унавал мөн pending хэвээр үлдэж, retry аюулгүй байна.
- Enrollment болон backend URL бүрээр локал өгөгдөл тусгаарлагдана. Өөр хүүхэдтэй
  холбох үед хуучин pending өгөгдлийг шинэ хүүхдийн token-оор илгээхгүй.
- 401/expiry үед pending устахгүй, “Дахин холбох” урсгал үзүүлнэ. Ижил enrollment-д
  шинэ урилга авбал үлдсэн pending дамжина; өөр enrollment-д автоматаар шилжүүлэхгүй.
- Гарахад credential-ийг устгаж, серверийн logout дуудна. Сүлжээгүй бол локал гаралт
  амжилттай боловч серверийн эрхийг эмнэлгээс цуцлуулах шаардлагатайг харуулна.
  Pending болон түүхийг logout устгахгүй.
- Нэг хэсэг ≥30 секунд × дөрвөн хэсэг биелсэн terminal session л локал од авна.
  Энэ нь эмнэлгийн шагналын ledger биш; бусад төхөөрөмжийн түүхийг татаж нэгтгэх,
  од зарцуулах функц энэ үе шатанд ороогүй.
- Календарийн өдрийг session-ийн IANA time zone-оор тооцно. Android/iOS native
  channel, browser Intl-оос бүсийг авч, боломжгүй бол UTC хэрэглэнэ.

Нүүр/тохиргоонд pending, blocked, сүүлийн дамжуулсан цаг, дахин холбох төлөв харагдана.
Нэр болон нас нь серверийн profile-оос; browser localStorage-ийн хуучин profile bridge
ашиглахгүй. Сануулгын тохиргоо enrollment тус бүрээр тусгаарлагдсан.

## Шалгалт

```sh
flutter analyze --no-fatal-infos
flutter test
flutter test --platform chrome test/web/store_test.dart
flutter build apk --debug
flutter build web --debug
```

Тестүүд offline restart, SQLite close/reopen, дискний алдаа, ижил UUID retry,
зэрэгцээ sync, 401/expiry, өөр хүүхэд/сервер рүү credential шилжихгүй байх,
зөвшөөрөлгүй exchange хийхгүй байх, logout/profile race болон камерын save failure-г шалгана.
Chrome-ийн тусдаа тест нь IndexedDB commit/reopen, scope тусгаарлалт, Intl timezone-ийг шалгана.

Бодит API-ийн opt-in тестийг зөвхөн тусдаа тест enrollment/шинэ урилга дээр ажиллуулна.
Түр JSON fixture нь `{ "baseUrl": "http://127.0.0.1:8082/api/v1",
"invitation": "<fresh token>", "enrollmentId": "<UUID>" }` байна.
Тест урилгыг хэрэглэж, угаалт үүсгээд төхөөрөмжийн эрхийг цуцална. Файлыг repository-д
хийхгүй, туршилтын дараа устгана. PostgreSQL backend ажиллаж байх шаардлагатай.

```sh
SHUDHEN_LIVE_FIXTURE=/private/tmp/shudhen-fixture.json \
  flutter test test/live_api_test.dart
```

## Build ба үлдсэн ажил

```sh
flutter build apk --release --dart-define=API_BASE_URL=https://api.oyudent.com/hospital/api/v1
flutter build ios --release --dart-define=API_BASE_URL=https://api.oyudent.com/hospital/api/v1
```

Android release signing одоогоор debug key хэвээр; application/bundle ID ч demo нэртэй.
Store-д гаргахаас өмнө бодит ID, release signing болон production API deployment-ийг шалгана.
Энэ өөрчлөлтөөр deploy хийгээгүй, бодит эмнэлгийн DB-д өгөгдөл нэмээгүй.

Дараагийн үе шат: hospital-front дээр урилга үүсгэх, хүүхдийн угаалтыг харах “Шүдхэн”
таб/dashboard. Одоогоор урилгыг backend API-аар үүсгэж, апп дээр хуулж оруулна;
QR scanner болон баталгаажсан олон хүүхэдтэй guardian account тусдаа ажил.

## Динамик бэлэг

Эмнэлэг хүүхдийн Шүдхэн хэсэгт бэлгийн нэр, зураг, дараалсан өдрийн тоог тохируулна.
Аппын `/me` хариу дахь `rewards` нь идэвхтэй бэлгүүдийн ахиц, цуглуулсан бэлгийн
сүүлийн 50 бичлэг, нийт тоог агуулна. Жишээ: 7 өдөр тутам жижиг бэлэг, 30 өдөр тутам
том бэлэг зэрэг ажиллана. Өдөр тасарвал ахиц дахин эхэлнэ; авсан бэлэг хадгалагдана.
Өдрийг Asia/Ulaanbaatar цагаар, тохируулга хийснээс хойших серверт ирсэн бүрэн
120 секундын зорилтот session-оор тооцно. Нэг өдрийн олон угаалт нэг өдөрт тооцогдоно.

Бэлэг нь sync-ийн дараах profile refresh-ээр шинэчлэгдэнэ. Profile-ийн бэлгийн
offline cache нь API base + enrollment scope-оор тусгаарлагдсан SharedPreferences
түлхүүртэй; төхөөрөмжийн bearer credential нь өмнөх secure storage-д үлдэнэ.
Offline ахиц нь баталгаажсан сүүлийн тоо; тасарсан өдөр өнгөрвөл харагдах ахиц 0 болно.
Кэш хадгалагдахгүй байсан ч угаалтын бүртгэл, outbox sync үргэлжилнэ.
