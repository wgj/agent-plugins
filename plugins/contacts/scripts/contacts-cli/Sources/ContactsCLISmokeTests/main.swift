import ContactsCore
import Foundation

@main
struct ContactsCLISmokeTests {
    static func main() throws {
        try testDecodesCompanyAlias()
        testMatchesRecordsAcrossSupportedFields()
        testValidatesUsableUpsertIdentity()
        testSeparatesPatchIntentFromUsableContent()
        testMapsKnownLabels()
        print("contacts-cli smoke tests passed")
    }

    private static func testDecodesCompanyAlias() throws {
        let json = """
        {
          "givenName": "Dawn",
          "familyName": "Homyak",
          "company": "Bison Designs",
          "jobTitle": "Owner",
          "phoneNumbers": [{ "label": "work", "value": "+1 303 555 0101" }],
          "emailAddresses": [{ "label": "work", "value": "dawn@example.com" }]
        }
        """

        let input = try JSONDecoder().decode(ContactInput.self, from: Data(json.utf8))

        check(input.givenName == "Dawn", "givenName decoded")
        check(input.familyName == "Homyak", "familyName decoded")
        check(input.organizationName == "Bison Designs", "company alias decoded")
        check(input.jobTitle == "Owner", "jobTitle decoded")
        check(input.phoneNumbers == [LabeledString(label: "work", value: "+1 303 555 0101")], "phone decoded")
        check(input.emailAddresses == [LabeledString(label: "work", value: "dawn@example.com")], "email decoded")
    }

    private static func testMatchesRecordsAcrossSupportedFields() {
        let record = ContactRecord(
            identifier: "contact-123",
            givenName: "Brian",
            familyName: "Kelleghan",
            organizationName: "EAR Inc",
            jobTitle: "Seller",
            phoneNumbers: [LabeledString(label: "work", value: "+1 (303) 555-0100")],
            emailAddresses: [LabeledString(label: "work", value: "brian@example.com")]
        )

        check(ContactMatching.record(record, matches: "kelleghan"), "matches family name")
        check(ContactMatching.record(record, matches: "ear inc"), "matches organization")
        check(ContactMatching.record(record, matches: "3035550100"), "matches normalized phone")
        check(ContactMatching.record(record, matches: "BRIAN@EXAMPLE.COM"), "matches normalized email")
        check(!ContactMatching.record(record, matches: "not present"), "rejects absent query")
    }

    private static func testValidatesUsableUpsertIdentity() {
        check(!ContactMatching.hasUpsertIdentity(ContactInput(organizationName: "Only Org")), "rejects org-only upsert")
        check(!ContactMatching.hasUpsertIdentity(ContactInput(phoneNumbers: [LabeledString(label: "mobile", value: "")])), "rejects blank phone upsert")
        check(!ContactMatching.hasUpsertIdentity(ContactInput(emailAddresses: [LabeledString(label: "work", value: "  ")])), "rejects blank email upsert")
        check(ContactMatching.hasUpsertIdentity(ContactInput(givenName: "Jane")), "accepts name upsert")
        check(
            ContactMatching.hasUpsertIdentity(ContactInput(phoneNumbers: [LabeledString(label: "mobile", value: "+13035550100")])),
            "accepts phone upsert"
        )
        check(
            ContactMatching.hasUpsertIdentity(ContactInput(emailAddresses: [LabeledString(label: "work", value: "jane@example.com")])),
            "accepts email upsert"
        )
    }

    private static func testSeparatesPatchIntentFromUsableContent() {
        check(ContactMatching.hasPatchIntent(ContactInput(jobTitle: "")), "empty text still clears on update")
        check(ContactMatching.hasPatchIntent(ContactInput(phoneNumbers: [])), "empty phone array still clears on update")
        check(!ContactMatching.hasUsableContent(ContactInput(jobTitle: "")), "empty text is not create content")
        check(!ContactMatching.hasUsableContent(ContactInput(phoneNumbers: [LabeledString(label: "mobile", value: "")])), "blank phone is not create content")
    }

    private static func testMapsKnownLabels() {
        check(ContactLabels.displayLabel(ContactLabels.contactsLabel("work", kind: .email)) == "work", "maps work label")
        check(ContactLabels.displayLabel(ContactLabels.contactsLabel("mobile", kind: .phone)) == "mobile", "maps mobile label")
        check(ContactLabels.contactsLabel("custom", kind: .phone) == "custom", "preserves custom label")
    }

    private static func check(_ condition: Bool, _ message: String) {
        if !condition {
            fputs("smoke test failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
