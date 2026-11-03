import SwiftUI
#if os(macOS)
import AppKit

@MainActor
final class PaperletAppDelegate: NSObject, NSApplicationDelegate {
    static var isTerminating = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Self.isTerminating = true
        return .terminateNow
    }
}
#endif

@main struct MyApp: App {
    @State private var store = NoteStore()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(PaperletAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        Window("Paperlet · 메모 보드", id: "board") {
            ContentView()
                .frame(minWidth: 620, minHeight: 500)
                .modifier(DesktopNoteRestoration())
                .environment(store)
        }
        .defaultSize(width: 1120, height: 800)
        #else
        WindowGroup("Paperlet · 메모 보드", id: "board") {
            ContentView()
                .environment(store)
        }
        .defaultSize(width: 1120, height: 800)
        #endif

        #if os(macOS)
        WindowGroup("스티커 메모", id: "desktop-note", for: UUID.self) { $noteID in
            DesktopNoteWindow(noteID: noteID)
                .modifier(DesktopNoteRestoration())
                .environment(store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 340, height: 400)
        .windowResizability(.contentMinSize)
        #endif
    }
}
