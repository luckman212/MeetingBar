//
//  AdvancedTab.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 13.01.2021.
//  Copyright © 2021 Andrii Leitsius. All rights reserved.
//

import SwiftUI

import Defaults

struct AdvancedTab: View {
    var body: some View {
        VStack(alignment: .leading) {
            ScriptSection()
            Divider()
            FilterEventRegexesSection()
            Divider()
            MeetingRegexesSection()
            Divider()
            HStack {
                Spacer()
                Text("preferences_advanced_setting_warning".loco())
                Spacer()
            }
        }.padding()
    }
}

struct ScriptSection: View {
    @Default(.runEventStartScript) var runEventStartScript
    @Default(.eventStartScriptLocation) var eventStartScriptLocation
    @Default(.eventStartScript) var eventStartScript
    @Default(.eventStartScriptTime) var eventStartScriptTime

    @State private var showingRunEventStartScriptModal = false

    @Default(.runJoinEventScript) var runJoinEventScript
    @Default(.joinEventScriptLocation) var joinEventScriptLocation
    @Default(.joinEventScript) var joinEventScript

    @State private var showingJoinEventScriptModal = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Toggle("Run AppleScript automatically", isOn: $runEventStartScript)
                Picker("", selection: $eventStartScriptTime) {
                    Text("general_when_event_starts".loco()).tag(EventScriptExecutionTime.atStart)
                    Text("general_one_minute_before".loco()).tag(EventScriptExecutionTime.minuteBefore)
                    Text("general_three_minute_before".loco()).tag(EventScriptExecutionTime.threeMinuteBefore)
                    Text("general_five_minute_before".loco()).tag(EventScriptExecutionTime.fiveMinuteBefore)
                }.frame(width: 150, alignment: .leading).labelsHidden().disabled(!runEventStartScript)
                Spacer()
                if runEventStartScript {
                    Button(action: runSampleScript) {
                        Text("Test on next event")
                    }
                    Button("Edit script") { showingRunEventStartScriptModal = true }
                }
            }.sheet(isPresented: $showingRunEventStartScriptModal) {
                EditScriptModal(script: $eventStartScript, scriptLocation: $eventStartScriptLocation, scriptName: "eventStartScript.scpt")
            }
            Divider()
            HStack {
                Toggle("preferences_advanced_apple_script_checkmark".loco(), isOn: $runJoinEventScript)
                Spacer()
                if runJoinEventScript {
                    Button("Edit script") { showingJoinEventScriptModal = true }
                }
            }.sheet(isPresented: $showingJoinEventScriptModal) {
                EditScriptModal(script: $joinEventScript, scriptLocation: $joinEventScriptLocation, scriptName: "joinEventScript.scpt")
            }
        }
    }

    func runSampleScript() {
        if let app = NSApplication.shared.delegate as! AppDelegate? {
            runAppleScriptForNextEvent(events: app.statusBarItem.events)
        }
    }
}

struct EditScriptModal: View {
    @Environment(\.presentationMode) var presentationMode

    @Binding var script: String
    @Binding var scriptLocation: URL?
    var scriptName: String

    @State var editedScript: String = ""

    @State private var showingAlert = false
    @State private var error_msg = ""

    var body: some View {
        VStack {
            Spacer()
            Text("Edit script")
            Spacer()
            NSScrollableTextViewWrapper(text: $editedScript).padding(.leading, 19)
            Spacer()
            HStack {
                Button(action: cancel) {
                    Text("general_cancel".loco())
                }
                Spacer()
                Button(action: saveScript) {
                    Text("general_save".loco())
                }.disabled(self.editedScript == self.script)
            }
            Spacer()
        }.padding().frame(width: 500, height: 500)
            .onAppear { self.editedScript = self.script }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("preferences_advanced_wrong_location_title".loco()),
                      message: Text("preferences_advanced_wrong_location_message".loco()),
                      dismissButton: .default(Text("preferences_advanced_wrong_location_button".loco())))
            }
    }

    func saveScript() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowedFileTypes = ["none"]
        openPanel.allowsOtherFileTypes = false
        openPanel.prompt = "preferences_advanced_save_script_button".loco()
        openPanel.message = "preferences_advanced_wrong_location_message".loco()
        let scriptPath = try! FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        openPanel.directoryURL = scriptPath
        openPanel.begin { response in
            if response == .OK {
                if openPanel.url != scriptPath {
                    showingAlert = true
                    return
                }
                scriptLocation = openPanel.url
                if let filepath = openPanel.url?.appendingPathComponent(scriptName) {
                    do {
                        try editedScript.write(to: filepath, atomically: true, encoding: String.Encoding.utf8)
                        script = editedScript
                        presentationMode.wrappedValue.dismiss()
                    } catch {}
                }
            }
            openPanel.close()
        }
    }

    func cancel() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct NSScrollableTextViewWrapper: NSViewRepresentable {
    typealias NSViewType = NSScrollView
    var isEditable = true
    var textSize: CGFloat = 12

    @Binding var text: String

    var didEndEditing: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as? NSTextView
        textView?.font = NSFont.systemFont(ofSize: textSize)
        textView?.isEditable = isEditable
        textView?.isSelectable = true
        textView?.isAutomaticQuoteSubstitutionEnabled = false
        textView?.delegate = context.coordinator

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context _: Context) {
        let textView = nsView.documentView as? NSTextView
        guard textView?.string != text else {
            return
        }

        textView?.string = text
        textView?.display() // force update UI to re-draw the string
        textView?.scrollRangeToVisible(NSRange(location: text.count, length: 0))
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var view: NSScrollableTextViewWrapper

        init(_ view: NSScrollableTextViewWrapper) {
            self.view = view
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            view.text = textView.string
        }

        func textDidEndEditing(_: Notification) {
            view.didEndEditing?()
        }
    }
}

