import ContactsCore
import Foundation

@main
struct ContactsCLI {
    static func main() {
        do {
            let parsed = try ParsedArguments(Array(CommandLine.arguments.dropFirst()))
            if parsed.command == "help" || parsed.hasFlag("help") {
                print(Self.helpText)
                return
            }

            let service = ContactsService()
            switch parsed.command {
            case "doctor":
                try runDoctor(parsed, service: service)
            case "list":
                try runList(parsed, service: service, query: parsed.option("query"))
            case "search":
                let query = parsed.option("query") ?? parsed.positionals.joined(separator: " ")
                guard !query.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
                    throw ContactsCLIError.message("search requires a query")
                }
                try runList(parsed, service: service, query: query)
            case "get":
                try runGet(parsed, service: service)
            case "add":
                try runAdd(parsed, service: service)
            case "upsert":
                try runUpsert(parsed, service: service)
            case "update":
                try runUpdate(parsed, service: service)
            case "delete":
                try runDelete(parsed, service: service)
            default:
                throw ContactsCLIError.message("unknown command \(parsed.command)")
            }
        } catch {
            writeError(error)
            exit(1)
        }
    }

    private static func runDoctor(_ parsed: ParsedArguments, service: ContactsService) throws {
        let status = parsed.hasFlag("request-permission")
            ? try service.requestAccessIfNeeded()
            : ContactsService.authorizationStatusDescription()
        writeJSON(DoctorResponse(status: status))
    }

    private static func runList(_ parsed: ParsedArguments, service: ContactsService, query: String?) throws {
        let limit = try parsed.integerOption("limit") ?? 50
        let contacts = try service.list(query: query, limit: limit)
        writeJSON(ListResponse(query: query, count: contacts.count, contacts: contacts))
    }

    private static func runGet(_ parsed: ParsedArguments, service: ContactsService) throws {
        let identifier = try parsed.requiredIdentifier()
        writeJSON(ContactResponse(contact: try service.get(identifier: identifier)))
    }

    private static func runAdd(_ parsed: ParsedArguments, service: ContactsService) throws {
        let input = try loadContactInput(parsed)
        let result = try service.add(input, dryRun: parsed.hasFlag("dry-run"))
        writeJSON(OperationResponse(result: result))
    }

    private static func runUpsert(_ parsed: ParsedArguments, service: ContactsService) throws {
        let input = try loadContactInput(parsed)
        let result = try service.upsert(input, dryRun: parsed.hasFlag("dry-run"))
        writeJSON(OperationResponse(result: result))
    }

    private static func runUpdate(_ parsed: ParsedArguments, service: ContactsService) throws {
        let identifier = try parsed.requiredIdentifier()
        let input = try loadContactInput(parsed)
        let result = try service.update(identifier: identifier, input: input, dryRun: parsed.hasFlag("dry-run"))
        writeJSON(OperationResponse(result: result))
    }

    private static func runDelete(_ parsed: ParsedArguments, service: ContactsService) throws {
        let identifier = try parsed.requiredIdentifier()
        let result = try service.delete(
            identifier: identifier,
            dryRun: parsed.hasFlag("dry-run"),
            confirmDelete: parsed.hasFlag("confirm-delete")
        )
        writeJSON(OperationResponse(result: result))
    }

    private static func loadContactInput(_ parsed: ParsedArguments) throws -> ContactInput {
        let data: Data
        if let inlineJSON = parsed.option("json") {
            data = Data(inlineJSON.utf8)
        } else if let inputPath = parsed.option("input") {
            if inputPath == "-" {
                data = FileHandle.standardInput.readDataToEndOfFile()
            } else {
                data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
            }
        } else {
            throw ContactsCLIError.message("command requires --input PATH, --input -, or --json JSON")
        }

        do {
            return try JSONDecoder().decode(ContactInput.self, from: data)
        } catch {
            throw ContactsCLIError.message("invalid contact JSON: \(error)")
        }
    }

    private static func writeJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(value)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            writeError(error)
            exit(1)
        }
    }

    private static func writeError(_ error: Error) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let message: String
        if let cliError = error as? ContactsCLIError {
            message = cliError.description
        } else {
            message = error.localizedDescription
        }
        let response = ErrorResponse(error: message)
        if let data = try? encoder.encode(response) {
            FileHandle.standardError.write(data)
            FileHandle.standardError.write(Data("\n".utf8))
        } else {
            FileHandle.standardError.write(Data("{\"ok\":false,\"error\":\"unknown error\"}\n".utf8))
        }
    }

    private static let helpText = """
    contacts-cli COMMAND [OPTIONS]

    Commands:
      doctor [--request-permission]
      list [--query TEXT] [--limit N]
      search TEXT [--limit N]
      get --id CONTACT_IDENTIFIER
      add --input PATH|--input -|--json JSON [--dry-run]
      upsert --input PATH|--input -|--json JSON [--dry-run]
      update --id CONTACT_IDENTIFIER --input PATH|--json JSON [--dry-run]
      delete --id CONTACT_IDENTIFIER [--dry-run|--confirm-delete]

    All operational commands return JSON. Mutating commands support --dry-run.
    """
}

