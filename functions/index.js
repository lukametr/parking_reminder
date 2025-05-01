// Импортируем модуль firebase-functions для определения облачных функций
import { firestore } from "firebase-functions";

// Импортируем модуль firebase-admin для взаимодействия с Firebase Admin SDK
import { initializeApp, firestore as _firestore, messaging } from "firebase-admin";

// Инициализируем приложение Firebase Admin
initializeApp();

exports.sendParkingNotification = firestore
    .document("parkings/{parkingId}")
    .onUpdate(async (change, context) => {
        // Извлекаем новые данные документа после обновления
        const newData = change.after.data();

        try {
            // Получаем снимок коллекции "users" (пользователи)
            const usersSnapshot = await _firestore().collection("users").get();

            // Массив промисов для отправки уведомлений каждому пользователю
            const notificationPromises = [];

            // Проходим по каждому документу пользователя в коллекции
            usersSnapshot.forEach((userDoc) => {
                // Извлекаем токен для получения push-уведомлений
                const userToken = userDoc.data().fcmToken;

                // Формируем полезную нагрузку (payload) уведомления
                const payload = {
                    notification: {
                        title: "Близкая парковка!", // Заголовок уведомления
                        body: `Лот №${newData.lotNumber}` // Текст уведомления с номером лота
                    }
                };

                // Добавляем промис отправки уведомления в массив для дальнейшего ожидания
                notificationPromises.push(
                    messaging().sendToDevice(userToken, payload)
                );
            });

            // Ждем завершения отправки уведомлений для всех пользователей
            await Promise.all(notificationPromises);

            // Возвращаем null для успешного завершения функции
            return null;
        } catch (error) {
            // Логируем ошибку для последующего анализа
            console.error("Ошибка при отправке уведомлений:", error);
            // Можно дополнительно обработать ошибку, например, вернуть ее или выполнить другие действия
            throw new Error("Ошибка при отправке уведомлений"); // Завершаем выполнение функции с ошибкой
        }
    });
