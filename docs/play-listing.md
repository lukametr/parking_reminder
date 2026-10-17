# Play Console paste pack (`com.findall.ParkingReminder`)

We cannot sign into LM’s Play account. Paste these.

## Store listing (ka)

**App name:** პარკინგის შეხსენება

**Short description:** თბილისის ზონალური პარკინგი — ლოტი, ოფიციალური აპი, SOS.

**Full description:**
თბილისის ფასიან ზონალურ პარკინგზე გაჩერებისას აპი გიჩვენებთ ლოტის ნომერს და გეკითხებათ, გსურთ თუ არა პარკირების ჩართვა. დიახ — იხსნება ოფიციალური აპი ge.msda.parking (MSDA); თუ არ გაქვთ, Play Store. ლოტიდან გასვლისას შეგახსენებთ, რომ **გამორთოთ** პარკირება იქვე. საფასური წუთებში ითვლება — აპი დროს არ ითვლის.

ფონური მონიტორინგი: Android foreground location (მუდმივი შეტყობინება). SOS: 112 და დაზღვევა. სერვისები: კვება, მაღაზია, აფთიაქი, საწვავი, ვულკანიზაცია.

**Privacy policy URL:** https://cdn.jsdelivr.net/gh/lukametr/parking_reminder@gh-pages/privacy/index.html  
(Preferred after Pages enable: https://lukametr.github.io/parking_reminder/privacy/)

## Data safety

| Question | Answer |
| --- | --- |
| Collects user data? | Yes |
| Precise location | Yes, on-device, required. **Background: yes** |
| Approximate location | No |
| Account / name / email | No |
| Crash logs | Firebase Crashlytics |
| Device IDs | Advertising ID (AdMob banner) |
| Encrypted in transit | Yes |
| Sold | No |
| Ads | AdMob banner; we do not sell location |

## Background location declaration

**Video:** grant “Allow all the time” → minimize → stop on a lot → overlay/notification with lot number → confirm opens `ge.msda.parking` or Play Store → leave lot → “turn parking OFF” reminder. Ongoing notification “მონიტორინგი ჩართულია”.

**Text:** This app detects when a Tbilisi driver has stopped on a paid zonal lot so they can start or stop payment in the official MSDA parking app. That only works with location while the app is not on screen. Visible foreground service, Fused Location, Activity Recognition (high-accuracy when still), geofences around nearby lots. No live track is uploaded. User can stop monitoring by closing the app or revoking always-allow.

## AdMob interstitial (LM)

https://admob.google.com → app `ca-app-pub-8872582533953072~4948596381` → Add interstitial → put ID in `lib/config/ad_config.dart` replacing `/0000000000`.

## Maps rotate (LM)

Cloud Console → Credentials → rotate the key that was on GitHub. Restrict Android app `com.findall.ParkingReminder`, SHA-1 `AC:FF:5F:5F:3A:48:8A:47:FD:68:B0:C6:29:10:B6:43:B3:CF:8E:4C`. Maps SDK, Places API (New), Directions API. Then GitHub secret `MAPS_API_KEY`.
