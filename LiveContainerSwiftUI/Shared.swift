//
//  Shared.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/22.
//

import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication
import SafariServices
import Security

struct LCPath {
    public static let docPath = {
        let fm = FileManager()
        return fm.urls(for: .documentDirectory, in: .userDomainMask).last!
    }()
    public static let bundlePath = docPath.appendingPathComponent("Applications")
    public static let dataPath = docPath.appendingPathComponent("Data/Application")
    public static let appGroupPath = docPath.appendingPathComponent("Data/AppGroup")
    public static let tweakPath = docPath.appendingPathComponent("Tweaks")
    
    public static let lcGroupDocPath = {
        let fm = FileManager()
        // it seems that Apple don't want to create one for us, so we just borrow our Store's
        if let appGroupPathUrl = LCUtils.appGroupPath() {
            return appGroupPathUrl.appendingPathComponent("LiveContainer")
        } else if let appGroupPathUrl =
                    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.SideStore.SideStore") {
            return appGroupPathUrl.appendingPathComponent("LiveContainer")
        } else {
            return docPath
        }
    }()
    public static let lcGroupBundlePath = lcGroupDocPath.appendingPathComponent("Applications")
    public static let lcGroupDataPath = lcGroupDocPath.appendingPathComponent("Data/Application")
    public static let lcGroupAppGroupPath = lcGroupDocPath.appendingPathComponent("Data/AppGroup")
    public static let lcGroupTweakPath = lcGroupDocPath.appendingPathComponent("Tweaks")
    
    public static func ensureAppGroupPaths() throws {
        let fm = FileManager()
        if !fm.fileExists(atPath: LCPath.lcGroupBundlePath.path) {
            try fm.createDirectory(at: LCPath.lcGroupBundlePath, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: LCPath.lcGroupDataPath.path) {
            try fm.createDirectory(at: LCPath.lcGroupDataPath, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: LCPath.lcGroupTweakPath.path) {
            try fm.createDirectory(at: LCPath.lcGroupTweakPath, withIntermediateDirectories: true)
        }
    }
}

class SharedModel: ObservableObject {
    @Published var isHiddenAppUnlocked = false
    @Published var developerMode = false
    // 0= not installed, 1= is installed, 2=current liveContainer is the second one
    @Published var multiLCStatus = 0
    
    @Published var apps : [LCAppModel] = []
    @Published var hiddenApps : [LCAppModel] = []
    let isPhone: Bool = {
        UIDevice.current.userInterfaceIdiom == .phone
    }()
    
    func updateMultiLCStatus() {
        if LCUtils.appUrlScheme()?.lowercased() != "livecontainer" {
            multiLCStatus = 2
        } else if UIApplication.shared.canOpenURL(URL(string: "livecontainer2://")!) {
            multiLCStatus = 1
        } else {
            multiLCStatus = 0
        }
    }
    
    init() {
        updateMultiLCStatus()
    }
}

class DataManager {
    static let shared = DataManager()
    let model = SharedModel()
}

class AlertHelper<T> : ObservableObject {
    @Published var show = false
    private var result : T?
    private var c : CheckedContinuation<Void, Never>? = nil
    
    func open() async -> T? {
        await withCheckedContinuation { c in
            self.c = c
            DispatchQueue.main.async {
                self.show = true
            }
        }
        return self.result
    }
    
    func close(result: T?) {
        self.result = result
        c?.resume()
    }
}

typealias YesNoHelper = AlertHelper<Bool>

class InputHelper : AlertHelper<String> {
    @Published var initVal = ""
    
    func open(initVal: String) async -> String? {
        self.initVal = initVal
        return await super.open()
    }
    
    override func open() async -> String? {
        self.initVal = ""
        return await super.open()
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
        
    private static var enBundle : Bundle? = {
        let language = "en"
        let path = Bundle.main.path(forResource:language, ofType: "lproj")
        let bundle = Bundle(path: path!)
        return bundle
    }()
    
    var loc: String {
        let message = NSLocalizedString(self, comment: "")
        if message != self {
            return message
        }

        if let forcedString = String.enBundle?.localizedString(forKey: self, value: nil, table: nil){
            return forcedString
        }else {
            return self
        }
    }
    
    func localizeWithFormat(_ arguments: CVarArg...) -> String{
        String.localizedStringWithFormat(self.loc, arguments)
    }
    
}



extension UTType {
    static let ipa = UTType(filenameExtension: "ipa")!
    static let dylib = UTType(filenameExtension: "dylib")!
    static let deb = UTType(filenameExtension: "deb")!
    static let lcFramework = UTType(filenameExtension: "framework", conformingTo: .package)!
}

struct SafariView: UIViewControllerRepresentable {
    let url: Binding<URL>
    func makeUIViewController(context: UIViewControllerRepresentableContext<Self>) -> SFSafariViewController {
        return SFSafariViewController(url: url.wrappedValue)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        
    }
}

// https://stackoverflow.com/questions/56726663/how-to-add-a-textfield-to-alert-in-swiftui
extension View {

    public func textFieldAlert(
        isPresented: Binding<Bool>,
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        action: @escaping (String?) -> Void,
        actionCancel: @escaping (String?) -> Void
    ) -> some View {
        self.modifier(TextFieldAlertModifier(isPresented: isPresented, title: title, text: text, placeholder: placeholder, action: action, actionCancel: actionCancel))
    }
    
    public func betterFileImporter(
        isPresented: Binding<Bool>,
        types : [UTType],
        multiple : Bool = false,
        callback: @escaping ([URL]) -> (),
        onDismiss: @escaping () -> Void
    ) -> some View {
        self.modifier(DocModifier(isPresented: isPresented, types: types, multiple: multiple, callback: callback, onDismiss: onDismiss))
    }
    
    func onBackground(_ f: @escaping () -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification),
            perform: { _ in f() }
        )
    }
    
    func onForeground(_ f: @escaping () -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification),
            perform: { _ in f() }
        )
    }
    
}

