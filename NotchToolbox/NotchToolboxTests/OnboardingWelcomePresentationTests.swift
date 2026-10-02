import Foundation
import Testing
@testable import NotchToolbox

struct OnboardingWelcomePresentationTests {
    @Test(arguments: [
        (hour: 5, expected: "早上好"),
        (hour: 11, expected: "早上好"),
        (hour: 12, expected: "下午好"),
        (hour: 17, expected: "下午好"),
        (hour: 18, expected: "晚上好"),
        (hour: 4, expected: "晚上好")
    ])
    func greetingMatchesLocalHour(hour: Int, expected: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: 6,
            hour: hour
        ))!

        #expect(OnboardingWelcomePresentation.greeting(at: date, calendar: calendar) == expected)
    }
}
