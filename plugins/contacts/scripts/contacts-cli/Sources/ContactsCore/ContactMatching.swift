import Foundation

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
            || !(input.phoneNumbers ?? []).isEmpty
            || !(input.emailAddresses ?? []).isEmpty
    }

    public static func hasUpsertIdentity(_ input: ContactInput) -> Bool {
        if !(input.emailAddresses ?? []).isEmpty || !(input.phoneNumbers ?? []).isEmpty {
            return true
        }
        return !trimmed(input.givenName).isEmpty || !trimmed(input.familyName).isEmpty
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
        if values.contains(where: { normalizedToken($0).contains(normalizedQuery) }) {
            return true
        }
        if record.phoneNumbers.contains(where: { normalizedPhone($0.value).contains(normalizedPhone(query)) }) {
            return true
        }
        return record.emailAddresses.contains { normalizedEmail($0.value).contains(normalizedQuery) }
    }
}