public struct DocModifier: ViewModifier {

    @State private var docController: UIDocumentPickerViewController?
    @State private var delegate : UIDocumentPickerDelegate
    
    @Binding var isPresented: Bool

    var callback: ([URL]) -> ()
    private let onDismiss: () -> Void
    private let types : [UTType]
    private let multiple : Bool
    
    init(isPresented : Binding<Bool>, types : [UTType], multiple : Bool, callback: @escaping ([URL]) -> (), onDismiss: @escaping () -> Void) {
        self.callback = callback
        self.onDismiss = onDismiss
        self.types = types
        self.multiple = multiple
        self.delegate = Coordinator(callback: callback, onDismiss: onDismiss)
        self._isPresented = isPresented
    }

    public func body(content: Content) -> some View {
        content.onChange(of: isPresented) { isPresented in
            if isPresented, docController == nil {
                let controller = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
                controller.allowsMultipleSelection = multiple
                controller.delegate = delegate
                self.docController = controller
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    return
                }
                scene.windows.first?.rootViewController?.present(controller, animated: true)
            } else if !isPresented, let docController = docController {
                docController.dismiss(animated: true)
                self.docController = nil
            }
        }
    }

    private func shutdown() {
        isPresented = false
        docController = nil
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var callback: ([URL]) -> ()
        private let onDismiss: () -> Void
        
        init(callback: @escaping ([URL]) -> Void, onDismiss: @escaping () -> Void) {
            self.callback = callback
            self.onDismiss = onDismiss
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            callback(urls)
            onDismiss()
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDismiss()
        }
    }

}

public struct TextFieldAlertModifier: ViewModifier {

    @State private var alertController: UIAlertController?

    @Binding var isPresented: Bool

    let title: String
    let text: Binding<String>
    let placeholder: String
    let action: (String?) -> Void
    let actionCancel: (String?) -> Void

