//
//  BackupInteractor.swift
//  SmartReceipts
//
//  Created by Bogdan Evsenev on 14/02/2018.
//Copyright © 2018 Will Baumann. All rights reserved.
//

import Foundation
import Viperit
import RxSwift
import Toaster

class BackupInteractor: Interactor {
    let bag = DisposeBag()
    
    var backupManager: BackupProvidersManager!
    let purchaseService = PurchaseService()
    
    required init() {
        backupManager = BackupProvidersManager(syncProvider: .current)
    }
    
    func isCurrentDevice(backup: RemoteBackupMetadata) -> Bool {
        return backup.syncDeviceId == backupManager.deviceSyncId
    }
    
    func hasValidSubscription() -> Bool {
        return purchaseService.hasValidSubscriptionValue()
    }
    
    func downloadZip(_ backup: RemoteBackupMetadata) {
        weak var hud = PendingHUDView.showFullScreen()
        backupManager.downloadAllData(remoteBackupMetadata: backup)
            .map({ result -> URL? in
                if !result.database.open() { return nil }
                let tempDirPath = NSTemporaryDirectory()
                let database = result.database
                let trips = database.allTrips() as! [WBTrip]
                
                var urls = [URL]()
                
                for file in result.files {
                    for trip in trips {
                        let receipts = database.allReceipts(for: trip) as! [WBReceipt]
                        if !receipts.filter({ $0.imageFilePath(for: trip).contains(file.filename) }).isEmpty {
                            let tripPath = tempDirPath.asNSString.appendingPathComponent(trip.name)
                            _ = FileManager.createDirectiryIfNotExists(path: tripPath)
                            let receiptPath = tripPath.asNSString.appendingPathComponent(file.filename)
                            FileManager.default.createFile(atPath: receiptPath, contents: file.data, attributes: nil)
                            urls.append(tripPath.asFileURL)
                        }
                    }
                }
                
                let backupPath = tempDirPath.asNSString.appendingPathComponent("\(backup.syncDeviceName).zip")
                try? DataExport.zipFiles(urls, to: backupPath)
                for url in urls { try? FileManager.default.removeItem(at: url) }
                
                database.close()
                return backupPath.asFileURL
            }).do(onSuccess: { _ in
                hud?.hide()
            }).filter({ $0 != nil })
            .subscribe(onSuccess: { [weak self] url in
                self?.presenter.presentOptions(file: url!)
            }, onError: { [weak self] _ in
                hud?.hide()
                self?.presenter.presentAlert(title: nil, message: LocalizedString("EXPORT_ERROR"))
            }).disposed(by: bag)
    }
    
    func downloadDebugZip(_ backup: RemoteBackupMetadata) {
        weak var hud = PendingHUDView.showFullScreen()
        backupManager.debugDownloadAllData(remoteBackupMetadata: backup)
            .map({ result -> URL? in
                let tempDirPath = NSTemporaryDirectory()
                var urls = [URL]()
                urls.append(try! result.database.pathToDatabase.asURL())
                
                for file in result.files {
                    let receiptPath = tempDirPath.asNSString.appendingPathComponent(file.filename)
                    FileManager.default.createFile(atPath: receiptPath, contents: file.data, attributes: nil)
                    urls.append(receiptPath.asFileURL)
                }
                
                let backupPath = tempDirPath.asNSString.appendingPathComponent("debug_\(backup.syncDeviceName).zip")
                try? DataExport.zipFiles(urls, to: backupPath)
                for url in urls { try? FileManager.default.removeItem(at: url) }
                
                return backupPath.asFileURL
            }).do(onSuccess: { _ in
                hud?.hide()
            }).filter({ $0 != nil })
            .subscribe(onSuccess: { [weak self] url in
                self?.presenter.presentOptions(file: url!)
            }, onError: { [weak self] _ in
                hud?.hide()
                self?.presenter.presentAlert(title: nil, message: LocalizedString("EXPORT_ERROR"))
            }).disposed(by: bag)
    }
    
