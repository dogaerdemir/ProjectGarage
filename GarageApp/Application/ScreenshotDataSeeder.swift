#if DEBUG

import UIKit

@MainActor
enum ScreenshotDataSeeder {
    private static let vehicleID = UUID(
        uuidString: "B1A0E8D4-2C4E-4B22-A2C9-010000000001"
    )!

    static func seed(container: DependencyContainer) async throws {
        guard try await container.vehicleRepository.vehicle(id: vehicleID) == nil else {
            return
        }

        let now = Date.now
        let vehicle = Vehicle(
            id: vehicleID,
            nickname: "Günlük Aracım",
            make: "Toyota",
            model: "Corolla",
            modelYear: 2022,
            fuelType: .gasoline,
            transmissionType: .automatic,
            plateNumber: "34 OTO 2026",
            currentMileage: 48_650,
            catalogMakeID: "toyota",
            catalogModelID: "toyota-corolla",
            createdAt: date(byAddingMonths: -18, to: now),
            updatedAt: now
        )
        try await container.vehicleRepository.save(vehicle)

        let records = makeRecords(now: now)
        for record in records {
            try await container.recordRepository.save(record, lineItems: [])
        }

        let reminders = [
            Reminder(
                id: fixedUUID(suffix: 201),
                vehicleID: vehicleID,
                title: "Periyodik bakım",
                dueDate: date(byAddingDays: 21, to: now),
                dueMileage: 50_000,
                status: .approaching,
                createdAt: now,
                updatedAt: now
            ),
            Reminder(
                id: fixedUUID(suffix: 202),
                vehicleID: vehicleID,
                title: "Trafik sigortasını yenile",
                dueDate: date(byAddingDays: 74, to: now),
                status: .active,
                createdAt: now,
                updatedAt: now
            ),
            Reminder(
                id: fixedUUID(suffix: 203),
                vehicleID: vehicleID,
                title: "Lastik basınçlarını kontrol et",
                dueDate: date(byAddingDays: 7, to: now),
                status: .approaching,
                createdAt: now,
                updatedAt: now
            )
        ]
        for reminder in reminders {
            try await container.reminderRepository.save(reminder)
        }

        try await seedDocuments(
            container: container,
            records: records,
            now: now
        )
        await container.session.dataChanged()
    }

    private static func makeRecords(now: Date) -> [VehicleRecord] {
        let definitions: [
            (
                Int,
                RecordType,
                String,
                Int,
                Int64?,
                Decimal?,
                String?,
                Decimal?,
                Decimal?
            )
        ] = [
            (101, .fuel, "Yakıt Alımı", -1, 48_520, 2_315, "Shell", 41.2, 56.19),
            (102, .maintenance, "Periyodik Bakım", -12, 47_980, 7_850, "Yetkili Servis", nil, nil),
            (103, .expense, "Otopark Aboneliği", -34, nil, 1_250, "İSPARK", nil, nil),
            (104, .fuel, "Yakıt Alımı", -48, 46_730, 2_180, "Petrol Ofisi", 40.1, 54.36),
            (105, .insurance, "Trafik Sigortası", -82, nil, 8_550, "Anadolu Sigorta", nil, nil),
            (106, .fuel, "Yakıt Alımı", -116, 44_860, 2_040, "Opet", 39.4, 51.78),
            (107, .inspection, "Araç Muayenesi", -154, 43_240, 1_821, "TÜVTÜRK", nil, nil),
            (108, .maintenance, "Kış Lastiği Değişimi", -211, 41_900, 3_600, "Lastik Servisi", nil, nil),
            (109, .fuel, "Yakıt Alımı", -245, 41_160, 1_890, "TotalEnergies", 38.2, 49.48),
            (110, .expense, "HGS Yüklemesi", -288, nil, 1_000, "HGS", nil, nil),
            (111, .maintenance, "Klima Bakımı", -327, 39_720, 2_450, "Özel Servis", nil, nil),
            (112, .mileage, "Kilometre Güncellemesi", -355, 38_900, nil, nil, nil, nil),
            (113, .mileage, "Kilometre Güncellemesi", -2, 48_650, nil, nil, nil, nil)
        ]

        return definitions.map { definition in
            VehicleRecord(
                id: fixedUUID(suffix: definition.0),
                vehicleID: vehicleID,
                recordType: definition.1,
                title: definition.2,
                eventDate: date(byAddingDays: definition.3, to: now),
                odometer: definition.4,
                totalAmount: definition.5,
                vendorName: definition.6,
                notes: "OtoHafıza örnek ekran görüntüsü verisi",
                liters: definition.7,
                unitPrice: definition.8,
                isFullTank: definition.1 == .fuel ? true : nil,
                createdAt: date(byAddingDays: definition.3, to: now),
                updatedAt: now
            )
        }
    }

    private static func seedDocuments(
        container: DependencyContainer,
        records: [VehicleRecord],
        now: Date
    ) async throws {
        let definitions: [
            (String, DocumentType, UIColor, UUID?, Int)
        ] = [
            ("Servis Faturası", .serviceInvoice, .systemBlue, fixedUUID(suffix: 102), 301),
            ("Yakıt Fişi", .fuelReceipt, .systemOrange, fixedUUID(suffix: 101), 302),
            ("Trafik Sigortası", .insurancePolicy, .systemTeal, fixedUUID(suffix: 105), 303),
            ("Muayene Belgesi", .inspectionDocument, .systemIndigo, fixedUUID(suffix: 107), 304)
        ]
        let recordIDs = Set(records.map(\.id))

        for definition in definitions {
            let associatedRecordID = definition.3.flatMap {
                recordIDs.contains($0) ? $0 : nil
            }
            let data = makeDocumentImage(
                title: definition.0,
                accentColor: definition.2
            )
            let path = try await container.fileStorageService.save(
                data: data,
                vehicleID: vehicleID,
                recordID: associatedRecordID,
                fileExtension: "png"
            )
            let document = GarageDocument(
                id: fixedUUID(suffix: definition.4),
                vehicleID: vehicleID,
                recordID: associatedRecordID,
                documentType: definition.1,
                displayName: "\(definition.0).png",
                mimeType: "image/png",
                fileSize: Int64(data.count),
                localRelativePath: path,
                createdAt: now
            )
            try await container.documentRepository.save(document)
        }
    }

    private static func makeDocumentImage(
        title: String,
        accentColor: UIColor
    ) -> Data {
        let size = CGSize(width: 900, height: 1_200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            accentColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: 190))

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 54, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            title.draw(
                in: CGRect(x: 62, y: 62, width: 776, height: 80),
                withAttributes: titleAttributes
            )

            let lineColor = UIColor.secondaryLabel.withAlphaComponent(0.18)
            lineColor.setFill()
            for index in 0..<8 {
                let width = index.isMultiple(of: 3) ? 650.0 : 760.0
                context.fill(
                    CGRect(
                        x: 70,
                        y: 270 + CGFloat(index) * 92,
                        width: width,
                        height: 20
                    )
                )
            }

            accentColor.withAlphaComponent(0.14).setFill()
            context.fill(CGRect(x: 70, y: 1_050, width: 760, height: 72))
        }
        return image.pngData() ?? Data()
    }

    private static func date(byAddingDays days: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    private static func date(byAddingMonths months: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: date) ?? date
    }

    private static func fixedUUID(suffix: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "B1A0E8D4-2C4E-4B22-A2C9-%012d",
                suffix
            )
        )!
    }
}

#endif