    public func body(content: Content) -> some View {
        content.onChange(of: isPresented) { isPresented in
            if isPresented, alertController == nil {
                let alertController = makeAlertController()
                self.alertController = alertController
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    return
                }
                scene.windows.first?.rootViewController?.present(alertController, animated: true)
            } else if !isPresented, let alertController = alertController {
                alertController.dismiss(animated: true)
                self.alertController = nil
            }
        }
    }

    private func makeAlertController() -> UIAlertController {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        controller.addTextField {
            $0.placeholder = self.placeholder
            $0.text = self.text.wrappedValue
            $0.clearButtonMode = .always
        }
        controller.addAction(UIAlertAction(title: "lc.common.cancel".loc, style: .cancel) { _ in
            self.actionCancel(nil)
            shutdown()
        })
        controller.addAction(UIAlertAction(title: "lc.common.ok".loc, style: .default) { _ in
            self.action(controller.textFields?.first?.text)
            shutdown()
        })
        return controller
    }

    private func shutdown() {
        isPresented = false
        alertController = nil
    }

}

struct ImageDocument: FileDocument {
    var data: Data
    
    static var readableContentTypes: [UTType] {
        [UTType.image] // Specify that the document supports image files
    }
    
    // Initialize with data
    init(uiImage: UIImage) {
        self.data = uiImage.pngData()!
    }
    
    // Function to read the data from the file
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    // Write data to the file
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}



struct SiteAssociationDetailItem : Codable {
    var appID: String?
    var appIDs: [String]?
    
    func getBundleIds() -> [String] {
        var ans : [String] = []
        // get rid of developer id
        if let appID = appID, appID.count > 11 {
            let index = appID.index(appID.startIndex, offsetBy: 11)
            let modifiedString = String(appID[index...])
            ans.append(modifiedString)
        }
        if let appIDs = appIDs {
            for appID in appIDs {
                if appID.count > 11 {
                    let index = appID.index(appID.startIndex, offsetBy: 11)
                    let modifiedString = String(appID[index...])
                    ans.append(modifiedString)
                }
            }
        }
        return ans
    }
}

struct AppLinks : Codable {
    var details : [SiteAssociationDetailItem]?
}

struct SiteAssociation : Codable {
    var applinks: AppLinks?
}

extension LCUtils {
    public static let appGroupUserDefault = UserDefaults.init(suiteName: LCUtils.appGroupID()) ?? UserDefaults.standard
    
    public static func signFilesInFolder(url: URL, signer:Signer, onProgressCreated: (Progress) -> Void) async -> (String?, Date?) {
        let fm = FileManager()
        var ans : String? = nil
        let codesignPath = url.appendingPathComponent("_CodeSignature")
        let provisionPath = url.appendingPathComponent("embedded.mobileprovision")
        let tmpExecPath = url.appendingPathComponent("LiveContainer.tmp")
        let tmpInfoPath = url.appendingPathComponent("Info.plist")
        var info = Bundle.main.infoDictionary!;
        info["CFBundleExecutable"] = "LiveContainer.tmp";
        let nsInfo = info as NSDictionary
        nsInfo.write(to: tmpInfoPath, atomically: true)
        do {
            try fm.copyItem(at: Bundle.main.executableURL!, to: tmpExecPath)
        } catch {
            return (nil, nil)
        }
        var ansDate : Date? = nil
        await withCheckedContinuation { c in
            func compeletionHandler(success: Bool, expirationDate: Date?, teamId : String?, error: Error?){
                do {
                    if let error = error {
                        ans = error.localizedDescription
                    }
                    if(fm.fileExists(atPath: codesignPath.path)) {
                        try fm.removeItem(at: codesignPath)
                    }
                    if(fm.fileExists(atPath: provisionPath.path)) {
                        try fm.removeItem(at: provisionPath)
                    }

                    try fm.removeItem(at: tmpExecPath)
                    try fm.removeItem(at: tmpInfoPath)
                    ansDate = expirationDate
                } catch {
                    ans = error.localizedDescription
                }
                c.resume()
            }
            let progress : Progress?
            if signer == .AltSign {
                progress = LCUtils.signAppBundle(url, completionHandler: compeletionHandler)
            } else {
                progress = LCUtils.signAppBundle(withZSign: url, completionHandler: compeletionHandler)
            }
            guard let progress = progress else {
                ans = "lc.utils.initSigningError".loc
                c.resume()
                return
            }
            onProgressCreated(progress)
        }
        return (ans, ansDate)

    }
    
