import Foundation

public enum NameIdentityMatch: String {
    case none
    case exact
    case partial
}

public enum ContactMatching {
    public static func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public static func normalizedToken(_ value: String?) -> String {
        trimmed(value).lowercased()
    }

    public static func normalizedEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func normalizedPhone(_ value: String) -> String {
        value.filter { $0.isNumber }
    }

    public static func hasUsableContent(_ input: ContactInput) -> Bool {
        !trimmed(input.givenName).isEmpty
            || !trimmed(input.familyName).isEmpty
            || !trimmed(input.organizationName).isEmpty
            || !trimmed(input.jobTitle).isEmpty
            || (input.phoneNumbers ?? []).contains { !normalizedPhone($0.value).isEmpty }
            || (input.emailAddresses ?? []).contains { !normalizedEmail($0.value).isEmpty }
    }

    public static func hasPatchIntent(_ input: ContactInput) -> Bool {
        input.givenName != nil
            || input.familyName != nil
            || input.organizationName != nil
            || input.jobTitle != nil
            || input.phoneNumbers != nil
            || input.emailAddresses != nil
    }

    public static func hasUpsertIdentity(_ input: ContactInput) -> Bool {
        if (input.emailAddresses ?? []).contains(where: { !normalizedEmail($0.value).isEmpty }) {
            return true
        }
        if (input.phoneNumbers ?? []).contains(where: { !normalizedPhone($0.value).isEmpty }) {
            return true
        }
        return !trimmed(input.givenName).isEmpty || !trimmed(input.familyName).isEmpty
    }

    public static func nameCandidates(givenName: String, familyName: String) -> [String] {
        let given = trimmed(givenName)
        let family = trimmed(familyName)
        let values = [
            given,
            family,
            [given, family].filter { !$0.isEmpty }.joined(separator: " "),
            [family, given].filter { !$0.isEmpty }.joined(separator: " ")
        ]
        var seen: Set<String> = []
        return values.filter { value in
            !value.isEmpty && seen.insert(value).inserted
        }
    }

    public static func nameIdentityMatch(
        input: ContactInput,
        recordGivenName: String,
        recordFamilyName: String
    ) -> NameIdentityMatch {
        let givenName = normalizedToken(input.givenName)
        let familyName = normalizedToken(input.familyName)
        let recordGivenName = normalizedToken(recordGivenName)
        let recordFamilyName = normalizedToken(recordFamilyName)

        if !givenName.isEmpty && !familyName.isEmpty {
            return recordGivenName == givenName && recordFamilyName == familyName ? .exact : .none
        }
        if !givenName.isEmpty {
            guard recordGivenName == givenName else {
                return .none
            }
            return recordFamilyName.isEmpty ? .exact : .partial
        }
        if !familyName.isEmpty {
            guard recordFamilyName == familyName else {
                return .none
            }
            return recordGivenName.isEmpty ? .exact : .partial
        }
        return .none
    }

    public static func record(_ record: ContactRecord, matches query: String) -> Bool {
        let normalizedQuery = normalizedToken(query)
        guard !normalizedQuery.isEmpty else {
            return true
        }

        let values = [
            record.identifier ?? "",
            record.givenName,
            record.familyName,
            record.organizationName,
            record.jobTitle
        ]
        let nameValues = nameCandidates(givenName: record.givenName, familyName: record.familyName)
        if (values + nameValues).contains(where: { normalizedToken($0).contains(normalizedQuery) }) {
            return true
        }
        let normalizedPhoneQuery = normalizedPhone(query)
        if !normalizedPhoneQuery.isEmpty,
           record.phoneNumbers.contains(where: { normalizedPhone($0.value).contains(normalizedPhoneQuery) }) {
            return true
        }
        return record.emailAddresses.contains { normalizedEmail($0.value).contains(normalizedQuery) }
    }
}
