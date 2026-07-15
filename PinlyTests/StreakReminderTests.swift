import XCTest
import UserNotifications
@testable import Pinly

// MARK: - Mock

final class MockNotificationScheduler: NotificationScheduling {
    var weeklyNotificationScheduled = false
    var streakReminderDays: Int? = nil

    func scheduleWeeklyNotification() {
        weeklyNotificationScheduled = true
    }

    func requestWeeklyNotification() {
        weeklyNotificationScheduled = true
    }

    func scheduleStreakReminder(consecutiveDays: Int) {
        streakReminderDays = consecutiveDays
    }
}

// MARK: - Tests

final class StreakReminderTests: XCTestCase {

    func test_scheduleStreakReminder_sifirGundeCagrilmaz() {
        let mock = MockNotificationScheduler()
        mock.scheduleStreakReminder(consecutiveDays: 0)
        XCTAssertEqual(mock.streakReminderDays, 0)
    }

    func test_scheduleStreakReminder_pozitifGundeCagrilir() {
        let mock = MockNotificationScheduler()
        mock.scheduleStreakReminder(consecutiveDays: 5)
        XCTAssertEqual(mock.streakReminderDays, 5)
    }

    func test_scheduleStreakReminder_buyukGunDegeriniIletir() {
        let mock = MockNotificationScheduler()
        mock.scheduleStreakReminder(consecutiveDays: 30)
        XCTAssertEqual(mock.streakReminderDays, 30)
    }

    func test_weeklyNotification_bagimsizCalisir() {
        let mock = MockNotificationScheduler()
        mock.scheduleWeeklyNotification()
        XCTAssertTrue(mock.weeklyNotificationScheduled)
        XCTAssertNil(mock.streakReminderDays)
    }
}
