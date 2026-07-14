//
//  Created by Doğa Erdemir on 12.07.2026.
//

import UIKit

@MainActor
final class AppCoordinator: BaseCoordinator {
    private let window: UIWindow; private let container: DependencyContainer
    private weak var tabBarController: UITabBarController?

    init(window: UIWindow, container: DependencyContainer) { self.window = window; self.container = container }

    override func start() {
        AppTheme.apply(); let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let tabs = storyboard.instantiateInitialViewController() as? UITabBarController else { preconditionFailure("Main.storyboard must start with a UITabBarController") }
        configureNavigation(in: tabs)
        tabBarController = tabs; injectDependencies(in: tabs); window.rootViewController = tabs; window.tintColor = AppTheme.accentColor; window.makeKeyAndVisible()
        Task {
            do {
                try await container.session.reload()
                let bypassOnboarding = ProcessInfo.processInfo.arguments.contains("-uiTesting")
                if container.session.vehicles.isEmpty && !bypassOnboarding { showOnboarding() }
            } catch { tabs.presentError(error) }
        }
    }

    private func configureNavigation(in tabs: UITabBarController) {
        tabs.viewControllers?.compactMap { $0 as? UINavigationController }.forEach { navigation in
            guard let root = navigation.viewControllers.first else { return }
            navigation.navigationBar.prefersLargeTitles = false
            root.navigationItem.largeTitleDisplayMode = .never
            root.navigationItem.title = nil
        }
        let symbols = [("house", "house.fill"), ("clock", "clock.fill"), ("doc", "doc.fill"), ("chart.bar", "chart.bar.fill")]
        tabs.tabBar.items?.enumerated().forEach { index, item in
            guard symbols.indices.contains(index) else { return }
            item.image = UIImage(systemName: symbols[index].0)
            item.selectedImage = UIImage(systemName: symbols[index].1)
        }
    }

    private func injectDependencies(in tabs: UITabBarController) {
        let roots = tabs.viewControllers?.compactMap { ($0 as? UINavigationController)?.viewControllers.first } ?? []
        for root in roots {
            switch root {
            case let controller as HomeViewController:
                controller.viewModel = container.makeHomeViewModel()
                controller.onSettings = { [weak self, weak controller] in guard let self, let controller else { return }; self.showSettings(from: controller) }
                controller.onChooseVehicle = { [weak self, weak controller] in guard let self, let controller else { return }; self.showVehicles(from: controller) }
                controller.onAddRecord = { [weak self, weak controller] type in guard let self, let controller else { return }; self.showRecordEditor(type: type, from: controller) }
                controller.onUpdateMileage = { [weak self, weak controller] in guard let self, let controller else { return }; self.showRecordEditor(type: .mileage, from: controller) }
                controller.onReminders = { [weak self, weak controller] in guard let self, let controller else { return }; self.showReminders(from: controller) }
                controller.onRecord = { [weak self, weak controller] record in guard let self, let controller else { return }; self.showRecordDetail(record, from: controller) }
            case let controller as TimelineViewController:
                controller.viewModel = container.makeTimelineViewModel()
                controller.onAdd = { [weak self, weak controller] in guard let self, let controller else { return }; self.chooseRecordType(from: controller) }
                controller.onRecord = { [weak self, weak controller] record in guard let self, let controller else { return }; self.showRecordDetail(record, from: controller) }
            case let controller as DocumentsViewController:
                controller.viewModel = container.makeDocumentsViewModel(); controller.session = container.session; controller.repository = container.documentRepository; controller.storage = container.fileStorageService
            case let controller as InsightsViewController: controller.viewModel = container.makeInsightsViewModel()
            default: break
            }
        }
    }

    private func showOnboarding() {
        guard tabBarController?.presentedViewController == nil else { return }
        let onboarding = OnboardingViewController(); onboarding.modalPresentationStyle = .fullScreen
        onboarding.onAddFirstVehicle = { [weak self, weak onboarding] in guard let self, let onboarding else { return }; self.showVehicleEditor(vehicle: nil, from: onboarding, firstVehicle: true) }
        tabBarController?.present(onboarding, animated: true)
    }

