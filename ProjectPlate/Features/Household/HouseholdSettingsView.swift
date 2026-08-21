import SwiftUI

struct HouseholdSettingsView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var household: Household?
    @State private var householdName = ""
    @State private var selfName = "You"
    @State private var memberName = ""
    @State private var memberGoalText = ""
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Text("Local household roster for a shared plan preview. Cloud invites and live shared diaries are not enabled yet.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            if let household, household.isActive {
                Section("Household") {
                    LabeledContent("Name", value: household.name)
                    LabeledContent("Invite code", value: household.inviteCode)
                    Text("Share the code later when cloud family sync ships. It stays on this device for now.")
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Section("Members") {
                    ForEach(HouseholdMath.sortedMembers(household.members)) { member in
                        VStack(alignment: .leading, spacing: Spacing.space4) {
                            Text(member.displayName)
                                .font(Typography.supporting.weight(.semibold))
                            Text(member.role.title + goalSuffix(member.calorieGoal))
                                .font(Typography.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Section {
                    Button("Dissolve household", role: .destructive) {
                        Task { await clearHousehold() }
                    }
                }
            } else {
                Section("Create") {
                    TextField("Household name", text: $householdName)
                    TextField("Your display name", text: $selfName)
                    Button("Create household") {
                        Task { await createHousehold() }
                    }
                    .disabled(HouseholdMath.sanitizeName(householdName).isEmpty)
                }
            }

            if household?.isActive == true {
                Section("Add member") {
                    TextField("Name", text: $memberName)
                    TextField("Calorie goal (optional)", text: $memberGoalText)
                        .keyboardType(.numberPad)
                    Button("Add member") {
                        Task { await addMember() }
                    }
                    .disabled(HouseholdMath.sanitizeName(memberName).isEmpty)
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .navigationTitle("Family plan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private func goalSuffix(_ goal: Int?) -> String {
        guard let goal else { return "" }
        return " · \(goal) cal"
    }

    private func reload() async {
        household = await environment.householdStore.load()
    }

    private func createHousehold() async {
        let name = HouseholdMath.sanitizeName(householdName)
        let you = HouseholdMath.sanitizeName(selfName).isEmpty ? "You" : HouseholdMath.sanitizeName(selfName)
        guard !name.isEmpty else { return }
        let created = Household(
            id: UUID(),
            name: name,
            inviteCode: HouseholdMath.makeInviteCode(),
            members: [
                HouseholdMember(displayName: you, role: .selfMember),
            ],
            updatedAt: .now
        )
        await environment.householdStore.save(created)
        householdName = ""
        message = "Household created on this iPhone."
        await reload()
    }

    private func addMember() async {
        guard var household else { return }
        let name = HouseholdMath.sanitizeName(memberName)
        guard !name.isEmpty else { return }
        let goal = Int(memberGoalText.trimmingCharacters(in: .whitespacesAndNewlines))
        household.members.append(
            HouseholdMember(displayName: name, role: .member, calorieGoal: goal)
        )
        household.updatedAt = .now
        await environment.householdStore.save(household)
        memberName = ""
        memberGoalText = ""
        message = "Added \(name)."
        await reload()
    }

    private func clearHousehold() async {
        await environment.householdStore.clear()
        message = "Household cleared from this device."
        await reload()
    }
}