    public static func signTweaks(tweakFolderUrl: URL, force : Bool = false, signer:Signer, progressHandler : ((Progress) -> Void)? = nil) async throws {
        guard LCUtils.certificatePassword() != nil else {
            return
        }
        let fm = FileManager.default
        var isFolder :ObjCBool = false
        if(fm.fileExists(atPath: tweakFolderUrl.path, isDirectory: &isFolder) && !isFolder.boolValue) {
            return
        }
        
        // check if re-sign is needed
        // if sign is expired, or inode number of any file changes, we need to re-sign
        let tweakSignInfo = NSMutableDictionary(contentsOf: tweakFolderUrl.appendingPathComponent("TweakInfo.plist")) ?? NSMutableDictionary()
        let expirationDate = tweakSignInfo["expirationDate"] as? Date
        var signNeeded = false
        if let expirationDate, expirationDate.compare(Date.now) == .orderedDescending, !force {
            
            let tweakFileINodeRecord = tweakSignInfo["files"] as? [String:NSNumber] ?? [String:NSNumber]()
            let fileURLs = try fm.contentsOfDirectory(at: tweakFolderUrl, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                let attributes = try fm.attributesOfItem(atPath: fileURL.path)
                let fileType = attributes[.type] as? FileAttributeType
                if(fileType != FileAttributeType.typeDirectory && fileType != FileAttributeType.typeRegular) {
                    continue
                }
                if(fileType == FileAttributeType.typeDirectory && !fileURL.lastPathComponent.hasSuffix(".framework")) {
                    continue
                }
                if(fileType == FileAttributeType.typeRegular && !fileURL.lastPathComponent.hasSuffix(".dylib")) {
                    continue
                }
                
                if(fileURL.lastPathComponent == "TweakInfo.plist"){
                    continue
                }
                let inodeNumber = try fm.attributesOfItem(atPath: fileURL.path)[.systemFileNumber] as? NSNumber
                if let fileInodeNumber = tweakFileINodeRecord[fileURL.lastPathComponent] {
                    if(fileInodeNumber != inodeNumber) {
                        signNeeded = true
                        break
                    }
                } else {
                    signNeeded = true
                    break
                }
                
                print(fileURL.lastPathComponent) // Prints the file name
            }
            
        } else {
            signNeeded = true
        }
        
        guard signNeeded else {
            return
        }
        // sign start
        
        let tweakItems : [String] = []
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("TweakTmp.app")
        if fm.fileExists(atPath: tmpDir.path) {
            try fm.removeItem(at: tmpDir)
        }
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        
        var tmpPaths : [URL] = []
        // copy items to tmp folders
        let fileURLs = try fm.contentsOfDirectory(at: tweakFolderUrl, includingPropertiesForKeys: nil)
        for fileURL in fileURLs {
            let attributes = try fm.attributesOfItem(atPath: fileURL.path)
            let fileType = attributes[.type] as? FileAttributeType
            if(fileType != FileAttributeType.typeDirectory && fileType != FileAttributeType.typeRegular) {
                continue
            }
            if(fileType == FileAttributeType.typeDirectory && !fileURL.lastPathComponent.hasSuffix(".framework")) {
                continue
            }
            if(fileType == FileAttributeType.typeRegular && !fileURL.lastPathComponent.hasSuffix(".dylib")) {
                continue
            }
            
            let tmpPath = tmpDir.appendingPathComponent(fileURL.lastPathComponent)
            tmpPaths.append(tmpPath)
            try fm.copyItem(at: fileURL, to: tmpPath)
        }
        
        if tmpPaths.isEmpty {
            try fm.removeItem(at: tmpDir)
            return
        }
        
        let (error, expirationDate2) = await LCUtils.signFilesInFolder(url: tmpDir, signer: signer) { p in
            if let progressHandler {
                progressHandler(p)
            }
        }
        if let error = error {
            throw error
        }
        
        // move signed files back and rebuild TweakInfo.plist
        tweakSignInfo.removeAllObjects()
        tweakSignInfo["expirationDate"] = expirationDate2
        var fileInodes = [String:NSNumber]()
        for tmpFile in tmpPaths {
            let toPath = tweakFolderUrl.appendingPathComponent(tmpFile.lastPathComponent)
            // remove original item and move the signed ones back
            if fm.fileExists(atPath: toPath.path) {
                try fm.removeItem(at: toPath)
                
            }
            try fm.moveItem(at: tmpFile, to: toPath)
            if let inodeNumber = try fm.attributesOfItem(atPath: toPath.path)[.systemFileNumber] as? NSNumber {
                fileInodes[tmpFile.lastPathComponent] = inodeNumber
            }
        }
        try fm.removeItem(at: tmpDir)

        tweakSignInfo["files"] = fileInodes
        try tweakSignInfo.write(to: tweakFolderUrl.appendingPathComponent("TweakInfo.plist"))
        
    }
    
