# Kampus Yogunluk Analizi Taslagi

Bu taslak sistem kablosuz ag access point verilerini kampus bolgelerine esleyip mobil arayuzde basit bir isi haritasi olarak gosterir.

## Olusturulan ana dosyalar

- `backend/app/main.py`: FastAPI uygulamasini, CORS ayarlarini, REST route'larini ve WebSocket endpoint'ini baglar.
- `backend/app/models/schemas.py`: API veri sozlesmeleri. Access point, baglanti olayi ve yogunluk snapshot modelleri burada.
- `backend/app/services/density_service.py`: Demo yogunluk hesaplama mantigi. Gercek sistemde controller/AP loglari veya RADIUS kayitlari buraya akar.
- `backend/app/api/routes.py`: `/access-points`, `/density`, `/connections`, `/simulate` endpoint'leri.
- `backend/app/websocket/manager.py`: Mobil uygulamaya 2 saniyede bir guncel yogunluk snapshot'i yayinlar.
- `mobile/lib/main.dart`: Kampus haritasi, isi noktasi painter'i, WebSocket baglantisi ve bolge listesi.

## Calistirma

Backend:

```powershell
cd backend
.\venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Mobil:

```powershell
cd mobile
flutter run
```

Android emulator backend'e erisemiyorsa:

```powershell
flutter run --dart-define=API_HOST=10.0.2.2:8000
```

## Gercek sisteme genisletme

1. Access point envanterini veritabanina tasi.
2. Kablosuz controller, RADIUS veya DHCP loglarindan `ap_id`, cihaz kimligi ve sinyal gucu olaylarini al.
3. `DensityService.register_connection` icinde cihazlari zaman penceresine gore tekillestir.
4. Yogunluk formulunu kapasite, cihaz sayisi, RSSI ve son gorulme zamanina gore agirliklandir.
5. Mobil haritaya gercek kampus planini asset olarak ekle ve `map_x/map_y` koordinatlarini bu plana gore kalibre et.
