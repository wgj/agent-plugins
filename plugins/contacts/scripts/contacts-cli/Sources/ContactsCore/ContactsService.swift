@preconcurrency import Contacts
import Foundation

public final class ContactsService {
    private let store: CNContactStore

    private static var keysToFetch: [CNKeyDescriptor] {
        [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
    }

    public init(store: CNContactStore = CNContactStore()) {
        self.store = store
    }

    public static func authorizationStatusDescription() -> String {
        describe(CNContactStore.authorizationStatus(for: .contacts))
    }

    public func requestAccessIfNeeded() throws -> String {
        try ensureAccess()
        return Self.authorizationStatusDescription()
    }

    public func list(query: String?, limit: Int) throws -> [ContactRecord] {
        try ensureAccess()
        let records = try fetchAllContacts().map(Self.record(from:))
        let filtered = records.filter { record in
            guard let query else {
                return true
            }
            return ContactMatching.record(record, matches: query)
        }
        return Array(filtered.prefix(max(limit, 0)))
    }

    public func get(identifier: String) throws -> ContactRecord {
        try ensureAccess()
        return Self.record(from: try fetchContact(identifier: identifier))
    }

    public func add(_ input: ContactInput, dryRun: Bool) throws -> ContactOperationResult {
        guard ContactMatching.hasUsableContent(input) else {
            throw ContactsCLIError.message("contact input must include at least one supported field")
        }

        if dryRun {
            return ContactOperationResult(
                action: "add",
                dryRun: true,
                contact: Self.plannedRecord(from: input),
                message: "No contact was created. Dry-run add output has no stable identifier until the contact is saved."
            )
        }

        try ensureAccess()
        let mutable = CNMutableContact()
        apply(input, to: mutable)
        let request = CNSaveRequest()
        request.add(mutable, toContainerWithIdentifier: nil)
        try store.execute(request)

        return ContactOperationResult(
            action: "add",
            dryRun: false,
            contact: Self.record(from: mutable),
            message: "Contact created."
        )
    }

    public func update(identifier: String, input: ContactInput, dryRun: Bool) throws -> ContactOperationResult {
        guard ContactMatching.hasUsableContent(input) else {
            throw ContactsCLIError.message("update input must include at least one supported field")
        }

        try ensureAccess()
        let contact = try fetchContact(identifier: identifier)
        let before = Self.record(from: contact)
        guard let mutable = contact.mutableCopy() as? CNMutableContact else {
            throw ContactsCLIError.message("could not create a mutable copy of contact \(identifier)")
        }
        apply(input, to: mutable)
        let after = Self.record(from: mutable)

        if dryRun {
            return ContactOperationResult(
                action: "update",
                dryRun: true,
                before: before,
                after: after,
                message: "No contact was updated."
            )
        }

        let request = CNSaveRequest()
        request.update(mutable)
        try store.execute(request)

        return ContactOperationResult(
            action: "update",
            dryRun: false,
            before: before,
            after: Self.record(from: mutable),
            message: "Contact updated."
        )
    }

    public func upsert(_ input: ContactInput, dryRun: Bool) throws -> ContactOperationResult {
        guard ContactMatching.hasUsableContent(input) else {
            throw ContactsCLIError.message("contact input must include at least one supported field")
        }
        guard ContactMatching.hasUpsertIdentity(input) else {
            throw ContactsCLIError.message("upsert requires an email address, phone number, or name")
        }

        try ensureAccess()
        let match = try findUpsertMatches(for: input)
        if match.contacts.count > 1 {
            if dryRun {
                return ContactOperationResult(
                    action: "upsert",
                    dryRun: true,
                    matchedBy: match.reason,
                    matches: match.contacts.map(Self.record(from:)),
                    message: "Multiple contacts matched. No contact was changed; use get/update with an explicit identifier."
                )
            }
            throw ContactsCLIError.message("upsert matched multiple contacts by \(match.reason); use get/update with an explicit identifier")
        }
        if let existing = match.contacts.first {
            return try update(identifier: existing.identifier, input: input, dryRun: dryRun).with(action: "upsert", matchedBy: match.reason)
        }
        return try add(input, dryRun: dryRun).with(action: "upsert", matchedBy: "none")
    }

    public func delete(identifier: String, dryRun: Bool, confirmDelete: Bool) throws -> ContactOperationResult {
        try ensureAccess()
        let contact = try fetchContact(identifier: identifier)
        let record = Self.record(from: contact)

        if dryRun {
            return ContactOperationResult(
                action: "delete",
                dryRun: true,
                contact: record,
                message: "No contact was deleted."
            )
        }

        guard confirmDelete else {
            throw ContactsCLIError.message("delete requires --confirm-delete")
        }
        guard let mutable = contact.mutableCopy() as? CNMutableContact else {
            throw ContactsCLIError.message("could not create a mutable copy of contact \(identifier)")
        }

        let request = CNSaveRequest()
        request.delete(mutable)
        try store.execute(request)

        return ContactOperationResult(
            action: "delete",
            dryRun: false,
            contact: record,
            message: "Contact deleted."
        )
    }

    private func ensureAccess() throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            let accessResult = AccessResult()
            store.requestAccess(for: .contacts) { didGrant, error in
                accessResult.set(granted: didGrant, error: error)
                semaphore.signal()
            }
            semaphore.wait()
            let result = accessResult.get()
            if let error = result.error {
                throw error
            }
            if result.granted {
                return
            }
            throw ContactsCLIError.message("macOS Contacts access was not granted")
        case .denied:
            throw ContactsCLIError.message("macOS Contacts access is denied for this executable")
        case .restricted:
            throw ContactsCLIError.message("macOS Contacts access is restricted")
        @unknown default:
            throw ContactsCLIError.message("macOS Contacts access is \(Self.describe(status))")
        }
    }

    private func fetchContact(identifier: String) throws -> CNContact {
        do {
            return try store.unifiedContact(withIdentifier: identifier, keysToFetch: Self.keysToFetch)
        } catch {
            throw ContactsCLIError.message("contact not found for identifier \(identifier)")
        }
    }

    private func fetchAllContacts() throws -> [CNContact] {
        var contacts: [CNContact] = []
        let request = CNContactFetchRequest(keysToFetch: Self.keysToFetch)
        request.sortOrder = .userDefault
        request.unifyResults = true
        try store.enumerateContacts(with: request) { contact, _ in
            contacts.append(contact)
        }
        return contacts
    }

    private func apply(_ input: ContactInput, to mutable: CNMutableContact) {
        if let givenName = input.givenName {
            mutable.givenName = givenName
        }
        if let familyName = input.familyName {
            mutable.familyName = familyName
        }
        if let organizationName = input.organizationName {
            mutable.organizationName = organizationName
        }
        if let jobTitle = input.jobTitle {
            mutable.jobTitle = jobTitle
        }
        if let phoneNumbers = input.phoneNumbers {
            mutable.phoneNumbers = phoneNumbers.map { value in
                CNLabeledValue(
                    label: ContactLabels.contactsLabel(value.label, kind: .phone),
                    value: CNPhoneNumber(stringValue: value.value)
                )
            }
        }
        if let emailAddresses = input.emailAddresses {
            mutable.emailAddresses = emailAddresses.map { value in
                CNLabeledValue(
                    label: ContactLabels.contactsLabel(value.label, kind: .email),
                    value: value.value as NSString
                )
            }
        }
    }

    private func findUpsertMatches(for input: ContactInput) throws -> (reason: String, contacts: [CNContact]) {
        let contacts = try fetchAllContacts()

        let emails = Set((input.emailAddresses ?? []).map { ContactMatching.normalizedEmail($0.value) }.filter { !$0.isEmpty })
        if !emails.isEmpty {
            let matches = contacts.filter { contact in
                contact.emailAddresses.contains { emails.contains(ContactMatching.normalizedEmail(String($0.value))) }
            }
            if !matches.isEmpty {
                return ("email", matches)
            }
        }

        let phones = Set((input.phoneNumbers ?? []).map { ContactMatching.normalizedPhone($0.value) }.filter { !$0.isEmpty })
        if !phones.isEmpty {
            let matches = contacts.filter { contact in
                contact.phoneNumbers.contains { phones.contains(ContactMatching.normalizedPhone($0.value.stringValue)) }
            }
            if !matches.isEmpty {
                return ("phone", matches)
            }
        }

        let givenName = ContactMatching.normalizedToken(input.givenName)
        let familyName = ContactMatching.normalizedToken(input.familyName)
        if !givenName.isEmpty || !familyName.isEmpty {
            let matches = contacts.filter { contact in
                ContactMatching.normalizedToken(contact.givenName) == givenName
                    && ContactMatching.normalizedToken(contact.familyName) == familyName
            }
            if !matches.isEmpty {
                return ("name", matches)
            }
        }

        return ("none", [])
    }

    private static func record(from contact: CNContact) -> ContactRecord {
        ContactRecord(
            identifier: contact.identifier.isEmpty ? nil : contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            organizationName: contact.organizationName,
            jobTitle: contact.jobTitle,
            phoneNumbers: contact.phoneNumbers.map { value in
                LabeledString(label: ContactLabels.displayLabel(value.label), value: value.value.stringValue)
            },
            emailAddresses: contact.emailAddresses.map { value in
                LabeledString(label: ContactLabels.displayLabel(value.label), value: String(value.value))
            }
        )
    }

    private static func plannedRecord(from input: ContactInput) -> ContactRecord {
        ContactRecord(
            identifier: nil,
            givenName: input.givenName ?? "",
            familyName: input.familyName ?? "",
            organizationName: input.organizationName ?? "",
            jobTitle: input.jobTitle ?? "",
            phoneNumbers: (input.phoneNumbers ?? []).map { value in
                LabeledString(
                    label: ContactLabels.displayLabel(ContactLabels.contactsLabel(value.label, kind: .phone)) ?? value.label,
                    value: value.value
                )
            },
            emailAddresses: (input.emailAddresses ?? []).map { value in
                LabeledString(
                    label: ContactLabels.displayLabel(ContactLabels.contactsLabel(value.label, kind: .email)) ?? value.label,
                    value: value.value
                )
            }
        )
    }

    private static func describe(_ status: CNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        @unknown default:
            return "unknown"
        }
    }
}

private final class AccessResult: @unchecked Sendable {
    private let lock = NSLock()
    private var granted = false
    private var error: Error?

    func set(granted: Bool, error: Error?) {
        lock.lock()
        self.granted = granted
        self.error = error
        lock.unlock()
    }

    func get() -> (granted: Bool, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        return (granted, error)
    }
}

private extension ContactOperationResult {
    func with(action: String, matchedBy: String?) -> ContactOperationResult {
        ContactOperationResult(
            action: action,
            dryRun: dryRun,
            matchedBy: matchedBy,
            contact: contact,
            before: before,
            after: after,
            matches: matches,
            message: message
        )
    }
}
