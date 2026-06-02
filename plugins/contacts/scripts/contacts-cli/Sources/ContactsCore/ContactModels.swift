import Foundation

public struct LabeledString: Codable, Equatable {
    public var label: String?
    public var value: String

    public init(label: String? = nil, value: String) {
        self.label = label
        self.value = value
    }
}

public struct ContactInput: Codable, Equatable {
    public var givenName: String?
    public var familyName: String?
    public var organizationName: String?
    public var jobTitle: String?
    public var phoneNumbers: [LabeledString]?
    public var emailAddresses: [LabeledString]?

    public init(
        givenName: String? = nil,
        familyName: String? = nil,
        organizationName: String? = nil,
        jobTitle: String? = nil,
        phoneNumbers: [LabeledString]? = nil,
        emailAddresses: [LabeledString]? = nil
    ) {
        self.givenName = givenName
        self.familyName = familyName
        self.organizationName = organizationName
        self.jobTitle = jobTitle
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
    }

    private enum CodingKeys: String, CodingKey {
        case givenName
        case familyName
        case organizationName
        case company
        case jobTitle
        case phoneNumbers
        case emailAddresses
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        givenName = try container.decodeIfPresent(String.self, forKey: .givenName)
        familyName = try container.decodeIfPresent(String.self, forKey: .familyName)
        organizationName = try container.decodeIfPresent(String.self, forKey: .organizationName)
            ?? container.decodeIfPresent(String.self, forKey: .company)
        jobTitle = try container.decodeIfPresent(String.self, forKey: .jobTitle)
        phoneNumbers = try container.decodeIfPresent([LabeledString].self, forKey: .phoneNumbers)
        emailAddresses = try container.decodeIfPresent([LabeledString].self, forKey: .emailAddresses)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(givenName, forKey: .givenName)
        try container.encodeIfPresent(familyName, forKey: .familyName)
        try container.encodeIfPresent(organizationName, forKey: .organizationName)
        try container.encodeIfPresent(jobTitle, forKey: .jobTitle)
        try container.encodeIfPresent(phoneNumbers, forKey: .phoneNumbers)
        try container.encodeIfPresent(emailAddresses, forKey: .emailAddresses)
    }
}

public struct ContactRecord: Codable, Equatable {
    public var identifier: String?
    public var givenName: String
    public var familyName: String
    public var organizationName: String
    public var jobTitle: String
    public var phoneNumbers: [LabeledString]
    public var emailAddresses: [LabeledString]

    public init(
        identifier: String? = nil,
        givenName: String,
        familyName: String,
        organizationName: String,
        jobTitle: String,
        phoneNumbers: [LabeledString],
        emailAddresses: [LabeledString]
    ) {
        self.identifier = identifier
        self.givenName = givenName
        self.familyName = familyName
        self.organizationName = organizationName
        self.jobTitle = jobTitle
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
    }
}

public struct ContactOperationResult: Codable, Equatable {
    public var action: String
    public var dryRun: Bool
    public var matchedBy: String?
    public var contact: ContactRecord?
    public var before: ContactRecord?
    public var after: ContactRecord?
    public var matches: [ContactRecord]?
    public var message: String?

    public init(
        action: String,
        dryRun: Bool,
        matchedBy: String? = nil,
        contact: ContactRecord? = nil,
        before: ContactRecord? = nil,
        after: ContactRecord? = nil,
        matches: [ContactRecord]? = nil,
        message: String? = nil
    ) {
        self.action = action
        self.dryRun = dryRun
        self.matchedBy = matchedBy
        self.contact = contact
        self.before = before
        self.after = after
        self.matches = matches
        self.message = message
    }
}

public enum ContactsCLIError: Error, CustomStringConvertible {
    case message(String)

    public var description: String {
        switch self {
        case .message(let value):
            value
        }
    }
}
