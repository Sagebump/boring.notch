//
//  boringNotchApp.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//

import AVFoundation
import Combine
import KeyboardShortcuts
import Sparkle
import SwiftUI

@main
struct DynamicNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @Environment(\.openWindow) var openWindow
    let updaterController: SPUStandardUpdaterController
    
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    var body: some Scene {
        Settings {
            SettingsView(updaterController: updaterController)
                .environmentObject(appDelegate.vm)
        }
        //.windowResizability(.contentSize)
        .defaultSize(width: 500, height: 600)
        
        Window("Onboarding", id: "onboarding") {
            ProOnboard()
        }
        
        Window("Activation", id: "activation") {
            ActivationWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        MenuBarExtra("boring.notch", systemImage: "music.note", isInserted: $showMenuBarIcon) {
            SettingsLink(label: {
                Text("Settings")
            })
            .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            Button("Clipboard history") {
                self.appDelegate.vm.openClipboard()
            }
            .keyboardShortcut(KeyboardShortcuts.Name("clipboardHistoryPanel"))
            .disabled(BoringExtensionManager().installedExtensions.map({$0.bundleIdentifier}).contains(clipboardExtension))
            Button("Activate License") {
                openWindow(id: "activation")
            }
            CheckForUpdatesView(updater: updaterController.updater)
            Divider()
            Button("Restart Boring Notch") {}
            Button("Quit", role: .destructive) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var window: NSWindow!
    var sizing: Sizes = .init()
    let vm: BoringViewModel = .init()
    var whatsNewWindow: NSWindow?
    var timer: Timer?
    let calenderManager = CalendarManager()
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        
        vm.setupWorkersNotificationObservers();
        
        if !NSScreen.screens.contains(where: {$0.localizedName == vm.selectedScreen}) {
            vm.selectedScreen = NSScreen.main?.localizedName ?? "Unknown"
        }
    
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustWindowPosition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(forName: Notification.Name.selectedScreenChanged, object: nil, queue: nil) { [weak self] _ in
            self?.adjustWindowPosition()
        }
        
        window = BoringNotchWindow(
            contentRect: NSRect(x: 0, y: 0, width: sizing.size.opened.width! + 20, height: sizing.size.opened.height! + 30),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = NSHostingView(rootView: ContentView(onHover: adjustWindowPosition, batteryModel: .init(vm: self.vm)).environmentObject(vm).environmentObject(MusicManager(vm: vm)!))
        
        adjustWindowPosition()
        
        window.orderFrontRegardless()
        
        if vm.firstLaunch {
            playWelcomeSound()
        }
    }
    
    func playWelcomeSound() {
        let audioPlayer = AudioPlayer()
        audioPlayer.play(fileName: "boring", fileExtension: "m4a")
    }
    
    func deviceHasNotch() -> Bool {
        if #available(macOS 12.0, *) {
            for screen in NSScreen.screens {
                if screen.safeAreaInsets.top > 0 {
                    return true
                }
            }
        }
        return false
    }
    
    @objc func adjustWindowPosition() {
        let selectedScreen = NSScreen.screens.first(where: {$0.localizedName == vm.selectedScreen})
        closedNotchSize = setNotchSize(screen: selectedScreen?.localizedName)
        
        if let screenFrame = selectedScreen {
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            
            DispatchQueue.main.async {[weak self] in
                self!.window.setFrameOrigin(screenFrame.frame.origin.applying(CGAffineTransform(translationX: (screenFrame.frame.width / 2) - self!.window.frame.width / 2, y: screenFrame.frame.height - self!.window.frame.height)))
                self!.window.alphaValue = 1
            }
        }
    }
    
    @objc func togglePopover(_ sender: Any?) {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
    }
    
    @objc func showMenu() {
        statusItem!.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}

extension Notification.Name {
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
}
