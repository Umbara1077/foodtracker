import Foundation

enum HouseholdRole: String, Codable, Sendable, CaseIterable {
    case selfMember
    case member

    var title: String {
        switch self {
        case .selfMember: "You"
        case .member: "Member"
        }
    }
}

struct HouseholdMember: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var role: HouseholdRole
    /// Soft daily calorie goal shown in the household card (optional).
    var calorieGoal: Int?

    init(
        id: UUID = UUID(),
        displayName: String,
        role: HouseholdRole,
        calorieGoal: Int? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.calorieGoal = calorieGoal
    }
}

struct Household: Codable, Sendable, Equatable {
    var id: UUID
    var name: String
    var inviteCode: String
    var members: [HouseholdMember]
    var updatedAt: Date

    static let empty = Household(
        id: UUID(),
        name: "",
        inviteCode: "",
        members: [],
        updatedAt: .now
    )

    var isActive: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !members.isEmpty
    }
}

enum HouseholdMath {
    /// Short, uppercase invite code (no ambiguous chars). Local-only for this phase.
    static func makeInviteCode(rng: inout some RandomNumberGenerator) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement(using: &rng)! })
    }

    static func makeInviteCode() -> String {
        var rng = SystemRandomNumberGenerator()
        return makeInviteCode(rng: &rng)
    }

    static func sanitizeName(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    }

    static func sortedMembers(_ members: [HouseholdMember]) -> [HouseholdMember] {
        members.sorted { lhs, rhs in
            if lhs.role != rhs.role {
                return lhs.role == .selfMember && rhs.role != .selfMember
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

enum HouseholdPreference {
    static let enabledKey = "plate.household.enabled"

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: enabledKey) == nil { return true }
        return defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: enabledKey)
    }
}

protocol HouseholdStore: Sendable {
    func load() async -> Household?
    func save(_ household: Household) async
    func clear() async
}

actor UserDefaultsHouseholdStore: HouseholdStore {
    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "plate.household.payload") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func load() async -> Household? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(Household.self, from: data)
    }

    func save(_ household: Household) async {
        guard let data = try? JSONEncoder().encode(household) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func clear() async {
        defaults.removeObject(forKey: storageKey)
    }
}
