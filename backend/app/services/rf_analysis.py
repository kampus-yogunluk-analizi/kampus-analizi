"""
RF (Radyo Frekans) Analiz Modülü
---------------------------------
Kablosuz Ağlar dersi kapsamında kullanılan teorik hesaplamalar:
  - Log-Distance Path Loss Modeli  → mesafe tahmini
  - SNR (Signal-to-Noise Ratio)    → sinyal/gürültü oranı
  - Shannon Kanal Kapasitesi       → teorik maksimum veri hızı
  - BER (Bit Error Rate) Tahmini   → BPSK/QPSK ile bit hata oranı
  - Kanal Girişim Skoru            → yoğunluk bazlı interference
"""

import math

# ── Sabitler ──────────────────────────────────────────────────────────────────

# Bluetooth LE iBeacon: 1m referans mesafesindeki RSSI ≈ -59 dBm
BLE_TX_POWER_DBM: float = -59.0

# Çevre faktörü (path loss exponent):
#   2.0 = serbest alan,  2.5 = hafif engel,  3.5 = yoğun iç mekan
INDOOR_PATH_LOSS_EXP: float = 2.7

# Gürültü katı (thermal noise floor, 2.4 GHz iç mekan için tipik değer)
NOISE_FLOOR_DBM: float = -95.0

# WiFi 2.4 GHz standart kanal genişliği (MHz)
WIFI_CHANNEL_BW_MHZ: float = 20.0

# BLE kanal genişliği (MHz)
BLE_CHANNEL_BW_MHZ: float = 2.0

# Kanal kapasitesi sınır eşikleri (bina başına Mbps)
CAPACITY_EXCELLENT_MBPS: float = 50.0
CAPACITY_GOOD_MBPS: float = 20.0
CAPACITY_FAIR_MBPS: float = 5.0

# Kanal girişimi: bu cihaz sayısının üzerinde 2.4 GHz doyuma ulaşır
CHANNEL_SATURATION_DEVICES: int = 25


# ── Yardımcı ──────────────────────────────────────────────────────────────────

def _clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(v, hi))


# ── 1. Log-Distance Path Loss → Mesafe Tahmini ───────────────────────────────

def estimate_distance_m(
    rssi: float,
    tx_power: float = BLE_TX_POWER_DBM,
    n: float = INDOOR_PATH_LOSS_EXP,
) -> float:
    """
    Log-Distance Path Loss Modeli ile mesafe tahmini (metre).

    Formül:  RSSI = TX_Power - 10·n·log₁₀(d)
             d    = 10 ^ ((TX_Power - RSSI) / (10·n))

    Parametreler:
        rssi     : ölçülen alınan sinyal gücü (dBm)
        tx_power : 1 m mesafedeki referans RSSI (dBm), varsayılan BLE iBeacon
        n        : ortam yol kaybı üssü (2.0–4.0)

    Referans: Rappaport, T.S. (2002) "Wireless Communications", Bölüm 3.
    """
    if rssi >= tx_power:
        return 0.5  # çok yakın, model sınırı
    exponent = (tx_power - rssi) / (10.0 * n)
    return round(_clamp(10 ** exponent, 0.5, 200.0), 2)


# ── 2. SNR Hesabı ─────────────────────────────────────────────────────────────

def calculate_snr_db(
    rssi: float,
    noise_floor: float = NOISE_FLOOR_DBM,
) -> float:
    """
    Sinyal/Gürültü Oranı (dB).

    SNR_dB = RSSI_dBm - NoiseFloor_dBm

    Referans: IEEE 802.11 Std, Bölüm 17 (PHY katmanı).
    """
    return round(max(0.0, rssi - noise_floor), 2)


def snr_linear(snr_db: float) -> float:
    """dB → lineer dönüşüm:  SNR_lin = 10^(SNR_dB / 10)"""
    return 10 ** (snr_db / 10.0)


# ── 3. Shannon Kanal Kapasitesi ───────────────────────────────────────────────

def calculate_shannon_capacity_mbps(
    snr_db: float,
    bandwidth_mhz: float = WIFI_CHANNEL_BW_MHZ,
) -> float:
    """
    Shannon–Hartley teoremi: teorik maksimum kanal kapasitesi.

    C = B · log₂(1 + SNR_lin)   [bit/s]

    Parametreler:
        snr_db        : Sinyal/Gürültü oranı (dB)
        bandwidth_mhz : Kanal bant genişliği (MHz)

    Referans: Shannon, C.E. (1948) "A Mathematical Theory of Communication".
    """
    snr_lin = snr_linear(snr_db)
    capacity_mbps = bandwidth_mhz * math.log2(1 + snr_lin)
    return round(capacity_mbps, 2)


def classify_channel_quality(snr_db: float) -> str:
    """
    IEEE 802.11 önerilerine göre SNR → kanal kalitesi sınıflandırması.
    >25 dB Mükemmel, 15–25 dB İyi, 10–15 dB Orta, <10 dB Zayıf
    """
    if snr_db >= 25:
        return "excellent"
    if snr_db >= 15:
        return "good"
    if snr_db >= 10:
        return "fair"
    return "poor"