struct FilterEventRegexesSection: View {
    @Default(.filterEventRegexes) var filterEventRegexes

    @State private var showingEditRegexModal = false
    @State private var selectedRegex = ""

    var body: some View {
        Section {
            HStack {
                Text("preferences_advanced_event_regex_title".loco())
                Spacer()
                Button("preferences_advanced_regex_add_button".loco()) { openEditRegexModal("") }
            }
            List {
                ForEach(filterEventRegexes, id: \.self) { regex in
                    HStack {
                        Text(regex)
                        Spacer()
                        Button("preferences_advanced_regex_edit_button".loco()) { openEditRegexModal(regex) }
                        Button("preferences_advanced_regex_delete_button".loco()) { removeRegex(regex) }
                    }
                }
            }
            .sheet(isPresented: $showingEditRegexModal) {
                EditRegexModal(regex: selectedRegex, function: addRegex)
            }
        }.padding(.leading, 19)
    }

    func openEditRegexModal(_ regex: String) {
        selectedRegex = regex
        removeRegex(regex)
        showingEditRegexModal.toggle()
    }

    func addRegex(_ regex: String) {
        if !filterEventRegexes.contains(regex) {
            filterEventRegexes.append(regex)
        }
    }

    func removeRegex(_ regex: String) {
        if let index = filterEventRegexes.firstIndex(of: regex) {
            filterEventRegexes.remove(at: index)
        }
    }
}

struct MeetingRegexesSection: View {
    @Default(.customRegexes) var customRegexes

    @State private var showingEditRegexModal = false
    @State private var selectedRegex = ""

    var body: some View {
        Section {
            HStack {
                Text("preferences_advanced_regex_title".loco())
                Spacer()
                Button("preferences_advanced_regex_add_button".loco()) { openEditRegexModal("") }
            }
            List {
                ForEach(customRegexes, id: \.self) { regex in
                    HStack {
                        Text(regex)
                        Spacer()
                        Button("preferences_advanced_regex_edit_button".loco()) { openEditRegexModal(regex) }
                        Button("preferences_advanced_regex_delete_button".loco()) { removeRegex(regex) }
                    }
                }
            }
            .sheet(isPresented: $showingEditRegexModal) {
                EditRegexModal(regex: selectedRegex, function: addRegex)
            }
        }.padding(.leading, 19)
    }

    func openEditRegexModal(_ regex: String) {
        selectedRegex = regex
        removeRegex(regex)
        showingEditRegexModal.toggle()
    }

    func addRegex(_ regex: String) {
        if !customRegexes.contains(regex) {
            customRegexes.append(regex)
        }
    }

    func removeRegex(_ regex: String) {
        if let index = customRegexes.firstIndex(of: regex) {
            customRegexes.remove(at: index)
        }
    }
}

struct EditRegexModal: View {
    @Environment(\.presentationMode) var presentationMode
    @State var new_regex: String = ""
    var regex: String
    var function: (_ regex: String) -> Void

    @State private var showingAlert = false
    @State private var error_msg = ""

    var body: some View {
        VStack {
            Spacer()
            TextField("preferences_advanced_regex_new_title".loco(), text: $new_regex)
            Spacer()
            HStack {
                Button(action: cancel) {
                    Text("general_cancel".loco())
                }
                Spacer()
                Button(action: save) {
                    Text("general_save".loco())
                }.disabled(new_regex.isEmpty)
            }
        }.padding()
            .frame(width: 500, height: 150)
            .onAppear { self.new_regex = self.regex }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("preferences_advanced_regex_new_cant_save_title".loco()), message: Text(error_msg), dismissButton: .default(Text("general_ok".loco())))
            }
    }

    func cancel() {
        if !regex.isEmpty {
            function(regex)
        }
        presentationMode.wrappedValue.dismiss()
    }

    func save() {
        do {
            _ = try NSRegularExpression(pattern: new_regex)
            function(new_regex)
            presentationMode.wrappedValue.dismiss()
        } catch let error as NSError {
            error_msg = error.localizedDescription
            showingAlert = true
        }
    }
}
