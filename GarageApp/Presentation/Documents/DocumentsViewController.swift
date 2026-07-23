//
//  Created by Doğa Erdemir on 12.07.2026.
//

import PDFKit
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

final class DocumentsViewController: UIViewController {
    private enum Layout {
        static let horizontalInset = AppTheme.Metrics.horizontalMargin
        static let interItemSpacing: CGFloat = 12
        static let cardHeight: CGFloat = 218
        static let thumbnailSize = CGSize(width: 352, height: 260)
    }

    private enum DocumentSource {
        case files
        case photos
        case scanner

        var option: SelectionSheetOption {
            switch self {
            case .files:
                SelectionSheetOption(title: "Dosyalardan Seç", symbolName: "folder")
            case .photos:
                SelectionSheetOption(title: "Fotoğraflardan Seç", symbolName: "photo")
            case .scanner:
                SelectionSheetOption(title: "Belge Tara", symbolName: "doc.viewfinder")
            }
        }
    }

    private struct PendingDocument {
        let data: Data
        let name: String
        let mimeType: String
        let fileExtension: String
    }

    var viewModel: DocumentsViewModel!
    var session: AppSession!
    var repository: DocumentRepository!
    var storage: FileStorageService!

    private let titleLabel = UILabel()
    private let searchField = UISearchTextField()
    private let filterScrollView = UIScrollView()
    private let filterStackView = UIStackView()
    private let addButton = UIButton(type: .system)
    private let thumbnailCache = NSCache<NSUUID, UIImage>()
    private var thumbnailTasks: [UUID: Task<Void, Never>] = [:]
    private var filterButtons: [DocumentsViewModel.Filter: DocumentFilterButton] = [:]
    private var visibleDocuments: [GarageDocument] = []
    private var selectedType: DocumentType = .other
    private var lastCollectionWidth: CGFloat = 0

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Layout.interItemSpacing
        layout.minimumLineSpacing = Layout.interItemSpacing
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.keyboardDismissMode = .onDrag
        collectionView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: AppTheme.Metrics.floatingContentBottomInset,
            right: 0
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            UINib(nibName: DocumentGridCell.reuseIdentifier, bundle: .main),
            forCellWithReuseIdentifier: DocumentGridCell.reuseIdentifier
        )
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = nil
        view.backgroundColor = AppTheme.backgroundColor
        configureUI()
        bindViewModel()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reload),
            name: .garageDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reload),
            name: .selectedVehicleDidChange,
            object: nil
        )
        Task { await viewModel.load() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        thumbnailTasks.values.forEach { $0.cancel() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard abs(collectionView.bounds.width - lastCollectionWidth) > 0.5 else { return }
        lastCollectionWidth = collectionView.bounds.width
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func configureUI() {
        view.subviews.forEach { $0.removeFromSuperview() }

        titleLabel.text = "Belgeler"
        AppTheme.stylePageTitle(titleLabel)

        searchField.placeholder = "Belgelerde ara"
        AppTheme.styleSearchField(searchField)
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .search
        searchField.autocapitalizationType = .none
        searchField.autocorrectionType = .no
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        searchField.accessibilityLabel = "Belgelerde ara"

        filterScrollView.showsHorizontalScrollIndicator = false
        filterScrollView.alwaysBounceHorizontal = true

        filterStackView.axis = .horizontal
        filterStackView.alignment = .fill
        filterStackView.spacing = FilterPillStyle.spacing
        filterStackView.distribution = .fill
        for filter in DocumentsViewModel.Filter.allCases {
            let button = DocumentFilterButton(filter: filter)
            button.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            filterStackView.addArrangedSubview(button)
            filterButtons[filter] = button
        }
        filterScrollView.addSubview(filterStackView)
        filterStackView.translatesAutoresizingMaskIntoConstraints = false

        AppTheme.styleFloatingButton(addButton)
        addButton.accessibilityLabel = "Belge ekle"
        addButton.addTarget(self, action: #selector(addDocument), for: .touchUpInside)

        [titleLabel, searchField, filterScrollView, collectionView, addButton].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: AppTheme.Metrics.pageTopInset
            ),
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Layout.horizontalInset),
            titleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Layout.horizontalInset),

            searchField.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: AppTheme.Metrics.pageTitleToSearchSpacing
            ),
            searchField.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            searchField.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.searchFieldHeight),

            filterScrollView.topAnchor.constraint(
                equalTo: searchField.bottomAnchor,
                constant: AppTheme.Metrics.searchToFilterSpacing
            ),
            filterScrollView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            filterScrollView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            filterScrollView.heightAnchor.constraint(equalToConstant: FilterPillStyle.height),

            filterStackView.leadingAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.leadingAnchor),
            filterStackView.trailingAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.trailingAnchor),
            filterStackView.topAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.topAnchor),
            filterStackView.bottomAnchor.constraint(equalTo: filterScrollView.contentLayoutGuide.bottomAnchor),
            filterStackView.heightAnchor.constraint(equalTo: filterScrollView.frameLayoutGuide.heightAnchor),

            collectionView.topAnchor.constraint(
                equalTo: filterScrollView.bottomAnchor,
                constant: AppTheme.Metrics.filterToContentSpacing
            ),
            collectionView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            addButton.widthAnchor.constraint(equalToConstant: AppTheme.Metrics.floatingButtonSize),
            addButton.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.floatingButtonSize),
            addButton.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -AppTheme.Metrics.floatingButtonTrailingInset
            ),
            addButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -AppTheme.Metrics.floatingButtonBottomInset
            )
        ])

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: DocumentsViewController, _) in
            controller.updateFilterButtons()
        }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: DocumentsViewController, _) in
            controller.collectionView.collectionViewLayout.invalidateLayout()
        }
        updateFilterButtons()
    }

    private func bindViewModel() {
        viewModel.onChange = { [weak self] in self?.render() }
        viewModel.onError = { [weak self] in self?.presentError($0) }
    }

    private func render() {
        visibleDocuments = viewModel.documents
        collectionView.reloadData()
        updateFilterButtons()

        if visibleDocuments.isEmpty {
            let hasSearchOrFilter = !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.selectedFilter != .all
            if hasSearchOrFilter, viewModel.hasDocuments {
                collectionView.backgroundView = EmptyStateView(
                    symbol: "doc.text.magnifyingglass",
                    title: "Belge bulunamadı",
                    message: "Arama metnini veya filtreyi değiştirerek yeniden deneyin."
                )
            } else {
                collectionView.backgroundView = EmptyStateView(
                    symbol: "doc.text.image.fill",
                    title: "Henüz belge yok",
                    message: "Fatura, poliçe, muayene belgesi veya araç fotoğrafı ekleyin.",
                    actionTitle: "Belge Ekle"
                ) { [weak self] in
                    self?.addDocument()
                }
            }
        } else {
            collectionView.backgroundView = nil
        }
    }

    private func updateFilterButtons() {
        for (filter, button) in filterButtons {
            button.setSelected(viewModel != nil && filter == viewModel.selectedFilter)
        }
    }

    @objc private func searchTextChanged() {
        viewModel.query = searchField.text ?? ""
    }

    @objc private func filterTapped(_ sender: DocumentFilterButton) {
        viewModel.selectedFilter = sender.filter
    }

    private func open(_ document: GarageDocument) {
        Task {
            do {
                let data = try await storage.read(relativePath: document.localRelativePath)
                presentDocumentPreview(document: document, data: data)
            } catch {
                presentError(error)
            }
        }
    }

    private func requestDelete(_ document: GarageDocument) {
        confirm(
            title: "Belgeyi Sil",
            message: "\(displayTitle(for: document)) kalıcı olarak silinecek.",
            destructiveTitle: "Sil"
        ) { [weak self] in
            guard let self else { return }
            Task {
                do {
                    try await DeleteDocumentUseCase(repository: self.repository, storage: self.storage)
                        .execute(documentID: document.id)
                    self.thumbnailCache.removeObject(forKey: document.id as NSUUID)
                    await self.session.dataChanged()
                } catch {
                    self.presentError(error)
                }
            }
        }
    }

    private func loadThumbnail(for document: GarageDocument) {
        guard thumbnailTasks[document.id] == nil else { return }
        thumbnailTasks[document.id] = Task { [weak self] in
            guard let self else { return }
            defer { self.thumbnailTasks[document.id] = nil }
            do {
                let data = try await self.storage.read(relativePath: document.localRelativePath)
                guard !withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }),
                      let thumbnail = Self.makeThumbnail(
                          data: data,
                          mimeType: document.mimeType,
                          targetSize: Layout.thumbnailSize
                      )
                else { return }
                self.thumbnailCache.setObject(thumbnail, forKey: document.id as NSUUID)
                self.collectionView.visibleCells
                    .compactMap { $0 as? DocumentGridCell }
                    .filter { $0.representedDocumentID == document.id }
                    .forEach {
                        $0.setThumbnail(
                            thumbnail,
                            for: document.id,
                            isPhoto: document.mimeType.hasPrefix("image/")
                        )
                    }
            } catch {
                // The placeholder remains visible; opening the document still reports the storage error.
            }
        }
    }

    private static func makeThumbnail(data: Data, mimeType: String, targetSize: CGSize) -> UIImage? {
        if mimeType == "application/pdf",
           let document = PDFDocument(data: data),
           let page = document.page(at: 0) {
            let image = page.thumbnail(of: targetSize, for: .mediaBox)
            return renderedThumbnail(image, targetSize: targetSize, fill: false)
        }
        guard let image = UIImage(data: data) else { return nil }
        return renderedThumbnail(image, targetSize: targetSize, fill: true)
    }

    private static func renderedThumbnail(_ image: UIImage, targetSize: CGSize, fill: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            guard image.size.width > 0, image.size.height > 0 else { return }
            let horizontalScale = targetSize.width / image.size.width
            let verticalScale = targetSize.height / image.size.height
            let scale = fill ? max(horizontalScale, verticalScale) : min(horizontalScale, verticalScale)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
    }

    private func displayTitle(for document: GarageDocument) -> String {
        let title = (document.displayName as NSString).deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? document.documentType.displayName : title
    }

    @objc private func addDocument() {
        guard session.selectedVehicle != nil else {
            presentError(GarageError.validation("Önce bir araç ekleyin."))
            return
        }
        chooseSource()
    }

    private func chooseSource() {
        var sources: [DocumentSource] = [.files, .photos]
        if VNDocumentCameraViewController.isSupported { sources.append(.scanner) }
        presentSelectionSheet(title: "Belge Ekle", options: sources.map(\.option)) { [weak self] index in
            guard let self, sources.indices.contains(index) else { return }
            switch sources[index] {
            case .files:
                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)
                picker.delegate = self
                present(picker, animated: true)
            case .photos:
                var configuration = PHPickerConfiguration(photoLibrary: .shared())
                configuration.filter = .images
                configuration.selectionLimit = 1
                let picker = PHPickerViewController(configuration: configuration)
                picker.delegate = self
                present(picker, animated: true)
            case .scanner:
                let scanner = VNDocumentCameraViewController()
                scanner.delegate = self
                present(scanner, animated: true)
            }
        }
    }

    private func chooseTypeAndAttach(_ pendingDocuments: [PendingDocument]) {
        guard !pendingDocuments.isEmpty else { return }
        let types = DocumentType.allCases
        presentSelectionSheet(
            title: "Belge Türü",
            message: "Belgeyi daha sonra kolay bulmak için türünü seçin.",
            options: types.map { SelectionSheetOption(title: $0.displayName, symbolName: $0.symbolName) },
            selectedIndex: types.firstIndex(of: selectedType)
        ) { [weak self] index in
            guard let self, types.indices.contains(index) else { return }
            selectedType = types[index]
            attach(pendingDocuments, as: selectedType)
        }
    }

    private func attach(_ pendingDocuments: [PendingDocument], as type: DocumentType) {
        guard let vehicle = session.selectedVehicle else { return }
        Task {
            do {
                for pending in pendingDocuments {
                    _ = try await AttachDocumentUseCase(repository: repository, storage: storage).execute(
                        data: pending.data,
                        vehicleID: vehicle.id,
                        recordID: nil,
                        type: type,
                        displayName: pending.name,
                        mimeType: pending.mimeType,
                        fileExtension: pending.fileExtension
                    )
                }
                await session.dataChanged()
            } catch {
                await session.dataChanged()
                presentError(error)
            }
        }
    }

    @objc private func reload() {
        thumbnailTasks.values.forEach { $0.cancel() }
        thumbnailTasks.removeAll()
        Task { await viewModel.load() }
    }
}