    private func showVehicleEditor(vehicle: Vehicle?, from presenter: UIViewController, firstVehicle: Bool = false) {
        let editor = VehicleEditorViewController(vehicle: vehicle, repository: container.vehicleRepository, storage: container.fileStorageService)
        editor.navigationItem.largeTitleDisplayMode = .never
        let navigation = UINavigationController(rootViewController: editor); navigation.modalPresentationStyle = .formSheet
        editor.onSaved = { [weak self, weak navigation, weak presenter] saved in
            guard let self else { return }; Task { await self.container.session.dataChanged(); if !saved.isArchived { self.container.session.select(saved) }; navigation?.dismiss(animated: true) { if firstVehicle { presenter?.dismiss(animated: true) } } }
        }
        presenter.present(navigation, animated: true)
    }

    private func showVehicles(from presenter: UIViewController) {
        let list = VehicleListViewController(session: container.session, repository: container.vehicleRepository)
        list.navigationItem.largeTitleDisplayMode = .never
        list.onAdd = { [weak self, weak list] in guard let self, let list else { return }; self.showVehicleEditor(vehicle: nil, from: list) }
        list.onEdit = { [weak self, weak list] vehicle in guard let self, let list else { return }; self.showVehicleEditor(vehicle: vehicle, from: list) }
        list.onSelected = { [weak self, weak list] vehicle in self?.container.session.select(vehicle); list?.navigationController?.popViewController(animated: true) }
        list.onDelete = { [weak self, weak list] vehicle in
            list?.confirm(title: "Aracı Sil", message: "\(vehicle.nickname) ve tüm kayıtları, belgeleri ve hatırlatmaları kalıcı olarak silinecek.", destructiveTitle: "Sil") {
                Task { do { try await self?.deleteVehicle(vehicle) } catch { list?.presentError(error) } }
            }
        }
        list.onArchive = { [weak self, weak list] vehicle in
            var archived = vehicle; archived.isArchived.toggle(); archived.updatedAt = .now
            Task { do { try await self?.container.vehicleRepository.save(archived); await self?.container.session.dataChanged() } catch { list?.presentError(error) } }
        }
        presenter.navigationController?.pushViewController(list, animated: true)
    }

    private func deleteVehicle(_ vehicle: Vehicle) async throws {
        try await DeleteVehicleUseCase(repository: container.vehicleRepository, documentRepository: container.documentRepository, reminderRepository: container.reminderRepository, storage: container.fileStorageService, notificationService: container.notificationService).execute(vehicleID: vehicle.id)
        await container.session.dataChanged(); if container.session.vehicles.isEmpty { showOnboarding() }
    }

    private func showSettings(from presenter: UIViewController) {
        let settings = SettingsViewController(session: container.session, notificationService: container.notificationService)
        settings.navigationItem.largeTitleDisplayMode = .never
        settings.onVehicles = { [weak self, weak settings] in guard let self, let settings else { return }; self.showVehicles(from: settings) }
        settings.onDeleteSelectedVehicle = { [weak self, weak settings] in
            guard let self, let settings, let vehicle = container.session.selectedVehicle else { return }
            settings.confirm(title: "Aracı ve Verilerini Sil", message: "Bu işlem geri alınamaz.", destructiveTitle: "Kalıcı Olarak Sil") { Task { do { try await self.deleteVehicle(vehicle); settings.navigationController?.popToRootViewController(animated: true) } catch { settings.presentError(error) } } }
        }
        presenter.navigationController?.pushViewController(settings, animated: true)
    }

