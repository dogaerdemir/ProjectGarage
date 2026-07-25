//
//  Created by Doğa Erdemir on 24.07.2026.
//

import MapKit
import UIKit

final class NearbyViewController: UIViewController {
    var onUsePlace: ((RecordType, String) -> Void)?

    @IBOutlet private weak var categoryScrollView: UIScrollView!
    @IBOutlet private weak var mapContainerView: UIView!
    @IBOutlet private weak var resultsTitleLabel: UILabel!
    @IBOutlet private weak var resultsCountLabel: UILabel!
    @IBOutlet private weak var tableView: UITableView!

    private let viewModel: NearbyViewModel
    private let categoryStackView = UIStackView()
    private let mapView = MKMapView()
    private var categoryButtons: [UIButton] = []
    private var placesByID: [String: NearbyPlace] = [:]
    private let refreshControl = UIRefreshControl()
    private var isWaitingForLocationSettings = false

    init(viewModel: NearbyViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "NearbyViewController", bundle: .main)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Yakındakiler"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = AppTheme.backgroundColor
        configureCategories()
        configureMap()
        configureTableView()
        configureNavigation()
        bindViewModel()
        render(viewModel.state)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureCategories() {
        categoryScrollView.showsHorizontalScrollIndicator = false
        categoryScrollView.alwaysBounceHorizontal = true

        categoryStackView.axis = .horizontal
        categoryStackView.alignment = .fill
        categoryStackView.distribution = .fill
        categoryStackView.spacing = FilterPillStyle.spacing
        categoryScrollView.addSubview(categoryStackView)
        categoryStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            categoryStackView.leadingAnchor.constraint(equalTo: categoryScrollView.contentLayoutGuide.leadingAnchor),
            categoryStackView.trailingAnchor.constraint(equalTo: categoryScrollView.contentLayoutGuide.trailingAnchor),
            categoryStackView.topAnchor.constraint(equalTo: categoryScrollView.contentLayoutGuide.topAnchor),
            categoryStackView.bottomAnchor.constraint(equalTo: categoryScrollView.contentLayoutGuide.bottomAnchor),
            categoryStackView.heightAnchor.constraint(equalTo: categoryScrollView.frameLayoutGuide.heightAnchor)
        ])

        categoryButtons = NearbyCategory.allCases.enumerated().map { index, category in
            let button = UIButton(type: .system)
            button.tag = index
            button.heightAnchor.constraint(equalToConstant: FilterPillStyle.height).isActive = true
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            button.accessibilityIdentifier = "nearby.category.\(category.rawValue)"
            categoryStackView.addArrangedSubview(button)
            return button
        }
    }

    private func configureMap() {
        AppTheme.styleCard(mapContainerView)
        mapView.delegate = self
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = false
        mapView.isPitchEnabled = false
        mapView.layer.cornerRadius = AppTheme.Radius.card
        mapView.layer.cornerCurve = .continuous
        mapView.clipsToBounds = true
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: NearbyPlaceAnnotation.reuseIdentifier
        )
        mapContainerView.addSubview(mapView)
        mapView.pinToEdges(of: mapContainerView)
    }

    private func configureTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            UINib(nibName: "NearbyPlaceCell", bundle: .main),
            forCellReuseIdentifier: NearbyPlaceCell.reuseIdentifier
        )
        tableView.backgroundColor = AppTheme.backgroundColor
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: AppTheme.Spacing.large, right: 0)
        tableView.accessibilityIdentifier = "nearby.list"

        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    private func configureNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refresh)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Yakındaki işletmeleri yenile"
    }

    private func bindViewModel() {
        viewModel.onChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func render(_ state: NearbyViewModel.State) {
        updateCategoryButtons(selectedCategory: state.selectedCategory, isLoading: state.phase == .loading)
        resultsTitleLabel.text = "\(state.selectedCategory.title) Sonuçları"
        resultsCountLabel.text = state.places.isEmpty ? nil : "\(state.places.count)"
        resultsCountLabel.isHidden = state.places.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = state.phase != .loading
        if state.phase != .loading {
            refreshControl.endRefreshing()
        }
        tableView.reloadData()
        renderMap(places: state.places, userLocation: state.userLocation)

        switch state.phase {
        case .idle:
            tableView.backgroundView = EmptyStateView(
                symbol: "location.circle.fill",
                title: "Yakınınızdaki yerleri bulun",
                message: "Konumunuz yalnızca bu arama sırasında kullanılır ve kaydedilmez.",
                actionTitle: "Konumumu Kullan"
            ) { [weak self] in
                self?.requestNearbyPlaces()
            }
        case .loading:
            tableView.backgroundView = loadingStateView()
        case .loaded:
            tableView.backgroundView = nil
        case .empty:
            tableView.backgroundView = EmptyStateView(
                symbol: "map",
                title: "Sonuç bulunamadı",
                message: state.message ?? "Bu bölgede uygun işletme bulunamadı.",
                actionTitle: "Tekrar Ara"
            ) { [weak self] in
                self?.requestNearbyPlaces()
            }
        case .failure:
            tableView.backgroundView = EmptyStateView(
                symbol: state.requiresSettings ? "location.slash.fill" : "exclamationmark.triangle.fill",
                title: state.requiresSettings ? "Konum izni gerekli" : "Arama tamamlanamadı",
                message: state.message ?? "Lütfen tekrar deneyin.",
                actionTitle: state.requiresSettings ? "Ayarları Aç" : "Tekrar Dene"
            ) { [weak self] in
                if state.requiresSettings {
                    self?.openApplicationSettings()
                } else {
                    self?.requestNearbyPlaces()
                }
            }
        }
    }

    private func updateCategoryButtons(selectedCategory: NearbyCategory, isLoading: Bool) {
        for (index, button) in categoryButtons.enumerated() {
            guard NearbyCategory.allCases.indices.contains(index) else { continue }
            let category = NearbyCategory.allCases[index]
            let isSelected = category == selectedCategory
            var configuration = FilterPillStyle.configuration(title: category.title, isSelected: isSelected)
            configuration.image = UIImage(systemName: category.symbolName)
            configuration.imagePadding = 6
            button.configuration = configuration
            button.isEnabled = !isLoading
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    private func renderMap(places: [NearbyPlace], userLocation: CLLocation?) {
        let currentAnnotations = mapView.annotations.compactMap { $0 as? NearbyPlaceAnnotation }
        mapView.removeAnnotations(currentAnnotations)
        placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })

        let annotations = places.map { NearbyPlaceAnnotation(place: $0) }
        mapView.addAnnotations(annotations)
        if annotations.count == 1, let place = places.first {
            mapView.setRegion(
                MKCoordinateRegion(
                    center: place.coordinate,
                    latitudinalMeters: 5_000,
                    longitudinalMeters: 5_000
                ),
                animated: true
            )
        } else if !annotations.isEmpty {
            mapView.showAnnotations(annotations, animated: true)
        } else if let userLocation {
            mapView.setRegion(
                MKCoordinateRegion(
                    center: userLocation.coordinate,
                    latitudinalMeters: 12_000,
                    longitudinalMeters: 12_000
                ),
                animated: true
            )
        }
    }

    private func loadingStateView() -> UIView {
        let container = UIView()
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        indicator.color = AppTheme.accentColor
        let label = UILabel()
        label.text = "Yakındaki işletmeler aranıyor…"
        label.font = AppTheme.font(.body)
        label.textColor = AppTheme.secondaryTextColor
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [indicator, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = AppTheme.Spacing.medium
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: AppTheme.Spacing.large),
            container.trailingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor, constant: AppTheme.Spacing.large)
        ])
        container.accessibilityLabel = label.text
        return container
    }

    private func requestNearbyPlaces() {
        Task { await viewModel.requestNearbyPlaces() }
    }

    private func showDetails(for place: NearbyPlace, sourceView: UIView?) {
        var messageParts: [String] = []
        if let address = place.address { messageParts.append(address) }
        if let phone = place.phoneNumber { messageParts.append(phone) }

        let alert = UIAlertController(
            title: place.name,
            message: messageParts.isEmpty ? "İşletme bilgisi bulunmuyor." : messageParts.joined(separator: "\n"),
            preferredStyle: .actionSheet
        )
        if let phoneNumber = place.phoneNumber {
            alert.addAction(UIAlertAction(title: "Ara", style: .default) { [weak self] _ in
                self?.call(phoneNumber)
            })
        }
        alert.addAction(UIAlertAction(title: "Apple Maps’te Aç", style: .default) { _ in
            place.mapItem.openInMaps(
                launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
            )
        })
        if onUsePlace != nil {
            let actionTitle = switch place.category.suggestedRecordType {
            case .fuel: "Yakıt Kaydında Kullan"
            case .inspection: "Muayene Kaydında Kullan"
            default: "Bakım Kaydında Kullan"
            }
            alert.addAction(UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.onUsePlace?(place.category.suggestedRecordType, place.name)
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView ?? view
            popover.sourceRect = sourceView?.bounds ?? CGRect(
                x: view.bounds.midX,
                y: view.bounds.maxY,
                width: 1,
                height: 1
            )
        }
        present(alert, animated: true)
    }

    private func call(_ phoneNumber: String) {
        let normalized = phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard !normalized.isEmpty, let url = URL(string: "tel:\(normalized)") else { return }
        UIApplication.shared.open(url)
    }

    private func openApplicationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        isWaitingForLocationSettings = true
        UIApplication.shared.open(url)
    }

    @objc private func applicationDidBecomeActive() {
        guard isWaitingForLocationSettings else { return }
        isWaitingForLocationSettings = false
        let authorizationStatus = CLLocationManager().authorizationStatus
        guard authorizationStatus == .authorizedAlways
                || authorizationStatus == .authorizedWhenInUse else {
            return
        }
        requestNearbyPlaces()
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        guard NearbyCategory.allCases.indices.contains(sender.tag) else { return }
        let category = NearbyCategory.allCases[sender.tag]
        Task { await viewModel.select(category) }
    }

    @objc private func refresh() {
        Task { await viewModel.refresh() }
    }
}

