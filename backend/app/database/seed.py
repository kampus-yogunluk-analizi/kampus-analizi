from sqlalchemy.orm import Session

from app.models.models import Building


def seed_campus_data(db: Session):
    locations = [
        {"name": "Rektörlük", "lat": 38.33638407193362, "lng": 38.42932427341704},
        {
            "name": "Sağlık Bilimleri Fakültesi",
            "lat": 38.33558135080642,
            "lng": 38.4278677862198,
        },
        {
            "name": "Hemşirelik Fakültesi",
            "lat": 38.33552229504526,
            "lng": 38.428196989721144,
        },
        {
            "name": "Diş Hekimliği Fakültesi",
            "lat": 38.33530898420461,
            "lng": 38.426227359585376,
        },
        {
            "name": "Eczacılık Fakültesi",
            "lat": 38.334806782361085,
            "lng": 38.426814252960185,
        },
        {"name": "Tıp Fakültesi", "lat": 38.33705226721253, "lng": 38.43107175356755},
        {
            "name": "Sağlık Hizmetleri MYO",
            "lat": 38.333696422527545,
            "lng": 38.430569996687645,
        },
        {
            "name": "İlahiyat Fakültesi",
            "lat": 38.33075287920109,
            "lng": 38.43372135090098,
        },
        {
            "name": "Güzel Sanatlar Fakültesi",
            "lat": 38.328183628498316,
            "lng": 38.43363758563837,
        },
        {"name": "Kütüphane", "lat": 38.33342037814871, "lng": 38.4393494427308},
        {
            "name": "İnönü Üniversitesi Camii",
            "lat": 38.33076581963078,
            "lng": 38.43743817696971,
        },
        {
            "name": "Öğrenci İşleri",
            "lat": 38.330427846988925,
            "lng": 38.44172624579099,
        },
        {
            "name": "Eğitim Fakültesi",
            "lat": 38.331359298138544,
            "lng": 38.44274850257371,
        },
        {
            "name": "Hukuk Fakültesi",
            "lat": 38.333359821367694,
            "lng": 38.44326932679481,
        },
        {"name": "İİBF", "lat": 38.33259467174955, "lng": 38.44304052123137},
        {
            "name": "Eğitim Fakültesi C Blok",
            "lat": 38.332042453037005,
            "lng": 38.44383933955349,
        },
        {
            "name": "İletişim Fakültesi",
            "lat": 38.32996124634677,
            "lng": 38.44499933754838,
        },
        {
            "name": "Yabancı Dil Fakültesi",
            "lat": 38.33055384514514,
            "lng": 38.446392299755495,
        },
        {
            "name": "Spor Bilimleri Fakültesi",
            "lat": 38.33202907193111,
            "lng": 38.447939304348026,
        },
        {
            "name": "Mühendislik A Blok",
            "lat": 38.32974281195541,
            "lng": 38.44726961147349,
        },
        {
            "name": "Mühendislik B Blok",
            "lat": 38.32943785344574,
            "lng": 38.448128201674294,
        },
    ]

    for loc in locations:
        building = db.query(Building).filter(Building.name == loc["name"]).first()

        if building is None:
            building = (
                db.query(Building)
                .filter(
                    Building.latitude == loc["lat"],
                    Building.longitude == loc["lng"],
                )
                .first()
            )

        if building is None:
            db.add(
                Building(
                    name=loc["name"],
                    latitude=loc["lat"],
                    longitude=loc["lng"],
                )
            )
        else:
            building.name = loc["name"]
            building.latitude = loc["lat"]
            building.longitude = loc["lng"]

    db.commit()