# ── 4. Bit Hata Oranı (BER) Tahmini ─────────────────────────────────────────

def estimate_ber(snr_db: float, modulation: str = "bpsk") -> float:
    """
    BPSK / QPSK için teorik Bit Error Rate tahmini.

    BPSK:  BER = Q(√(2·Eb/N₀)) = ½·erfc(√(SNR_lin))
    QPSK:  BER = Q(√(2·Eb/N₀)) ≈ BPSK  (aynı Eb/N₀ için)

    Pratik not: Bu hesaplama AWGN (Additive White Gaussian Noise) kanalını
    varsayar. Çok-yollu solma (multipath fading) ortamlarında gerçek BER daha
    yüksek olabilir.

    Referans: Proakis, J. (2001) "Digital Communications", 4th ed., Bölüm 5.
    """
    snr_lin = snr_linear(snr_db)
    ber = 0.5 * math.erfc(math.sqrt(snr_lin))
    return float(f"{ber:.2e}")  # bilimsel gösterim hassasiyeti koru


def ber_to_quality(ber: float) -> str:
    if ber < 1e-6:
        return "excellent"
    if ber < 1e-4:
        return "good"
    if ber < 1e-2:
        return "fair"
    return "poor"


# ── 5. Kanal Girişim (Interference) Skoru ────────────────────────────────────

def calculate_interference_score(
    device_count: int,
    signal_strength: float,
    capacity: int = 120,
) -> int:
    """
    Kanal yük ve sinyal çakışmasına dayalı girişim tahmini (0–100).

    Yüksek cihaz sayısı + zayıf sinyal = yüksek interference.

    Model:
        load_factor     = device_count / saturation_threshold
        signal_degraded = 1 - signal_quality  (zayıf sinyal → daha çok çakışma)
        IS = (load_factor · 0.6 + signal_degraded · 0.4) × 100

    Referans: Mishra, A. (2008) "Fundamentals of Network Planning", Bölüm 4.
    """
    load_factor = _clamp(device_count / max(CHANNEL_SATURATION_DEVICES, 1), 0, 1)
    signal_quality = _clamp(
        (signal_strength - NOISE_FLOOR_DBM) / (-35.0 - NOISE_FLOOR_DBM),
        0, 1,
    )
    signal_degraded = 1.0 - signal_quality
    score = (load_factor * 0.6 + signal_degraded * 0.4) * 100
    return round(_clamp(score, 0, 100))


def recommend_channel(interference_score: int, device_count: int) -> str:
    """
    Girişim skoru ve cihaz yoğunluğuna göre kanal/bant önerisi.
    Düşük girişim → 2.4 GHz yeterli.
    Orta → 5 GHz tercih et.
    Yüksek → 6 GHz (Wi-Fi 6E) gerekli.
    """
    if interference_score >= 60 or device_count >= CHANNEL_SATURATION_DEVICES:
        return "6 GHz (Wi-Fi 6E)"
    if interference_score >= 30 or device_count >= 10:
        return "5 GHz (Wi-Fi 5/6)"
    return "2.4 GHz (Wi-Fi 4/5)"


# ── Birleşik RF Raporu ────────────────────────────────────────────────────────

def build_rf_report(
    rssi: float,
    device_count: int,
    capacity: int = 120,
) -> dict:
    """
    Tek RSSI + cihaz sayısından tüm RF metriklerini hesaplar.
    API ve WebSocket payload'larına doğrudan eklenebilir.
    """
    distance = estimate_distance_m(rssi)
    snr = calculate_snr_db(rssi)
    capacity_mbps = calculate_shannon_capacity_mbps(snr, WIFI_CHANNEL_BW_MHZ)
    ber = estimate_ber(snr)
    interference = calculate_interference_score(device_count, rssi, capacity)

    return {
        "rf": {
            "estimated_distance_m": distance,
            "snr_db": snr,
            "channel_quality": classify_channel_quality(snr),
            "shannon_capacity_mbps": capacity_mbps,
            "ber": ber,
            "ber_quality": ber_to_quality(ber),
            "interference_score": interference,
            "recommended_channel": recommend_channel(interference, device_count),
            # Formüllerin referans değerleri — hocanın görmesi için
            "formulas": {
                "path_loss": f"d = 10^(({BLE_TX_POWER_DBM} - {rssi}) / (10 × {INDOOR_PATH_LOSS_EXP})) = {distance} m",
                "snr": f"SNR = {rssi} - ({NOISE_FLOOR_DBM}) = {snr} dB",
                "shannon": f"C = {WIFI_CHANNEL_BW_MHZ} × log₂(1 + 10^({snr}/10)) = {capacity_mbps} Mbps",
                "ber": f"BER = ½·erfc(√(10^({snr}/10))) ≈ {ber}",
            },
        }
    }