extension NearbyViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.state.places.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: NearbyPlaceCell.reuseIdentifier,
            for: indexPath
        ) as? NearbyPlaceCell else {
            return UITableViewCell()
        }
        cell.configure(with: viewModel.state.places[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard viewModel.state.places.indices.contains(indexPath.row) else { return }
        showDetails(
            for: viewModel.state.places[indexPath.row],
            sourceView: tableView.cellForRow(at: indexPath)
        )
    }
}

extension NearbyViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? NearbyPlaceAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: NearbyPlaceAnnotation.reuseIdentifier,
            for: annotation
        ) as! MKMarkerAnnotationView
        view.markerTintColor = placesByID[annotation.placeID]?.category.displayColor ?? AppTheme.accentColor
        view.glyphImage = placesByID[annotation.placeID]
            .flatMap { UIImage(systemName: $0.category.symbolName) }
        view.canShowCallout = true
        view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        return view
    }

    func mapView(
        _ mapView: MKMapView,
        annotationView view: MKAnnotationView,
        calloutAccessoryControlTapped control: UIControl
    ) {
        guard let annotation = view.annotation as? NearbyPlaceAnnotation,
              let place = placesByID[annotation.placeID] else {
            return
        }
        showDetails(for: place, sourceView: view)
    }
}

private final class NearbyPlaceAnnotation: NSObject, MKAnnotation {
    static let reuseIdentifier = "NearbyPlaceAnnotation"

    let placeID: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(place: NearbyPlace) {
        placeID = place.id
        coordinate = place.coordinate
        title = place.name
        subtitle = place.address
        super.init()
    }
}