    public static func getAppRunningLCScheme(bundleId: String) -> String? {
        // Retrieve the app group path using the app group ID
        let infoPath = LCPath.lcGroupDocPath.appendingPathComponent("appLock.plist")
        // Read the plist file into a dictionary
        guard let info = NSDictionary(contentsOf: infoPath) as? [String: String] else {
            return nil
        }
        // Iterate over the dictionary to find the matching bundle ID
        for (key, value) in info {
            if value == bundleId {
                if key == LCUtils.appUrlScheme() {
                    return nil
                }
                return key
            }
        }
        
        return nil
    }
    
    public static func getContainerUsingLCScheme(containerName: String) -> String? {
        // Retrieve the app group path using the app group ID
        let infoPath = LCPath.lcGroupDocPath.appendingPathComponent("containerLock.plist")
        // Read the plist file into a dictionary
        guard let info = NSDictionary(contentsOf: infoPath) as? [String: String] else {
            return nil
        }
        // Iterate over the dictionary to find the matching bundle ID
        for (key, value) in info {
            if value == containerName {
                if key == LCUtils.appUrlScheme() {
                    return nil
                }
                return key
            }
        }
        
        return nil
    }
    
    private static func authenticateUser(completion: @escaping (Bool, Error?) -> Void) {
        // Create a context for authentication
        let context = LAContext()
        var error: NSError?

        // Check if the device supports biometric authentication
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            // Determine the reason for the authentication request
            let reason = "lc.utils.requireAuthentication".loc

            // Evaluate the authentication policy
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evaluationError in
                DispatchQueue.main.async {
                    if success {
                        // Authentication successful
                        completion(true, nil)
                    } else {
                        if let evaluationError = evaluationError as? LAError, evaluationError.code == LAError.userCancel || evaluationError.code == LAError.appCancel {
                            completion(false, nil)
                        } else {
                            // Authentication failed
                            completion(false, evaluationError)
                        }

                    }
                }
            }
        } else {
            // Biometric authentication is not available
            DispatchQueue.main.async {
                if let evaluationError = error as? LAError, evaluationError.code == LAError.passcodeNotSet {
                    // No passcode set, we also define this as successful Authentication
                    completion(true, nil)
                } else {
                    completion(false, error)
                }

            }
        }
    }
    
    public static func authenticateUser() async throws -> Bool {
        if DataManager.shared.model.isHiddenAppUnlocked {
            return true
        }
        
        var success = false
        var error : Error? = nil
        await withCheckedContinuation { c in
            LCUtils.authenticateUser { success1, error1 in
                success = success1
                error = error1
                c.resume()
            }
        }
        if let error = error {
            throw error
        }
        if !success {
            return false
        }
        DispatchQueue.main.async {
            DataManager.shared.model.isHiddenAppUnlocked = true
        }
        return true
    }
    
    public static func getStoreName() -> String {
        switch LCUtils.store() {
        case .AltStore:
            return "AltStore"
        case .SideStore:
            return "SideStore"
        default:
            return "未知商店"
        }
    }
    
    public static func removeAppKeychain(dataUUID label: String) {
        [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity].forEach {
          let status = SecItemDelete([
            kSecClass as String: $0,
            "alis": label,
          ] as CFDictionary)
          if status != errSecSuccess && status != errSecItemNotFound {
              //Error while removing class $0
              NSLog("[LC] 无法找到钥匙串项目: \(status)")
          }
        }
    }

}
