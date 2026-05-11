import Foundation
import SwiftUI
import Combine

struct ActivityItem: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let type: ActivityType
    let description: String
    let date: Date

    enum ActivityType: String, Codable {
        case embed
        case extract
    }
}

class ActivityStore: ObservableObject {
    static let shared = ActivityStore()

    private let key = "recentActivities"
    private let maxCount = 10

    @Published private(set) var activities: [ActivityItem] = []

    private init() {
        load()
    }

    func record(type: ActivityItem.ActivityType, fileName: String, description: String) {
        let item = ActivityItem(id: UUID(), fileName: fileName, type: type, description: description, date: Date())
        activities.insert(item, at: 0)
        if activities.count > maxCount {
            activities = Array(activities.prefix(maxCount))
        }
        save()
    }

    func clear() {
        activities.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        activities = (try? JSONDecoder().decode([ActivityItem].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(activities) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