    func importBackup(_ backup: RemoteBackupMetadata, overwrite: Bool) {
        weak var hud = PendingHUDView.showFullScreen()
        backupManager.downloadDatabase(remoteBackupMetadata: backup)
            .map({ database -> [WBReceipt] in
                let path = NSTemporaryDirectory().asNSString.appendingPathComponent(SYNC_DB_NAME)
                Database.sharedInstance().importData(fromBackup: path, overwrite: overwrite)
                if !database.open() { return [] }
                let trips = database.allTrips() as! [WBTrip]
                var result = [WBReceipt]()
                for trip in trips {
                    let receipts = database.allReceipts(for: trip) as! [WBReceipt]
                    result.append(contentsOf: receipts.filter({ !$0.syncId.isEmpty }))
                }
                database.close()
                return result
            }).map({ receipts -> [Observable<(WBReceipt, BackupReceiptFile)>] in
                return receipts.map({ [unowned self] receipt in
                    return self.backupManager.downloadReceiptFile(syncId: receipt.syncId)
                        .asObservable()
                        .map({ (receipt, $0) })
                })
            }).flatMap({ observables -> Single<Void> in
                return Observable<(WBReceipt, BackupReceiptFile)>.merge(observables)
                    .map({ downloaded -> Void in
                        let receipt = downloaded.0
                        let file = downloaded.1
                        
                        let path = receipt.imageFilePath(for: receipt.trip)
                        let folder = path.asNSString.deletingLastPathComponent
                        let fm = FileManager.default
                        if !fm.fileExists(atPath: folder) {
                            try? fm.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
                        }
                        fm.createFile(atPath: path, contents: file.data, attributes: nil)
                    }).toArray().asVoid().asSingle()
            }).asCompletable()
            .subscribe(onCompleted: {
                hud?.hide()
                Toast.show(LocalizedString("toast_import_complete"))
            }, onError: { [weak self] _ in
                hud?.hide()
                self?.presenter.presentAlert(title: nil, message: LocalizedString("IMPORT_ERROR"))
            }).disposed(by: bag)
    }
    
    func deleteBackup(_ backup: RemoteBackupMetadata) {
        weak var hud = PendingHUDView.showFullScreen()
        backupManager.deleteBackup(remoteBackupMetadata: backup)
            .andThen(backupManager.clearCurrentBackupConfiguration())
            .subscribe(onCompleted: { [weak self] in
                Database.sharedInstance().markAllReceiptsSynced(false)
                self?.presenter.updateBackups()
                hud?.hide()
                Toast.show(LocalizedString("dialog_remote_backup_delete_toast_success"))
            }, onError: { [weak self] error in
                hud?.hide()
                self?.presenter.presentAlert(title: nil, message: LocalizedString("dialog_remote_backup_delete_toast_failure"))
            }).disposed(by: bag)
    }
    
    func getBackups() -> Single<[RemoteBackupMetadata]> {
        return backupManager?.getRemoteBackups() ?? Single<[RemoteBackupMetadata]>.just([])
    }
    
    func purchaseSubscription() -> Observable<Void> {
        return purchaseService.purchaseSubscription().asVoid()
    }
    
    func saveCurrent(provider: SyncProvider) {
        if provider == .googleDrive {
            weak var hud = PendingHUDView.showFullScreen()
            GoogleDriveService.shared.signIn(onUI: presenter.signInUIDelegate())
                .subscribe(onNext: { [weak self] in
                    self?.setup(provider: .googleDrive)
                    hud?.hide()
                }, onError: { [weak self] error in
                    self?.setup(provider: .none)
                    hud?.hide()
                }).disposed(by: bag)
        } else {
            setup(provider: provider)
        }
    }
    
    func setupUseWifiOnly(enabled: Bool) {
        WBPreferences.setAutobackupWifiOnly(enabled)
    }
    
    private func setup(provider: SyncProvider) {
        backupManager = BackupProvidersManager(syncProvider: provider)
        SyncProvider.current = provider
        presenter.updateUI()
        presenter.updateBackups()
    }
    
}

// MARK: - VIPER COMPONENTS API (Auto-generated code)
private extension BackupInteractor {
    var presenter: BackupPresenter {
        return _presenter as! BackupPresenter
    }
}
