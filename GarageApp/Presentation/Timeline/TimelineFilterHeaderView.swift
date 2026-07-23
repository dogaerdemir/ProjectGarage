//
//  Created by Doğa Erdemir on 23.07.2026.
//

import UIKit

final class TimelineFilterHeaderView: UIView, UISearchBarDelegate {
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var filterScrollView: UIScrollView!

    var onSearchTextChanged: ((String) -> Void)?
    var onFilterSelected: ((RecordType?) -> Void)?

    private let filterStackView = UIStackView()
    private var filterTypes: [RecordType] = []
    private var selectedType: RecordType?
    private var filterButtons: [UIButton] = []

    static func instantiate() -> TimelineFilterHeaderView {
        guard let view = UINib(nibName: "TimelineFilterHeaderView", bundle: .main)
            .instantiate(withOwner: nil)
            .first as? TimelineFilterHeaderView else {
            preconditionFailure("TimelineFilterHeaderView.xib could not be loaded")
        }
        return view
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = AppTheme.backgroundColor

        searchBar.delegate = self
        searchBar.placeholder = "Kayıtlarda ara"
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.returnKeyType = .search
        searchBar.accessibilityLabel = "Kayıtlarda ara"
        searchBar.searchTextField.backgroundColor = AppTheme.inputColor
        searchBar.searchTextField.textColor = AppTheme.primaryTextColor
        searchBar.searchTextField.layer.cornerRadius = AppTheme.Radius.control
        searchBar.searchTextField.layer.cornerCurve = .continuous
        searchBar.searchTextField.layer.borderWidth = AppTheme.Metrics.borderWidth
        searchBar.searchTextField.layer.borderColor = AppTheme.borderColor.cgColor

        filterScrollView.showsHorizontalScrollIndicator = false
        filterScrollView.alwaysBounceHorizontal = true

        filterStackView.axis = .horizontal
        filterStackView.alignment = .fill
        filterStackView.distribution = .fill
        filterStackView.spacing = FilterPillStyle.spacing
        filterScrollView.addSubview(filterStackView)
        filterStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            filterStackView.leadingAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.leadingAnchor),
            filterStackView.trailingAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.trailingAnchor),
            filterStackView.topAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.topAnchor),
            filterStackView.bottomAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.bottomAnchor),
            filterStackView.heightAnchor.constraint(equalTo: filterScrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    func configure(types: [RecordType], selectedType: RecordType?) {
        self.selectedType = selectedType
        if filterTypes != types {
            filterTypes = types
            rebuildFilterButtons()
        }
        updateFilterButtons()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        onSearchTextChanged?(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    private func rebuildFilterButtons() {
        filterButtons.forEach { $0.removeFromSuperview() }
        filterButtons = ([nil] + filterTypes.map(Optional.some)).enumerated().map { index, type in
            let button = UIButton(type: .system)
            button.tag = index
            button.configuration = configuration(title: type?.displayName ?? "Tümü", isSelected: false)
            button.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(equalToConstant: FilterPillStyle.height).isActive = true
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.accessibilityIdentifier = type.map { "timeline.filter.\($0.rawValue)" } ?? "timeline.filter.all"
            filterStackView.addArrangedSubview(button)
            return button
        }
    }

    private func updateFilterButtons() {
        for (index, button) in filterButtons.enumerated() {
            let type: RecordType? = index == 0 ? nil : filterTypes[index - 1]
            let isSelected = type == selectedType
            button.configuration = configuration(title: type?.displayName ?? "Tümü", isSelected: isSelected)
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    private func configuration(title: String, isSelected: Bool) -> UIButton.Configuration {
        FilterPillStyle.configuration(title: title, isSelected: isSelected)
    }

    @objc private func filterTapped(_ sender: UIButton) {
        let type: RecordType? = sender.tag == 0 ? nil : filterTypes[sender.tag - 1]
        onFilterSelected?(type)
    }
}
