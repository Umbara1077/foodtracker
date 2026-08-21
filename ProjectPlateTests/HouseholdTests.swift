import Foundation
import Testing
@testable import ProjectPlate

@Suite("Phase 31 — Shared / family plan")
struct HouseholdTests {
    @Test("Invite codes are 6 unambiguous characters")
    func inviteCode() {
        var rng = SplitMix64(seed: 42)
        let code = HouseholdMath.makeInviteCode(rng: &rng)
        #expect(code.count == 6)
        #expect(code == code.uppercased())
        #expect(!code.contains("O"))
        #expect(!code.contains("0"))
        #expect(!code.contains("1"))
        #expect(!code.contains("I"))
    }

    @Test("Members sort self first then name")
    func sortMembers() {
        let members = HouseholdMath.sortedMembers([
            HouseholdMember(displayName: "Zoe", role: .member),
            HouseholdMember(displayName: "Alex", role: .selfMember),
            HouseholdMember(displayName: "Sam", role: .member),
        ])
        #expect(members.map(\.displayName) == ["Alex", "Sam", "Zoe"])
    }

    @Test("Household store round-trips")
    func storeRoundTrip() async {
        let suite = "plate.test.household.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsHouseholdStore(defaults: defaults)
        let household = Household(
            id: UUID(),
            name: "Kitchen crew",
            inviteCode: "ABCD23",
            members: [
                HouseholdMember(displayName: "You", role: .selfMember, calorieGoal: 2_100),
                HouseholdMember(displayName: "Sam", role: .member, calorieGoal: 1_800),
            ],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        await store.save(household)
        let loaded = await store.load()
        #expect(loaded?.name == "Kitchen crew")
        #expect(loaded?.members.count == 2)
        #expect(loaded?.inviteCode == "ABCD23")
        await store.clear()
        #expect(await store.load() == nil)
    }

    @Test("Preference defaults on")
    func preference() {
        let suite = "plate.test.household.pref.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(HouseholdPreference.isEnabled(defaults: defaults))
        HouseholdPreference.setEnabled(false, defaults: defaults)
        #expect(!HouseholdPreference.isEnabled(defaults: defaults))
    }
}

/// Deterministic RNG for invite-code tests.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