private struct ParsedArguments {
    let command: String
    let options: [String: String]
    let flags: Set<String>
    let positionals: [String]

    init(_ args: [String]) throws {
        guard let first = args.first else {
            command = "help"
            options = [:]
            flags = ["help"]
            positionals = []
            return
        }

        command = first
        var parsedOptions: [String: String] = [:]
        var parsedFlags: Set<String> = []
        var parsedPositionals: [String] = []
        var index = 1

        while index < args.count {
            let token = args[index]
            if token == "-h" {
                parsedFlags.insert("help")
            } else if token.hasPrefix("--") {
                let raw = String(token.dropFirst(2))
                let pieces = raw.split(separator: "=", maxSplits: 1).map(String.init)
                let name = pieces[0]
                if Self.valueOptions.contains(name) {
                    if pieces.count == 2 {
                        parsedOptions[name] = pieces[1]
                    } else {
                        index += 1
                        guard index < args.count else {
                            throw ContactsCLIError.message("--\(name) requires a value")
                        }
                        parsedOptions[name] = args[index]
                    }
                } else if Self.flagOptions.contains(name) {
                    parsedFlags.insert(name)
                } else {
                    throw ContactsCLIError.message("unknown option --\(name)")
                }
            } else {
                parsedPositionals.append(token)
            }
            index += 1
        }

        options = parsedOptions
        flags = parsedFlags
        positionals = parsedPositionals
    }

    func option(_ name: String) -> String? {
        options[name]
    }

    func hasFlag(_ name: String) -> Bool {
        flags.contains(name)
    }

    func integerOption(_ name: String) throws -> Int? {
        guard let value = options[name] else {
            return nil
        }
        guard let integer = Int(value) else {
            throw ContactsCLIError.message("--\(name) must be an integer")
        }
        return integer
    }

    func requiredIdentifier() throws -> String {
        if let identifier = option("id"), !identifier.isEmpty {
            return identifier
        }
        if let identifier = positionals.first, !identifier.isEmpty {
            return identifier
        }
        throw ContactsCLIError.message("command requires --id CONTACT_IDENTIFIER")
    }

    private static let valueOptions: Set<String> = ["id", "input", "json", "limit", "query"]
    private static let flagOptions: Set<String> = ["confirm-delete", "dry-run", "help", "request-permission"]
}

private struct DoctorResponse: Encodable {
    let ok = true
    let status: String
}

private struct ListResponse: Encodable {
    let ok = true
    let query: String?
    let count: Int
    let contacts: [ContactRecord]
}

private struct ContactResponse: Encodable {
    let ok = true
    let contact: ContactRecord
}

private struct OperationResponse: Encodable {
    let ok = true
    let result: ContactOperationResult
}

private struct ErrorResponse: Encodable {
    let ok = false
    let error: String
}
