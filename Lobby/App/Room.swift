import Foundation

enum Room: String, CaseIterable, Identifiable {
    case home, work, sports, fleet, trips, brand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .sports: return "Sports"
        case .fleet: return "Fleet"
        case .trips: return "Trips"
        case .brand: return "Brand"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .work: return "briefcase"
        case .sports: return "flag"
        case .fleet: return "airplane"
        case .trips: return "suitcase"
        case .brand: return "star"
        }
    }
}
