# 🔥 Firebase დაყენების ინსტრუქციები

## 📋 **თქვენი Firebase პროექტის მონაცემები:**
- **Project Name:** `ParkingReminder`
- **Project ID:** `parkingreminder-6466d`
- **Project Number:** `155641305476`

## 📁 **google-services.json ფაილის დაყენება:**

### ნაბიჯი 1: Firebase Console-ზე შესვლა
1. გახსენით [Firebase Console](https://console.firebase.google.com/)
2. აირჩიეთ თქვენი პროექტი: `ParkingReminder`

### ნაბიჯი 2: Android აპლიკაციის დამატება
1. Project Overview-ზე დააჭირეთ "Add app"
2. აირჩიეთ Android ხატი
3. შეიყვანეთ პაკეტის სახელი:
   ```
   com.parkingreminder.app
   ```
4. ჩამოტვირთეთ "Register app"

### ნაბიჯი 3: google-services.json-ის ჩამოტვირთვა
1. ჩამოტვირთეთ "Download google-services.json"
2. შეინახეთ ფაილი აქ:
   ```
   android/app/google-services.json
   ```

### ნაბიჯი 4: Remote Config პარამეტრების დაყენება
1. გადადით Remote Config განყოფილში
2. შექმნეთ პარამეტრები:
   ```
   ads_enabled: boolean (default: true)
   banner_ad_frequency: number (default: 3)
   interstitial_ad_frequency: number (default: 10)
   ```
3. გამოაქვენით და გააქტიურეთ

## 🔧 **შემოწმება:**
- ✅ ფაილი უნდა იყოს `android/app/` საქაღალდეში
- ✅ პაკეტის სახელი უნდა იყოს `com.parkingreminder.app`
- ✅ დააკოპირეთ ფაილი პროექტში

## 🚀 **შემდეგი:**
ახლა Firebase ინტეგრაცია სრულად იმუშავს და მონეტიზაცია ხელმისამართად მუშაობს!
