# Live River & Road Studio v0.3.0

Godot 4.8 + Terrain3D uchun daryo va yo'l plagini.

## Yangiliklar

### 1. Ikonkalar
- Tugmalar: Add Point, Live Terrain, Snap, Downhill, Carve, Revert, Ko'prik, Tekstura — hammasida ikonka.
- Nodelar: `LiveRiver3D`, `LiveRoad3D` (Scene daraxtida ikonka bilan).
- Resurslar: `LiveBridgeSettings`, `LiveTextureSet`.
- Inspektordagi tool tugmalarida ham ikonka bor.

### 2. Avtomatik ko'priklar
Yo'l daryoni kesib o'tganda ko'prik o'zi quriladi (har qanday burchak va egri daryo uchun).
Yo'l ko'prik balandligiga silliq ko'tariladi, terrain daryo kanalida buzilmaydi.

| Shakl | Tavsif |
|---|---|
| Plita (Beam) | Beton plita, devor/yumaloq tayanchlar |
| Tosh arka | Ko'p arkali tosh ko'prik, parapet |
| Bukri arka | Bitta baland arka |
| Yog'och | Taxtalar, ustunlar, X mustahkamlagichlar, yog'och to'siq |
| Ferma (Truss) | Po'lat Warren fermasi |
| Osma ko'prik | Minoralar, arqonlar, osma simlar |

Sozlanadi: kenglik, qalinlik, ko'tarilish, suvdan balandlik, tayanchlar (soni/shakli),
arkalar, panjara (4 tur), ferma, minora, bordyur, taxtalar va boshqalar.

**Ishlatish:** `LiveRoad3D` ni tanlang → toolbar'dagi **Ko'prik** tugmasi va shakl menyusi.
Barcha sozlamalar `bridge_settings` resursida (inspektorda). Uni `.tres` qilib saqlab,
boshqa yo'llarda qayta ishlatish mumkin.

### 3. O'z ko'prik modelingiz
`bridge_settings` → **O'z mesh (Custom)**: `custom_mesh` yoki `custom_scene`.
- Mesh uzunligi **Z o'qi** bo'ylab, ko'prik usti **Y = 0** da bo'lsin. Markaz avtomatik moslanadi.
- Moslashish: uzunlikka cho'zish / butunlay cho'zish / takrorlash (tile) / asl o'lcham.
- Siljish, burish, masshtab, material, collision sozlanadi.

### 4. Tekstura va Material paneli
Toolbar'dagi **Tekstura** tugmasi bitta oyna ochadi (Undo/Redo bilan):
- **Yo'l:** tayyor turlar (asfalt, tuproq, shag'al, qum, bruschatka), ranglar, sirt, o'rta va chekka chiziqlar.
- **Tekstura:** albedo, normal, roughness, AO, tiling, offset, tint (`LiveTextureSet` resursi).
- **Suv:** tayyor turlar (toza, feruza, botqoq, loyqa, ko'l), rang, to'lqin, ko'pik, 2 ta normal map, ko'pik teksturasi.
- **Ko'prik:** shakl va barcha o'lchamlar; **Ko'prik materiali:** konstruksiya/panjara/usti uchun material yoki tekstura.
- **O'z mesh:** model yuklash va joylashtirish.

Inspektorda ham: `custom_material` (istalgan Material bilan to'liq almashtirish),
**Materialni tahrirlash (nusxa)** tugmasi — standart shaderning barcha parametrlarini ochadi.

## O'rnatish
`addons/live_river_road/` papkasiga ko'chiring, Project Settings → Plugins'da yoqing.
Eski sahnalar ishlaydi (mavjud xususiyat nomlari o'zgarmagan).

## Eslatmalar
- Ko'prik node'lari sahnaga saqlanmaydi, har yuklashda qayta quriladi (`LiveBridges` — yo'l ichida).
- Ko'prik daryoni topishi uchun daryo va yo'l bir sahnada bo'lishi kerak.
- Daryo kanali yo'l tomonidan to'ldirilmasligi uchun yo'l carve'i daryo yo'lagini o'tkazib yuboradi (`auto_bridges` yoqiq bo'lsa).


---

## v0.3.0 yangiliklar

### Chorrahalar va aylana (roundabout)
- Yo'llar kesishganda (yoki bir yo'l uchi boshqasiga tegsa — T-chorraha) avtomatik **chorraha** quriladi: yumaloq burchaklar, yo'llar chorraha chetida aniq kesiladi, balandlik silliq tenglashadi.
- Yo'nalishlar soni `roundabout_min_arms` (standart 5) dan oshsa **aylana** quriladi: halqa yo'l, kengayuvchi kirishlar, o'rta orolcha (bordyur + o'z sahnangizni qo'yish mumkin).
- Sozlamalar: `LiveRoad3D.junction_settings` (tur: Avtomatik / Chorraha / Aylana / Yo'q, burchak radiusi, aylana radiusi va kengligi, orolcha rangi/materiali va h.k.).
- Toolbar: **Chorraha** tugmasi va tur menyusi.
- Chorraha eng kichik ID li yo'lga tegishli bo'ladi; uning sozlamalari ishlatiladi.

### Yoritgichlar (MultiMesh)
- Toolbar'da **Yoritgich** tugmasini yoqing → yo'lni tanlab, kerakli Path3D nuqtalarini **Shift+Click** bilan belgilang (qayta bosilsa belgi olinadi). Belgilar sariq halqa bilan ko'rinadi.
- Rejimlar: faqat belgilangan nuqtalarda (`POINTS`) yoki belgilangan juftliklar orasida har N metrda (`RANGE`).
- Tomon: chap / o'ng / ikkala / navbatma-navbat. Chetdan masofa, balandlik, qo'l uzunligi, rang va nur kuchi sozlanadi.
- Hammasi bitta `MultiMeshInstance3D` — FPS tushmaydi. O'z modelingizni `custom_mesh` ga qo'yish mumkin. Haqiqiy yorug'lik (OmniLight3D) ixtiyoriy.

### Keskin burilishlar
- Ichki chekka burilish radiusidan oshmaydi (o'zini kesib o'tmaydi), tashqi chekka miter bilan uzayadi.
- UV har bir chekka uchun o'z yoy uzunligi bo'yicha hisoblanadi: tekstura cho'zilmaydi va bukilmaydi.
