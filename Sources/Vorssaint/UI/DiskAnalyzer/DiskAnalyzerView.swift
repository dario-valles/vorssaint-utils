// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The Disk Analyzer window: pick a disk, watch the scan, then explore the
/// map and the list side by side.
struct DiskAnalyzerView: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        ZStack {
            switch service.phase {
            case .idle:
                DiskAnalyzerStartView(layout: .window)
                    .transition(.opacity)
            case .scanning:
                DiskAnalyzerScanningView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .results:
                DiskAnalyzerResultsView()
                    .transition(.opacity)
            case .failed:
                failedState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .animation(.easeInOut(duration: 0.25), value: service.phase)
    }

    private var failedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(strings.scanFailed)
                .font(.headline)
            Button(strings.newScan) { service.reset() }
                .controlSize(.large)
        }
    }
}

// MARK: - Start

/// The volume picker, shared by the window and its Settings page.
struct DiskAnalyzerStartView: View {
    enum Layout {
        case window
        case settings
    }

    let layout: Layout
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var volumes: [DiskAnalyzerService.Target] = []

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                    ForEach(volumes) { volume in
                        DiskAnalyzerVolumeCard(target: volume) { start(volume) }
                    }
                    DiskAnalyzerFolderCard(symbol: "house",
                                           title: strings.homeFolder,
                                           detail: DiskAnalyzerService.shared.homeTarget().name) {
                        start(DiskAnalyzerService.shared.homeTarget())
                    }
                    DiskAnalyzerFolderCard(symbol: "folder.badge.plus",
                                           title: strings.chooseFolder,
                                           detail: strings.chooseFolderHint) { chooseFolder() }
                }
                if !permissions.fullDiskAccess {
                    FullDiskAccessNote(reason: strings.fullDiskAccessReason)
                }
            }
            .padding(.horizontal, layout == .window ? 40 : 24)
            .padding(.top, layout == .window ? 44 : 20)
            .padding(.bottom, 28)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .onAppear { volumes = DiskAnalyzerService.shared.volumes() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: [.blue, .purple, .pink, .orange, .yellow, .green, .teal, .blue],
                                          center: .center))
                    .frame(width: 46, height: 46)
                Circle()
                    .fill(.background)
                    .frame(width: 22, height: 22)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(strings.title)
                    .font(.system(size: layout == .window ? 24 : 19, weight: .bold))
                Text(strings.tagline)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func start(_ target: DiskAnalyzerService.Target) {
        if layout == .settings {
            DiskAnalyzerWindowController.shared.show(scanning: target.path)
        } else {
            DiskAnalyzerService.shared.scan(target)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = strings.scan
        guard panel.runModal() == .OK, let url = panel.url else { return }
        start(DiskAnalyzerService.shared.folderTarget(url))
    }
}

private struct DiskAnalyzerVolumeCard: View {
    let target: DiskAnalyzerService.Target
    let action: () -> Void
    @ObservedObject private var l10n = L10n.shared
    @State private var hovering = false

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }
    private var fraction: Double {
        target.capacity > 0 ? Double(target.used) / Double(target.capacity) : 0
    }
    private var gaugeColor: Color {
        fraction > 0.9 ? .red : fraction > 0.75 ? .orange : .accentColor
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(gaugeColor.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: target.kind == .startupDisk ? "internaldrive.fill" : "externaldrive.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(target.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if target.kind == .startupDisk {
                        Text(strings.startupDisk)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(String(format: strings.usedOfFormat, bytes(target.used), bytes(target.capacity)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: strings.availableFormat, bytes(target.available)))
                        .font(.caption)
                        .foregroundStyle(gaugeColor)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(hovering ? Color.accentColor : Color.secondary.opacity(0.5))
            }
            .frame(minHeight: 84)
            .padding(14)
            .background(cardBackground(hovering: hovering))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(strings.scan)
    }
}

