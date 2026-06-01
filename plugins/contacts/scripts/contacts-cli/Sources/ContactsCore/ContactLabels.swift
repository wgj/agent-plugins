import Contacts
import Foundation

public enum ContactValueKind {
    case phone
    case email
}

public enum ContactLabels {
    public static func contactsLabel(_ rawLabel: String?, kind: ContactValueKind) -> String? {
        let normalized = (rawLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        switch normalized.lowercased() {
        case "home":
            return CNLabelHome
        case "work":
            return CNLabelWork
        case "other":
            return CNLabelOther
        case "mobile":
            return kind == .phone ? CNLabelPhoneNumberMobile : normalized
        case "iphone":
            return kind == .phone ? CNLabelPhoneNumberiPhone : normalized
        case "main":
            return kind == .phone ? CNLabelPhoneNumberMain : normalized
        case "homefax", "home-fax", "home fax":
            return kind == .phone ? CNLabelPhoneNumberHomeFax : normalized
        case "workfax", "work-fax", "work fax":
            return kind == .phone ? CNLabelPhoneNumberWorkFax : normalized
        case "otherfax", "other-fax", "other fax":
            return kind == .phone ? CNLabelPhoneNumberOtherFax : normalized
        case "pager":
            return kind == .phone ? CNLabelPhoneNumberPager : normalized
        default:
            return normalized
        }
    }

    public static func displayLabel(_ contactsLabel: String?) -> String? {
        guard let contactsLabel, !contactsLabel.isEmpty else {
            return nil
        }

        switch contactsLabel {
        case CNLabelHome:
            return "home"
        case CNLabelWork:
            return "work"
        case CNLabelOther:
            return "other"
        case CNLabelPhoneNumberMobile:
            return "mobile"
        case CNLabelPhoneNumberiPhone:
            return "iphone"
        case CNLabelPhoneNumberMain:
            return "main"
        case CNLabelPhoneNumberHomeFax:
            return "homeFax"
        case CNLabelPhoneNumberWorkFax:
            return "workFax"
        case CNLabelPhoneNumberOtherFax:
            return "otherFax"
        case CNLabelPhoneNumberPager:
            return "pager"
        default:
            return contactsLabel
        }
    }
}