extension DocumentsViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        visibleDocuments.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let document = visibleDocuments[indexPath.item]
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DocumentGridCell.reuseIdentifier,
            for: indexPath
        ) as? DocumentGridCell else {
            preconditionFailure("DocumentGridCell XIB must be registered")
        }

        let cachedThumbnail = thumbnailCache.object(forKey: document.id as NSUUID)
        cell.configure(
            document: document,
            title: displayTitle(for: document),
            badgeText: viewModel.associationText(for: document),
            metadataText: viewModel.metadataText(for: document),
            thumbnail: cachedThumbnail,
            onOpen: { [weak self] in self?.open(document) },
            onDelete: { [weak self] in self?.requestDelete(document) }
        )
        if cachedThumbnail == nil { loadThumbnail(for: document) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        open(visibleDocuments[indexPath.item])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let numberOfColumns: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
        let totalSpacing = Layout.interItemSpacing * (numberOfColumns - 1)
        let width = floor((collectionView.bounds.width - totalSpacing) / numberOfColumns)
        let height = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 252 : Layout.cardHeight
        return CGSize(width: max(0, width), height: height)
    }
}

extension DocumentsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension DocumentsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            let data = try Data(contentsOf: url)
            let pending = PendingDocument(
                data: data,
                name: url.lastPathComponent,
                mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream",
                fileExtension: url.pathExtension
            )
            controller.dismiss(animated: true) { [weak self] in
                self?.chooseTypeAndAttach([pending])
            }
        } catch {
            controller.dismiss(animated: true) { [weak self] in self?.presentError(GarageError.fileOperation) }
        }
    }
}

