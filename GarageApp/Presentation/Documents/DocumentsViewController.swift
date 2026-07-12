//
//  Created by Doğa Erdemir on 12.07.2026.
//

import PDFKit
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

final class DocumentsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var viewModel: DocumentsViewModel!
    var session: AppSession!; var repository: DocumentRepository!; var storage: FileStorageService!
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var selectedType: DocumentType = .other

    override func viewDidLoad() {
        super.viewDidLoad(); title = "Belgeler"; view.backgroundColor = UIColor(named: "AppBackground")
        view.subviews.forEach { $0.removeFromSuperview() }; tableView.dataSource = self; tableView.delegate = self; tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Document"); view.addSubview(tableView); tableView.pinToEdges(of: view)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addDocument))
        viewModel.onChange = { [weak self] in self?.tableView.reloadData() }; viewModel.onError = { [weak self] in self?.presentError($0) }
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .garageDataDidChange, object: nil); NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .selectedVehicleDidChange, object: nil)
        Task { await viewModel.load() }
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { viewModel.documents.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let document = viewModel.documents[indexPath.row]; let cell = tableView.dequeueReusableCell(withIdentifier: "Document", for: indexPath); var content = cell.defaultContentConfiguration(); content.text = document.displayName; content.secondaryText = "\(document.documentType.displayName) • \(ByteCountFormatter.string(fromByteCount: document.fileSize, countStyle: .file))"; content.image = UIImage(systemName: document.mimeType == "application/pdf" ? "doc.richtext.fill" : "photo.fill"); content.imageProperties.tintColor = UIColor(named: "AppAccent"); cell.contentConfiguration = content; cell.accessoryType = .disclosureIndicator; return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let document = viewModel.documents[indexPath.row]; Task { do { let data = try await storage.read(relativePath: document.localRelativePath); present(DocumentPreviewViewController(document: document, data: data), animated: true) } catch { presentError(error) } }
    }
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let document = viewModel.documents[indexPath.row]; return UISwipeActionsConfiguration(actions: [UIContextualAction(style: .destructive, title: "Sil") { [weak self] _, _, done in Task { do { try await self?.storage.delete(relativePath: document.localRelativePath); try await self?.repository.delete(id: document.id); await self?.session.dataChanged() } catch { if let self { self.presentError(error) } } }; done(true) }])
    }

    @objc private func addDocument() {
        guard session.selectedVehicle != nil else { presentError(GarageError.validation("Önce bir araç ekleyin.")); return }
        let typeAlert = UIAlertController(title: "Belge Türü", message: nil, preferredStyle: .actionSheet)
        DocumentType.allCases.forEach { type in typeAlert.addAction(UIAlertAction(title: type.displayName, style: .default) { _ in self.selectedType = type; self.chooseSource() }) }
        typeAlert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel)); present(typeAlert, animated: true)
    }
    private func chooseSource() {
        let alert = UIAlertController(title: "Belge Kaynağı", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Dosyalar", style: .default) { _ in let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true); picker.delegate = self; self.present(picker, animated: true) })
        alert.addAction(UIAlertAction(title: "Fotoğraflar", style: .default) { _ in var config = PHPickerConfiguration(photoLibrary: .shared()); config.filter = .images; config.selectionLimit = 1; let picker = PHPickerViewController(configuration: config); picker.delegate = self; self.present(picker, animated: true) })
        if VNDocumentCameraViewController.isSupported { alert.addAction(UIAlertAction(title: "Kamera ile Tara", style: .default) { _ in let scanner = VNDocumentCameraViewController(); scanner.delegate = self; self.present(scanner, animated: true) }) }
        alert.addAction(UIAlertAction(title: "Vazgeç", style: .cancel)); present(alert, animated: true)
    }
    private func attach(data: Data, name: String, mime: String, ext: String) {
        guard let vehicle = session.selectedVehicle else { return }
        Task { do { _ = try await AttachDocumentUseCase(repository: repository, storage: storage).execute(data: data, vehicleID: vehicle.id, recordID: nil, type: selectedType, displayName: name, mimeType: mime, fileExtension: ext); await session.dataChanged() } catch { presentError(error) } }
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
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) { controller.dismiss(animated: true); guard scan.pageCount > 0, let data = scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.86) else { return }; attach(data: data, name: "Taranan Belge.jpg", mime: "image/jpeg", ext: "jpg") }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { controller.dismiss(animated: true) }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { controller.dismiss(animated: true); presentError(error) }
}

final class DocumentPreviewViewController: UIViewController {
    private let document: GarageDocument; private let data: Data
    init(document: GarageDocument, data: Data) { self.document = document; self.data = data; super.init(nibName: nil, bundle: nil); modalPresentationStyle = .pageSheet }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        if document.mimeType == "application/pdf", let pdf = PDFDocument(data: data) { let pdfView = PDFView(); pdfView.document = pdf; pdfView.autoScales = true; view.addSubview(pdfView); pdfView.pinToEdges(of: view) }
        else { let imageView = UIImageView(image: UIImage(data: data)); imageView.contentMode = .scaleAspectFit; imageView.backgroundColor = .black; view.addSubview(imageView); imageView.pinToEdges(of: view) }
    }
}
