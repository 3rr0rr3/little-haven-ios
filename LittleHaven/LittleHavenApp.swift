import SwiftUI
import UIKit

@main
struct LittleHavenApp: App {
    var body: some Scene {
        WindowGroup { StartupRecoveryRoot().preferredColorScheme(.dark) }
    }
}

// Local startup breadcrumbs, not a crash handler. No data is uploaded automatically.
enum StartupTrace {
    private struct Record: Codable {
        var id = UUID().uuidString
        var pending = true
        var build: String
        var system: String
        var reason: String
        var steps: [String] = []
    }
    private static let lock = NSLock()
    private static let url: URL? = {
        guard let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first else{return nil}
        try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        return directory.appendingPathComponent("startup-report.json")
    }()
    private static var record: Record? = {
        guard let url,let data=try? Data(contentsOf:url) else{return nil}
        return try? JSONDecoder().decode(Record.self,from:data)
    }()
    static var version: String {
        "\(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "?") (\(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "?"))"
    }
    private static var enabled: Bool {
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        return !args.contains(where:{$0.hasPrefix("--ui-")}) || args.contains("--ui-recovery-preview") || args.contains("--ui-recovery-inspect")
        #else
        return true
        #endif
    }
    private static func persist() {
        guard let url,let record,let data=try? JSONEncoder().encode(record) else{return}
        try? data.write(to:url,options:.atomic)
    }
    static let needsRecovery: Bool = {
        guard enabled else{return false}
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-recovery-preview") {
            begin("simulated interrupted startup");stage("before_hotel_view");return true
        }
        #endif
        if let previous=record,previous.pending {
            if previous.build != version {
                // A prior build's unfinished attempt must not trap an updated app
                // in recovery. Preserve its evidence, then try this build once.
                if let url,let data=try? JSONEncoder().encode(previous) {
                    try? data.write(to:url.deletingLastPathComponent().appendingPathComponent("startup-report-previous.json"),options:.atomic)
                }
                begin("app update retry")
                stage("previous_build_startup_preserved")
                return false
            }
            return true
        }
        begin("app launch");return false
    }()
    static func begin(_ reason: String) {
        guard enabled else{return}
        lock.lock();defer{lock.unlock()}
        record=Record(build:version,system:UIDevice.current.systemVersion,reason:reason)
        record?.steps=["begin: "+reason];persist()
    }
    static func stage(_ name: String) {
        guard enabled else{return}
        lock.lock();defer{lock.unlock()}
        guard record?.pending == true,record?.steps.contains(name) == false else{return}
        record?.steps.append(name);persist()
    }
    static var activeID: String? {
        lock.lock();defer{lock.unlock()}
        return record?.pending == true ? record?.id : nil
    }
    static func finish(_ name: String,ifID: String? = nil) {
        guard enabled else{return}
        lock.lock();defer{lock.unlock()}
        guard record?.pending == true,ifID == nil || record?.id == ifID else{return}
        record?.steps.append(name);record?.pending=false;persist()
    }
    static var report: String {
        lock.lock();defer{lock.unlock()}
        guard let record else{return "Brainstorm Haven \(version)\nNo startup report recorded."}
        return "Brainstorm Haven startup report\nInstalled: \(version)\nRecorded: \(record.build)\niOS: \(record.system)\nStart: \(record.reason)\nStartup incomplete: \(record.pending)\n"+record.steps.joined(separator:"\n")
    }
}

private struct StartupRecoveryRoot: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var recovery = StartupTrace.needsRecovery
    var body: some View {
        Group {
            if recovery {
                StartupRecoveryScreen {
                    StartupTrace.begin("recovery retry")
                    recovery=false
                }
            } else {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-npc-gallery") {NPCIdentityReview()}
                else if ProcessInfo.processInfo.arguments.contains("--ui-life-gallery") {LifeAnimationReview()}
                else {ContentView()}
                #else
                ContentView()
                #endif
            }
        }.onChange(of:scenePhase) {_,phase in
            guard phase == .background,!recovery else{return}
            #if DEBUG
            let args=ProcessInfo.processInfo.arguments
            if args.contains("--ui-recovery-preview") || args.contains("--ui-recovery-inspect") {return}
            #endif
            // Leaving the app normally during the grace period is not a crash.
            StartupTrace.finish("startup_backgrounded")
        }
    }
}

private struct StartupRecoveryScreen: View {
    let retry: () -> Void
    @State private var copied=false
    private let report=StartupTrace.report
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text("BRAINSTORM HAVEN").font(.title2.bold())
            Text("Startup recovery").font(.title.bold())
            Text("The last startup did not finish. Your saved game has not been reset. Copy this report and paste it in our chat.")
            ScrollView {Text(report).font(.system(size:12,design:.monospaced)).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled)}
                .accessibilityIdentifier("startupReport")
            Button(copied ? "Report copied" : "Copy startup report") {
                UIPasteboard.general.string=report;copied=true
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains(where:{$0 == "--ui-recovery-preview" || $0 == "--ui-recovery-inspect"}) {StartupTrace.finish("preview_report_copied")}
                #endif
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("copyStartupReport")
            ShareLink("Share startup report",item:report).buttonStyle(.bordered)
            Button("Try opening my game",action:retry).buttonStyle(.bordered).accessibilityIdentifier("retryStartup")
            Text("Installed version \(StartupTrace.version)").font(.caption)
        }.padding(24).foregroundStyle(.white).background(Color(red:0.09,green:0.16,blue:0.14))
    }
}
