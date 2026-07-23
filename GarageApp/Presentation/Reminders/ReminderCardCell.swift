//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

@MainActor
final class ReminderCardCell: UITableViewCell {
    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var statusStripView: UIView!
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var badgeContainerView: UIView!
    @IBOutlet private weak var badgeLabel: UILabel!
    @IBOutlet private weak var targetIconImageView: UIImageView!
    @IBOutlet private weak var targetLabel: UILabel!
    @IBOutlet private weak var remainingLabel: UILabel!
    @IBOutlet private weak var chevronImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        AppTheme.styleCard(cardView)
        statusStripView.layer.cornerRadius = 2
        statusStripView.layer.cornerCurve = .continuous

        iconContainerView.layer.cornerRadius = 29
        iconContainerView.layer.cornerCurve = .continuous
        iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 25, weight: .medium)

        titleLabel.font = AppTheme.font(.headline, weight: .semibold)
        titleLabel.textColor = AppTheme.primaryTextColor
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2

        badgeContainerView.layer.cornerRadius = AppTheme.Radius.compact
        badgeContainerView.layer.cornerCurve = .continuous
        badgeLabel.font = AppTheme.font(.caption1, weight: .semibold)
        badgeLabel.adjustsFontForContentSizeCategory = true

        targetIconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        targetLabel.font = AppTheme.font(.footnote)
        targetLabel.textColor = AppTheme.secondaryTextColor
        targetLabel.adjustsFontForContentSizeCategory = true
        targetLabel.numberOfLines = 2

        remainingLabel.font = AppTheme.font(.footnote, weight: .semibold)
        remainingLabel.adjustsFontForContentSizeCategory = true
        remainingLabel.numberOfLines = 2

        chevronImageView.tintColor = AppTheme.secondaryTextColor
        chevronImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
    }

    func configure(
        reminder: Reminder,
        currentMileage: Int64,
        linkedRecordType: RecordType?,
        showsDisclosure: Bool
    ) {
        let appearance = appearance(for: reminder.status)
        let target = targetText(for: reminder)
        let remaining = remainingText(for: reminder, currentMileage: currentMileage)

        statusStripView.backgroundColor = appearance.color
        iconContainerView.backgroundColor = appearance.color.withAlphaComponent(0.10)
        iconImageView.tintColor = appearance.color
        iconImageView.image = UIImage(systemName: symbolName(for: reminder, linkedRecordType: linkedRecordType))

        titleLabel.text = reminder.title
        badgeLabel.text = reminder.status.displayName
        badgeLabel.textColor = appearance.color
        badgeContainerView.backgroundColor = appearance.color.withAlphaComponent(0.10)

        targetIconImageView.image = UIImage(systemName: target.symbol)
        targetIconImageView.tintColor = AppTheme.secondaryTextColor
        targetLabel.text = target.text
        targetIconImageView.isHidden = target.text == nil
        targetLabel.isHidden = target.text == nil

        remainingLabel.text = remaining.text
        remainingLabel.textColor = remaining.isUrgent ? appearance.color : AppTheme.secondaryTextColor
        remainingLabel.isHidden = remaining.text == nil
        chevronImageView.isHidden = !showsDisclosure

        var accessibilityParts = [reminder.title, reminder.status.displayName]
        if let targetText = target.text { accessibilityParts.append(targetText) }
        if let remainingText = remaining.text { accessibilityParts.append(remainingText) }
        accessibilityLabel = accessibilityParts.joined(separator: ", ")
        accessibilityHint = showsDisclosure ? "Hatırlatma ayrıntısını açar" : "Kaydırarak tamamlayabilir veya silebilirsiniz"
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        targetLabel.text = nil
        remainingLabel.text = nil
        iconImageView.image = nil
        targetIconImageView.image = nil
        chevronImageView.isHidden = true
    }

    private func appearance(for status: ReminderStatus) -> (color: UIColor, isFinal: Bool) {
        switch status {
        case .overdue: return (AppTheme.dangerColor, false)
        case .approaching: return (AppTheme.warningColor, false)
        case .active: return (AppTheme.accentColor, false)
        case .completed: return (AppTheme.successColor, true)
        case .cancelled: return (AppTheme.secondaryTextColor, true)
        }
    }

    private func symbolName(for reminder: Reminder, linkedRecordType: RecordType?) -> String {
        if let linkedRecordType {
            switch linkedRecordType {
            case .maintenance: return "wrench"
            case .fuel: return "fuelpump"
            case .expense: return "creditcard"
            case .insurance: return "shield"
            case .inspection: return "checkmark.clipboard"
            case .mileage: return "gauge.with.dots.needle.67percent"
            case .note: return "bell"
            }
        }

        let normalizedTitle = reminder.title.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "tr_TR")
        )
        if normalizedTitle.contains("sigorta") || normalizedTitle.contains("kasko") || normalizedTitle.contains("police") {
            return "shield"
        }
        if normalizedTitle.contains("muayene") || normalizedTitle.contains("egzoz") || normalizedTitle.contains("kontrol") {
            return "checkmark.clipboard"
        }
        if normalizedTitle.contains("bakim") || normalizedTitle.contains("servis") || normalizedTitle.contains("yag") || normalizedTitle.contains("filtre") {
            return "wrench"
        }
        if normalizedTitle.contains("kilometre") {
            return "gauge.with.dots.needle.67percent"
        }
        return reminder.status == .completed ? "checkmark.circle" : "bell"
    }

    private func targetText(for reminder: Reminder) -> (symbol: String, text: String?) {
        var pieces: [String] = []
        if let dueDate = reminder.dueDate {
            pieces.append(AppFormatters.date.string(from: dueDate))
        }
        if let dueMileage = reminder.dueMileage {
            let formattedMileage = AppFormatters.mileage.string(from: NSNumber(value: dueMileage)) ?? String(dueMileage)
            pieces.append("\(formattedMileage) km")
        }
        let symbol = reminder.dueDate != nil ? "calendar" : "gauge.with.dots.needle.67percent"
        return (symbol, pieces.isEmpty ? nil : pieces.joined(separator: " • "))
    }

    private func remainingText(for reminder: Reminder, currentMileage: Int64) -> (text: String?, isUrgent: Bool) {
        if reminder.status == .completed {
            if let completedAt = reminder.completedAt {
                return ("\(AppFormatters.date.string(from: completedAt)) tamamlandı", false)
            }
            return ("Tamamlandı", false)
        }
        if reminder.status == .cancelled { return ("İptal edildi", false) }

        var candidates: [(distance: Int64, text: String, isUrgent: Bool)] = []
        if let dueDate = reminder.dueDate {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: .now)
            let end = calendar.startOfDay(for: dueDate)
            let days = Int64(calendar.dateComponents([.day], from: start, to: end).day ?? 0)
            switch days {
            case ..<0: candidates.append((days, "\(-days) gün geçti", true))
            case 0: candidates.append((0, "Bugün", reminder.status == .overdue))
            default: candidates.append((days, "\(days) gün kaldı", reminder.status == .approaching))
            }
        }
        if let dueMileage = reminder.dueMileage {
            let difference = dueMileage - currentMileage
            switch difference {
            case ..<0: candidates.append((difference, "\(-difference) km geçti", true))
            case 0: candidates.append((0, "Hedefe ulaşıldı", true))
            default: candidates.append((difference, "\(difference) km kaldı", reminder.status == .approaching))
            }
        }

        let selected = candidates.sorted { lhs, rhs in
            if lhs.isUrgent != rhs.isUrgent { return lhs.isUrgent }
            return abs(lhs.distance) < abs(rhs.distance)
        }.first
        return (selected?.text, selected?.isUrgent ?? false)
    }
}

@MainActor
final class ReminderFilterHeaderView: UIView {
    @IBOutlet private weak var segmentedControl: UISegmentedControl!

    private var onSelectionChanged: ((Int) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppTheme.backgroundColor
        AppTheme.styleSegmentedControl(segmentedControl)
        segmentedControl.addTarget(self, action: #selector(selectionChanged), for: .valueChanged)
    }

    func configure(selectedIndex: Int, onSelectionChanged: @escaping (Int) -> Void) {
        segmentedControl.selectedSegmentIndex = selectedIndex
        self.onSelectionChanged = onSelectionChanged
    }

    @objc private func selectionChanged() {
        onSelectionChanged?(segmentedControl.selectedSegmentIndex)
    }
}
