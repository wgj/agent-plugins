# Contacts

Native macOS Contacts CRUD for Codex, backed by a small Swift CLI that uses Apple's `Contacts.framework`. It does not use UI automation and does not write directly to Contacts private databases.

## Build

```bash
swift build --package-path plugins/contacts/scripts/contacts-cli -c release
```

The release binary is written under:

```text
plugins/contacts/scripts/contacts-cli/.build/release/contacts-cli
```

For one-off use during development, run through Swift Package Manager:

```bash
swift run --package-path plugins/contacts/scripts/contacts-cli contacts-cli search "Jane Smith"
```

## Permissions

The first command that reads or writes real contacts will trigger the macOS Contacts permission prompt for the calling executable, such as `contacts-cli`, `swift`, or the built release binary. If access is denied, the CLI returns a JSON error and does not fall back to database writes.

Check current access without mutating contacts:

```bash
plugins/contacts/scripts/contacts-cli/.build/release/contacts-cli doctor
```

Prompt for access intentionally:

```bash
plugins/contacts/scripts/contacts-cli/.build/release/contacts-cli doctor --request-permission
```

## JSON Shape

Input fields:

```json
{
  "givenName": "Jane",
  "familyName": "Smith",
  "organizationName": "Acme Co",
  "jobTitle": "Owner",
  "phoneNumbers": [{ "label": "work", "value": "+1 303 555 0100" }],
  "emailAddresses": [{ "label": "work", "value": "jane@example.com" }]
}
```

`company` is accepted as an alias for `organizationName`. Labels can be `home`, `work`, `other`, and common phone labels such as `mobile`, `iphone`, `main`, `homeFax`, `workFax`, `otherFax`, or `pager`.

Notes are intentionally omitted in v1. Recent macOS Contacts privacy behavior may require the `com.apple.developer.contacts.notes` entitlement for notes access, so this helper does not claim notes support.

## Commands

All operational commands return JSON.

```bash
contacts-cli list --limit 25
contacts-cli search "Jane Smith"
contacts-cli get --id CONTACT_IDENTIFIER
contacts-cli add --dry-run --input contact.json
contacts-cli add --input contact.json
contacts-cli upsert --dry-run --input contact.json
contacts-cli update --id CONTACT_IDENTIFIER --dry-run --input patch.json
contacts-cli delete --id CONTACT_IDENTIFIER --dry-run
contacts-cli delete --id CONTACT_IDENTIFIER --confirm-delete
```

Use `--input -` for stdin or `--json '{"givenName":"Jane"}'` for inline JSON.

`delete` only mutates when `--confirm-delete` is present. `add`, `upsert`, `update`, and `delete` support `--dry-run`; dry-run output describes the planned action.

## PEOPLE.md-Style Example

Given source rows like:

```md
| Name | Company | Role | Phone | Email |
| --- | --- | --- | --- | --- |
| Brian Kelleghan | EAR Inc | Seller | +1 303 555 0100 | brian@example.com |
| Dawn Homyak | Bison Designs | Owner | +1 303 555 0101 | dawn@example.com |
```

Dry-run the two upserts first:

```bash
contacts-cli upsert --dry-run --json '{"givenName":"Brian","familyName":"Kelleghan","organizationName":"EAR Inc","jobTitle":"Seller","phoneNumbers":[{"label":"work","value":"+1 303 555 0100"}],"emailAddresses":[{"label":"work","value":"brian@example.com"}]}'
contacts-cli upsert --dry-run --json '{"givenName":"Dawn","familyName":"Homyak","organizationName":"Bison Designs","jobTitle":"Owner","phoneNumbers":[{"label":"work","value":"+1 303 555 0101"}],"emailAddresses":[{"label":"work","value":"dawn@example.com"}]}'
```

Only remove `--dry-run` after checking existing matches and getting explicit user approval to mutate Contacts.