private struct DiskAnalyzerFolderCard: View {
    let symbol: String
    let title: String
    let detail: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.accentColor.opacity(0.1)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 84)
            .padding(14)
            .background(cardBackground(hovering: hovering))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private func cardBackground(hovering: Bool) -> some View {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.primary.opacity(hovering ? 0.075 : 0.045))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.primary.opacity(hovering ? 0.14 : 0.07), lineWidth: 0.8))
        .animation(.easeOut(duration: 0.12), value: hovering)
}

private func bytes(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
}

private func count(_ value: Int) -> String {
    value.formatted(.number)
}

// MARK: - Scanning

private struct DiskAnalyzerScanningView: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }
    /// Volumes report how much is used, so their scan has a real progress.
    private var fraction: Double? {
        guard let target = service.target, target.isVolume, target.used > 0 else { return nil }
        return min(0.99, Double(service.progress.bytes) / Double(target.used))
    }

    var body: some View {
        VStack(spacing: 26) {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<4, id: \.self) { ring in
                        let width = 30.0 - Double(ring) * 5
                        Circle()
                            .trim(from: 0, to: 0.18 + 0.12 * Double(ring))
                            .stroke(AngularGradient(colors: [.blue, .purple, .pink, .orange, .yellow, .green, .teal, .blue],
                                                    center: .center),
                                    style: StrokeStyle(lineWidth: width, lineCap: .round))
                            .frame(width: 120 + Double(ring) * 70, height: 120 + Double(ring) * 70)
                            .rotationEffect(.degrees(time * (50 + Double(ring) * 22) * (ring.isMultiple(of: 2) ? 1 : -1)))
                            .opacity(0.85 - Double(ring) * 0.15)
                    }
                    VStack(spacing: 4) {
                        Text(bytes(service.progress.bytes))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(String(format: strings.filesFormat, count(service.progress.files)))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .frame(width: 340, height: 340)
            }
            VStack(spacing: 10) {
                Text(service.target?.name ?? strings.scanning)
                    .font(.title3.weight(.semibold))
                if let fraction {
                    ProgressView(value: fraction)
                        .frame(width: 320)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(width: 320)
                }
                Text(service.progress.currentPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 480)
            }
            Button(strings.cancel) { service.cancel() }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Results

private struct DiskAnalyzerResultsView: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var hovered: DiskNode?
    @State private var listMode = ListMode.contents
    @State private var pendingTrash: DiskNode?
    @State private var trashError: String?

    private enum ListMode: Hashable {
        case contents, largest
    }

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        if let root = service.root, let focus = service.focus {
            VStack(spacing: 0) {
                toolbar(root: root, focus: focus)
                Divider()
                HStack(spacing: 0) {
                    chart(focus: focus)
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    sidebar(focus: focus)
                        .frame(width: 360)
                }
                Divider()
                footer(root: root)
            }
            .alert(trashTitle, isPresented: Binding(get: { pendingTrash != nil },
                                                    set: { if !$0 { pendingTrash = nil } })) {
                Button(strings.moveToTrash, role: .destructive) {
                    if let node = pendingTrash { trash(node) }
                    pendingTrash = nil
                }
                Button(strings.cancel, role: .cancel) { pendingTrash = nil }
            } message: {
                Text(String(format: strings.trashMessageFormat, bytes(pendingTrash?.size ?? 0)))
            }
            .alert(trashError ?? "", isPresented: Binding(get: { trashError != nil },
                                                          set: { if !$0 { trashError = nil } })) {
                Button("OK") { trashError = nil }
            }
        }
    }

    private var trashTitle: String {
        String(format: strings.trashTitleFormat, pendingTrash?.name ?? "")
    }

    // MARK: Toolbar

    private func toolbar(root: DiskNode, focus: DiskNode) -> some View {
        HStack(spacing: 10) {
            Button {
                service.reset()
            } label: {
                Label(strings.newScan, systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            Divider().frame(height: 16)
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(focus.lineage.enumerated()), id: \.offset) { index, node in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            Button {
                                service.focus(on: node)
                            } label: {
                                Text(index == 0 ? (service.target?.name ?? node.name) : node.name)
                                    .font(.system(size: 12, weight: node === focus ? .semibold : .regular))
                                    .foregroundStyle(node === focus ? .primary : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: 5)
                                        .fill(node === focus ? Color.primary.opacity(0.07) : .clear))
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                }
                .onChange(of: ObjectIdentifier(focus)) { _, _ in
                    withAnimation { reader.scrollTo(focus.lineage.count - 1, anchor: .trailing) }
                }
            }
            Spacer(minLength: 8)
            if service.rescanning {
                ProgressView().controlSize(.small)
            }
            Button {
                service.rescanFocus()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(strings.rescan)
            .accessibilityLabel(strings.rescan)
            .disabled(service.rescanning)
            Button {
                service.reveal(focus)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help(strings.revealInFinder)
            .accessibilityLabel(strings.revealInFinder)
        }
        .padding(.leading, 78)
        .padding(.trailing, 14)
        .frame(height: 38)
    }

    // MARK: Chart

    private func chart(focus: DiskNode) -> some View {
        let shown = hovered ?? focus
        let share = focus.size > 0 ? Double(shown.size) / Double(focus.size) : 0
        let caption: String
        if shown === focus {
            caption = String(format: strings.filesFormat, count(focus.fileCount))
        } else {
            caption = share.formatted(.percent.precision(.fractionLength(share < 0.1 ? 1 : 0)))
        }
        return SunburstChart(focus: focus,
                             revision: service.revision,
                             centerTitle: displayName(shown),
                             centerDetail: bytes(shown.size),
                             centerCaption: caption,
                             canGoUp: focus.parent != nil,
                             hovered: $hovered,
                             onSelect: select,
                             onUp: { service.focusParent() })
            .contextMenu {
                if let node = hovered { menu(for: node) }
            }
    }

    private func select(_ node: DiskNode) {
        if node.canDrillDown {
            service.focus(on: node)
        } else if node.isFileSystemItem {
            service.reveal(node)
        }
    }

    // MARK: Sidebar

    private func sidebar(focus: DiskNode) -> some View {
        VStack(spacing: 0) {
            Picker("", selection: $listMode) {
                Text(strings.contents).tag(ListMode.contents)
                Text(strings.largestFiles).tag(ListMode.largest)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)
            Divider()
            ScrollView {
                LazyVStack(spacing: 2) {
                    switch listMode {
                    case .contents:
                        let rows = coloredChildren(of: focus)
                        if rows.isEmpty {
                            Text(strings.emptyFolder)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                        }
                        ForEach(rows, id: \.node.id) { row in
                            DiskAnalyzerRow(node: row.node, name: displayName(row.node), color: row.color,
                                            share: focus.size > 0 ? Double(row.node.size) / Double(focus.size) : 0,
                                            showsPath: false, highlighted: hovered === row.node,
                                            hovered: $hovered)
                                .onTapGesture(count: 2) { select(row.node) }
                                .onTapGesture { if row.node.canDrillDown { service.focus(on: row.node) } }
                                .contextMenu { menu(for: row.node) }
                        }
                    case .largest:
                        let files = service.largestFiles(in: focus)
                        let top = files.first?.size ?? 1
                        ForEach(files) { node in
                            DiskAnalyzerRow(node: node, name: node.name, color: .accentColor,
                                            share: Double(node.size) / Double(max(1, top)),
                                            showsPath: true, highlighted: false, hovered: .constant(nil))
                                .onTapGesture(count: 2) { service.reveal(node) }
                                .contextMenu { menu(for: node) }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .id(listMode == .largest ? "largest-\(ObjectIdentifier(focus).hashValue)-\(service.revision)" : "contents")
        }
    }

    /// The focus's children with the same colours the chart gives them.
    private func coloredChildren(of focus: DiskNode) -> [(node: DiskNode, color: Color)] {
        guard focus.size > 0 else { return [] }
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        var cursor = 0.0
        return focus.children.filter { $0.size > 0 }.map { child in
            let span = Double(child.size) / Double(focus.size)
            defer { cursor += span }
            return (child, SunburstPalette.color(for: child.kind, mid: cursor + span / 2, depth: 1, dark: dark))
        }
    }

    @ViewBuilder
    private func menu(for node: DiskNode) -> some View {
        if node.canDrillDown {
            Button(strings.zoomIn) { service.focus(on: node) }
        }
        if node.isFileSystemItem {
            Button(strings.revealInFinder) { service.reveal(node) }
            Button(strings.open) { service.open(node) }
            Button(strings.copyPath) { service.copyPath(node) }
            if service.canTrash(node) {
                Divider()
                Button(strings.moveToTrash, role: .destructive) { pendingTrash = node }
            }
        }
    }

    private func trash(_ node: DiskNode) {
        if hovered.map({ $0 === node || node.isAncestor(of: $0) }) == true { hovered = nil }
        let result = service.moveToTrash([node])
        if let failed = result.failed.first {
            trashError = String(format: strings.trashFailedFormat, failed)
        }
    }

    // MARK: Footer

    private func footer(root: DiskNode) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(String(format: strings.summaryFormat, count(service.progress.files), duration(service.scanSeconds)))
                .font(.caption)
                .foregroundStyle(.secondary)
            if service.progress.unreadable > 0 {
                Text("·").foregroundStyle(.tertiary)
                Label(String(format: strings.unreadableFormat, count(service.progress.unreadable)),
                      systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(strings.fullDiskAccessReason)
            }
            Spacer()
            if !permissions.fullDiskAccess {
                Button(strings.allowFullDiskAccess) { permissions.requestFullDiskAccess() }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
    }

    private func displayName(_ node: DiskNode) -> String {
        switch node.kind {
        case .smallFiles: return String(format: strings.smallFilesFormat, count(node.fileCount))
        case .hidden: return strings.hiddenSpace
        case .directory, .file:
            return node.parent == nil ? (service.target?.name ?? node.name) : node.name
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 60 ? [.minute, .second] : [.second]
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(1, seconds.rounded())) ?? ""
    }
}

private struct DiskAnalyzerRow: View {
    let node: DiskNode
    let name: String
    let color: Color
    let share: Double
    let showsPath: Bool
    let highlighted: Bool
    @Binding var hovered: DiskNode?
    @ObservedObject private var l10n = L10n.shared
    @State private var hovering = false

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if node.unreadable {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help(strings.unreadableHelp)
                    } else if node.cloudOnly {
                        Image(systemName: "icloud")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help(strings.cloudOnlyHelp)
                    }
                    Spacer(minLength: 4)
                    Text(bytes(node.size))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                if showsPath, let parent = node.parent {
                    Text(parent.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.07))
                        Capsule().fill(color.gradient)
                            .frame(width: max(3, proxy.size.width * min(1, share)))
                    }
                }
                .frame(height: 4)
            }
            if node.canDrillDown {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.primary.opacity(highlighted || hovering ? 0.07 : 0)))
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            if inside { hovered = node } else if hovered === node { hovered = nil }
        }
        .help(node.kind == .hidden ? strings.hiddenSpaceHelp : node.collapsed ? strings.collapsedHelp : "")
    }

    @ViewBuilder
    private var icon: some View {
        switch node.kind {
        case .smallFiles:
            Image(systemName: "square.stack.3d.down.right")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        case .hidden:
            Image(systemName: "eye.slash")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        case .directory, .file:
            Image(nsImage: DiskAnalyzerIconCache.shared.icon(for: node))
                .resizable()
                .interpolation(.high)
        }
    }
}

/// File icons for list rows, looked up once per path.
final class DiskAnalyzerIconCache {
    static let shared = DiskAnalyzerIconCache()
    private let cache = NSCache<NSString, NSImage>()

    func icon(for node: DiskNode) -> NSImage {
        let path = node.path
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 32, height: 32)
        cache.setObject(icon, forKey: path as NSString)
        return icon
    }
}

// MARK: - Settings

/// The Settings page: what the tool does and the same picker as the window,
/// which opens the window to show the scan.
struct DiskAnalyzerSettings: View {
    var body: some View {
        DiskAnalyzerStartView(layout: .settings)
    }
}
