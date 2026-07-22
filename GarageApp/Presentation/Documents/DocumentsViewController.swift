//
//  Created by Doğa Erdemir on 12.07.2026.
//

import PDFKit
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

final class DocumentsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private enum DocumentSource {
        case files, photos, scanner

        var option: SelectionSheetOption {
            switch self {
            case .files: SelectionSheetOption(title: "Dosyalar", subtitle: "PDF veya görsel seçin", symbolName: "folder.fill")
            case .photos: SelectionSheetOption(title: "Fotoğraflar", subtitle: "Fotoğraf arşivinizden seçin", symbolName: "photo.on.rectangle.angled")
            case .scanner: SelectionSheetOption(title: "Kamera ile Tara", subtitle: "Yeni bir belge tarayın", symbolName: "doc.viewfinder.fill")
            }
        }
    }

    var viewModel: DocumentsViewModel!
    var session: AppSession!; var repository: DocumentRepository!; var storage: FileStorageService!
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var selectedType: DocumentType = .other

    override func viewDidLoad() {
        super.viewDidLoad(); navigationItem.title = nil; navigationItem.largeTitleDisplayMode = .never; view.backgroundColor = AppTheme.backgroundColor
        view.subviews.forEach { $0.removeFromSuperview() }; tableView.dataSource = self; tableView.delegate = self
        tableView.register(UINib(nibName: "DataListCell", bundle: .main), forCellReuseIdentifier: "DataListCell")
        AppTheme.styleList(tableView)
        tableView.sectionHeaderTopPadding = 0
        view.addSubview(tableView); tableView.pinToEdges(of: view)
        tableView.tableHeaderView = PageHeaderView(title: "Belgeler", message: "Araç ve işlem belgelerinizi tek yerde yönetin.")
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: DocumentsViewController, _) in
            controller.tableView.updateTableHeaderHeightIfNeeded()
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addDocument))
        viewModel.onChange = { [weak self] in self?.render() }; viewModel.onError = { [weak self] in self?.presentError($0) }
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil); NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .selectedVehicleDidChange, object: nil)
        Task { await viewModel.load() }
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.updateTableHeaderHeightIfNeeded()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { viewModel.documents.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let document = viewModel.documents[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "DataListCell", for: indexPath) as! DataListCell
        cell.configure(
            title: document.displayName,
            subtitle: document.recordID == nil ? "Genel belge" : "İşlem belgesi",
            metadata: [
                "Tür · \(document.documentType.displayName)",
                "Boyut · \(ByteCountFormatter.string(fromByteCount: document.fileSize, countStyle: .file))"
            ],
            symbol: document.mimeType == "application/pdf" ? "doc.richtext.fill" : "photo.fill"
        )
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let document = viewModel.documents[indexPath.row]
        Task { do { let data = try await storage.read(relativePath: document.localRelativePath); presentDocumentPreview(document: document, data: data) } catch { presentError(error) } }
    }
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let document = viewModel.documents[indexPath.row]
        return UISwipeActionsConfiguration(actions: [UIContextualAction(style: .destructive, title: "Sil") { [weak self] _, _, done in
            guard let self else { done(false); return }
            Task {
                do {
                    try await DeleteDocumentUseCase(repository: self.repository, storage: self.storage).execute(documentID: document.id)
                    await self.session.dataChanged()
                    done(true)
                } catch {
                    self.presentError(error)
                    done(false)
                }
            }
        }])
    }

    @objc private func addDocument() {
        guard session.selectedVehicle != nil else { presentError(GarageError.validation("Önce bir araç ekleyin.")); return }
        let types = DocumentType.allCases
        presentSelectionSheet(
            title: "Belge Türü",
            message: "Belgeyi daha sonra kolay bulmak için türünü seçin.",
            options: types.map { SelectionSheetOption(title: $0.displayName, symbolName: $0.symbolName) },
            selectedIndex: types.firstIndex(of: selectedType)
        ) { [weak self] index in
            guard types.indices.contains(index) else { return }
            self?.selectedType = types[index]
            self?.chooseSource()
        }
    }
    private func chooseSource() {
        var sources: [DocumentSource] = [.files, .photos]
        if VNDocumentCameraViewController.isSupported { sources.append(.scanner) }
        presentSelectionSheet(title: "Belge Kaynağı", options: sources.map(\.option)) { [weak self] index in
            guard let self, sources.indices.contains(index) else { return }
            switch sources[index] {
            case .files:
                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)
                picker.delegate = self
                self.present(picker, animated: true)
            case .photos:
                var config = PHPickerConfiguration(photoLibrary: .shared()); config.filter = .images; config.selectionLimit = 1
                let picker = PHPickerViewController(configuration: config); picker.delegate = self; self.present(picker, animated: true)
            case .scanner:
                let scanner = VNDocumentCameraViewController(); scanner.delegate = self; self.present(scanner, animated: true)
            }
        }
    }
    private func attach(data: Data, name: String, mime: String, ext: String) {
        guard let vehicle = session.selectedVehicle else { return }
        Task { do { _ = try await AttachDocumentUseCase(repository: repository, storage: storage).execute(data: data, vehicleID: vehicle.id, recordID: nil, type: selectedType, displayName: name, mimeType: mime, fileExtension: ext); await session.dataChanged() } catch { presentError(error) } }
    }
    private func render() {
        tableView.reloadData()
        let emptyState = EmptyStateView(
            symbol: "doc.text.image.fill",
            title: "Henüz belge yok",
            message: "Fatura, poliçe, muayene belgesi veya araç fotoğrafı ekleyin.",
            actionTitle: "Belge Ekle"
        ) { [weak self] in self?.addDocument() }
        tableView.showEmptyState(emptyState, when: viewModel.documents.isEmpty)
    }
    @objc private func reload() { Task { await viewModel.load() } }
}

extension DocumentsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }; attach(data: data, name: url.lastPathComponent, mime: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream", ext: url.pathExtension) }
}
extension DocumentsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) { picker.dismiss(animated: true); guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }; provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in guard let data = (image as? UIImage)?.jpegData(compressionQuality: 0.86) else { return }; DispatchQueue.main.async { self?.attach(data: data, name: "Belge.jpg", mime: "image/jpeg", ext: "jpg") } } }
}
extension DocumentsViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        for pageIndex in 0..<scan.pageCount {
            guard let data = scan.imageOfPage(at: pageIndex).jpegData(compressionQuality: 0.86) else { continue }
            attach(data: data, name: "Taranan Belge \(pageIndex + 1).jpg", mime: "image/jpeg", ext: "jpg")
        }
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { controller.dismiss(animated: true) }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { controller.dismiss(animated: true); presentError(error) }
}

final class DocumentPreviewViewController: UIViewController {
    private let document: GarageDocument; private let data: Data
    init(document: GarageDocument, data: Data) { self.document = document; self.data = data; super.init(nibName: nil, bundle: nil); modalPresentationStyle = .pageSheet }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); title = document.displayName; view.backgroundColor = AppTheme.backgroundColor
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Kapat", style: .done, target: self, action: #selector(close))
        if document.mimeType == "application/pdf", let pdf = PDFDocument(data: data) { let pdfView = PDFView(); pdfView.document = pdf; pdfView.autoScales = true; view.addSubview(pdfView); pdfView.pinToEdges(of: view) }
        else { let imageView = UIImageView(image: UIImage(data: data)); imageView.contentMode = .scaleAspectFit; imageView.backgroundColor = .black; view.addSubview(imageView); imageView.pinToEdges(of: view) }
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