extension DocumentsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self)
        else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard error == nil,
                  let data = (image as? UIImage)?.jpegData(compressionQuality: 0.86)
            else { return }
            let pending = PendingDocument(
                data: data,
                name: "Araç Fotoğrafı.jpg",
                mimeType: "image/jpeg",
                fileExtension: "jpg"
            )
            DispatchQueue.main.async {
                self?.attach([pending], as: .vehiclePhoto)
            }
        }
    }
}

extension DocumentsViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        var pendingDocuments: [PendingDocument] = []
        for pageIndex in 0..<scan.pageCount {
            guard let data = scan.imageOfPage(at: pageIndex).jpegData(compressionQuality: 0.86) else { continue }
            pendingDocuments.append(PendingDocument(
                data: data,
                name: "Taranan Belge \(pageIndex + 1).jpg",
                mimeType: "image/jpeg",
                fileExtension: "jpg"
            ))
        }
        controller.dismiss(animated: true) { [weak self] in
            self?.chooseTypeAndAttach(pendingDocuments)
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: Error
    ) {
        controller.dismiss(animated: true) { [weak self] in self?.presentError(error) }
    }
}

private final class DocumentFilterButton: UIButton {
    let filter: DocumentsViewModel.Filter

    init(filter: DocumentsViewModel.Filter) {
        self.filter = filter
        super.init(frame: .zero)
        accessibilityLabel = "\(filter.title) belgeleri"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ isSelected: Bool) {
        configuration = FilterPillStyle.configuration(title: filter.title, isSelected: isSelected)
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

final class DocumentPreviewViewController: UIViewController {
    private let document: GarageDocument
    private let data: Data

    init(document: GarageDocument, data: Data) {
        self.document = document
        self.data = data
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = document.displayName
        view.backgroundColor = AppTheme.backgroundColor
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Kapat",
            style: .done,
            target: self,
            action: #selector(close)
        )
        if document.mimeType == "application/pdf", let pdf = PDFDocument(data: data) {
            let pdfView = PDFView()
            pdfView.document = pdf
            pdfView.autoScales = true
            view.addSubview(pdfView)
            pdfView.pinToEdges(of: view)
        } else {
            let imageView = UIImageView(image: UIImage(data: data))
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = .black
            view.addSubview(imageView)
            imageView.pinToEdges(of: view)
        }
    }

    @objc private func close() { dismiss(animated: true) }
}

extension UIViewController {
    func presentDocumentPreview(document: GarageDocument, data: Data) {
        let preview = DocumentPreviewViewController(document: document, data: data)
        let navigation = UINavigationController(rootViewController: preview)
        navigation.modalPresentationStyle = .pageSheet
        present(navigation, animated: true)
    }
}