    private func chooseRecordType(from presenter: UIViewController) {
        guard container.session.selectedVehicle != nil else { presenter.presentError(GarageError.validation("Önce bir araç ekleyin.")); return }
        let types = RecordType.timelineTypes
        presenter.presentSelectionSheet(
            title: "Kayıt Türü",
            message: "Aracınıza eklemek istediğiniz işlem türünü seçin.",
            options: types.map { SelectionSheetOption(title: $0.displayName, symbolName: $0.symbolName) }
        ) { [weak self, weak presenter] index in
            guard let self, let presenter, types.indices.contains(index) else { return }
            self.showRecordEditor(type: types[index], from: presenter)
        }
    }

    private func showRecordEditor(type: RecordType, existing: VehicleRecord? = nil, from presenter: UIViewController) {
        guard let vehicle = container.session.selectedVehicle else { presenter.presentError(GarageError.validation("Önce bir araç ekleyin.")); return }
        guard existing?.vehicleID == nil || existing?.vehicleID == vehicle.id else {
            presenter.presentError(GarageError.validation("Bu kayıt başka bir araca ait. Düzenlemek için ilgili aracı seçin."))
            return
        }
        let editor = RecordEditorViewController(vehicle: vehicle, type: type, existing: existing, recordRepository: container.recordRepository, vehicleRepository: container.vehicleRepository, reminderRepository: container.reminderRepository, documentRepository: container.documentRepository, storage: container.fileStorageService, notificationService: container.notificationService)
        editor.navigationItem.largeTitleDisplayMode = .never
        let navigation = UINavigationController(rootViewController: editor); navigation.modalPresentationStyle = .formSheet
        editor.onSaved = { [weak self, weak navigation] _ in guard let self else { return }; Task { await self.container.session.dataChanged(); navigation?.dismiss(animated: true) } }
        presenter.present(navigation, animated: true)
    }

    private func showRecordDetail(_ record: VehicleRecord, from presenter: UIViewController) {
        let viewModel = RecordDetailViewModel(record: record, recordRepository: container.recordRepository, documentRepository: container.documentRepository)
        let detail = RecordDetailViewController(viewModel: viewModel)
        detail.onEdit = { [weak self, weak detail] currentRecord in
            guard let self, let detail else { return }
            self.showRecordEditor(type: currentRecord.recordType, existing: currentRecord, from: detail)
        }
        detail.onDocument = { [weak self, weak detail] document in
            guard let self else { return }
            Task {
                do {
                    let data = try await self.container.fileStorageService.read(relativePath: document.localRelativePath)
                    detail?.presentDocumentPreview(document: document, data: data)
                } catch {
                    detail?.presentError(error)
                }
            }
        }
        detail.onDelete = { [weak self, weak detail] in
            detail?.confirm(title: "Kaydı Sil", message: "Kayıt ve ilişkili belgeler kalıcı olarak silinecek.", destructiveTitle: "Sil") {
                guard let self else { return }
                Task {
                    do {
                        try await DeleteRecordUseCase(repository: self.container.recordRepository, documentRepository: self.container.documentRepository, storage: self.container.fileStorageService).execute(recordID: record.id, vehicleID: record.vehicleID)
                        detail?.stopObservingChanges()
                        detail?.navigationController?.popViewController(animated: true)
                        await self.container.session.dataChanged()
                    } catch {
                        detail?.presentError(error)
                    }
                }
            }
        }
        presenter.navigationController?.pushViewController(detail, animated: true)
    }

    private func showReminders(from presenter: UIViewController) {
        let list = ReminderListViewController(session: container.session, repository: container.reminderRepository)
        list.navigationItem.largeTitleDisplayMode = .never
        list.onAdd = { [weak self, weak list] in
            guard let self, let list, let vehicle = container.session.selectedVehicle else { return }
            let editor = ReminderEditorViewController(vehicle: vehicle, repository: container.reminderRepository, notifications: container.notificationService); let nav = UINavigationController(rootViewController: editor)
            editor.navigationItem.largeTitleDisplayMode = .never
            editor.onSaved = { [weak nav, weak list] in nav?.dismiss(animated: true); list?.reload() }; list.present(nav, animated: true)
        }
        presenter.navigationController?.pushViewController(list, animated: true)
    }
}
