# Privacy Policy — პარკინგის შეხსენება

Last updated: 17 October 2026

This app (**პარკინგის შეხსენება**, Android package `com.findall.ParkingReminder`) helps Tbilisi drivers remember zonal parking. It is **not** an account-based social network.

## Location (we do collect it)

The core feature requires **precise location**, including **while the app is in the background** and after reboot if you enable monitoring.

- We compare your position to public Tbilisi parking-lot coordinates (Firestore `parkings`, ~15 m). If you stop on a lot we ask whether to start parking in the official MSDA app; when you leave we remind you to turn parking **off** there. There is **no** timed (55-minute / hourly) countdown — zonal parking is billed per minute.
- Location is processed **on the device** in a foreground location service (persistent notification: “მონიტორინგი ჩართულია”).
- We do **not** require a login. We do **not** upload ongoing GPS tracks. Parking sessions are stored **locally** on the phone.
- If you deny “Allow all the time”, foreground reminders while the app is open may still work; **background reminders will not**.

## Other data

- **Crash logs** (Firebase Crashlytics): device model, OS, stack traces — to fix bugs.
- **Remote Config**: image URLs / ad flags from Firebase.
- **Ads** (Google AdMob): advertising ID / approximate signals per Google’s policies. You can reset or opt out of ads personalization in device settings.
- **Maps / Places** (optional screens): Google receives the query location to show nearby services. Requires a Maps API key configured by the developer.
- **SOS**: tapping 112 or insurance opens the phone dialer. We do not place the call ourselves or store the number you dial.

We do not sell your data. We do not use your location to build advertising profiles in our own systems.

## Permissions

- Fine / background location
- Physical activity (to use high-accuracy GPS only when you appear parked, and save battery while moving)
- Notifications
- Internet

## Contact

GitHub: [lukametr/parking_reminder](https://github.com/lukametr/parking_reminder)

Live HTML: https://cdn.jsdelivr.net/gh/lukametr/parking_reminder@gh-pages/privacy/index.html

## ქართულად (მოკლე)

აპი **ზუსტ ლოკაციას** იყენებს, მათ შორის **ფონში**, რომ გაიგოს, ხართ თუ არა თბილისის ზონალურ ლოტთან. მონიტორინგისას ეკრანზე რჩება მუდმივი შეტყობინება. GPS ტრეკს სერვერზე არ ვტვირთავთ. სესია ინახება ტელეფონზე. თუ „ყოველთვის“ უარს იტყვით, ფონური შეხსენება არ იმუშავებს.
