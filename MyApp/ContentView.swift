import SwiftUI
import Foundation
import Observation
#if os(macOS)
import AppKit
#endif

enum NoteColor: String, Codable, CaseIterable, Identifiable {
    case butter, rose, sage, sky, lavender
    var id: String { rawValue }
    var name: String {
        switch self {
        case .butter: "버터"
        case .rose: "로즈"
        case .sage: "세이지"
        case .sky: "스카이"
        case .lavender: "라벤더"
        }
    }
    var color: Color {
        switch self {
        case .butter: Color(red: 0.98, green: 0.91, blue: 0.65)
        case .rose: Color(red: 0.97, green: 0.82, blue: 0.79)
        case .sage: Color(red: 0.83, green: 0.89, blue: 0.76)
        case .sky: Color(red: 0.80, green: 0.88, blue: 0.94)
        case .lavender: Color(red: 0.88, green: 0.83, blue: 0.94)
        }
    }
}

struct StickyNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var text: String
    var color: NoteColor
    var pinned = false
    var updatedAt = Date()

    mutating func toggleTask(at lineIndex: Int) {
        // Use the original line number, retaining indentation, blank lines and other Markdown.
        guard let block = MarkdownBlock.parse(text).first(where: { $0.id == lineIndex }),
              case .task(let done) = block.kind else { return }
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(lineIndex),
              let marker = lines[lineIndex].range(of: done ? "- [x]" : "- [ ]", options: .caseInsensitive) else { return }
        lines[lineIndex].replaceSubrange(marker, with: done ? "- [ ]" : "- [x]")
        text = lines.joined(separator: "\n")
    }

    static let examples: [StickyNote] = [
        StickyNote(title: "오늘의 작은 목표", text: "서두르지 말고, 하나씩. ☀️\n\n- [x] 커피 한 잔과 하루 시작하기\n- [ ] 가장 중요한 일 하나 끝내기\n- [ ] 20분 산책하기\n\n**작은 진전도 충분히 멋져요.**", color: .butter, pinned: true),
        StickyNote(title: "문득 떠오른 아이디어", text: "## 생각을 모으는 공간\n\n완벽한 문장보다 **잊기 전에 적는 것**.\n\n- 나만의 플레이리스트 만들기\n- 주말에 가고 싶은 곳 기록하기\n- 매일 한 장, 사진 일기\n\n> 좋은 생각은 사소한 순간에 찾아온다.", color: .rose),
        StickyNote(title: "이번 주 장보기", text: "- [ ] 아보카도 🥑\n- [x] 오트밀크\n- [ ] 토마토와 루콜라\n- [ ] 사워도우 빵\n\n토요일 아침, 동네 시장 들르기.", color: .sage),
        StickyNote(title: "Markdown 가이드", text: "**굵게**, *기울임*, ~~취소선~~\n\n# 큰 제목\n- 목록을 만들어요\n- [ ] 할 일도 적어요\n\n> 기억하고 싶은 문장\n\n코드는 `let idea = 42`\n\n[Markdown 알아보기](https://www.markdownguide.org)", color: .sky),
        StickyNote(title: "잠깐, 쉬어가기", text: "할 일을 모두 끝내지 않아도\n쉬어갈 자격은 충분해요.\n\n따뜻한 차 한 잔,\n좋아하는 노래 한 곡.\n\n*오늘도 나의 속도로.*", color: .lavender),
        StickyNote(title: "주말의 조각들", text: "## 느슨한 계획 ✨\n\n1. 늦잠 자고 브런치 먹기\n2. 읽던 책 마저 읽기\n3. 새로운 골목 걸어보기\n\n**계획에 없는 순간도 환영!**", color: .butter)
    ]
}

enum NoteFilter: String, CaseIterable, Identifiable {
    case all, pinned, tasks
    #if os(macOS)
    case desktop
    #endif

    var id: String { rawValue }

    var name: String {
        switch self {
        case .all: "모든 메모"
        case .pinned: "고정한 메모"
        case .tasks: "할 일 메모"
        #if os(macOS)
        case .desktop: "바탕화면에 열린 메모"
        #endif
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .pinned: "star"
        case .tasks: "checklist"
        #if os(macOS)
        case .desktop: "macwindow"
        #endif
        }
    }

    func matches(_ note: StickyNote, desktopIDs: Set<UUID>) -> Bool {
        switch self {
        case .all: true
        case .pinned: note.pinned
        case .tasks: MarkdownBlock.parse(note.text).contains {
            if case .task = $0.kind { return true }
            return false
        }
        #if os(macOS)
        case .desktop: desktopIDs.contains(note.id)
        #endif
        }
    }
}

enum NoteSort: String, CaseIterable, Identifiable {
    case recentlyUpdated, oldest, title, color

    var id: String { rawValue }

    var name: String {
        switch self {
        case .recentlyUpdated: "최근 수정순"
        case .oldest: "오래된순"
        case .title: "제목순"
        case .color: "색상별"
        }
    }

    func precedes(_ lhs: StickyNote, _ rhs: StickyNote, pinnedFirst: Bool) -> Bool {
        if pinnedFirst, lhs.pinned != rhs.pinned { return lhs.pinned }
        switch self {
        case .recentlyUpdated:
            break
        case .oldest:
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        case .title:
            let left = lhs.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let right = rhs.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if left.isEmpty != right.isEmpty { return !left.isEmpty }
            let comparison = left.localizedStandardCompare(right)
            if comparison != .orderedSame { return comparison == .orderedAscending }
        case .color:
            let left = NoteColor.allCases.firstIndex(of: lhs.color) ?? 0
            let right = NoteColor.allCases.firstIndex(of: rhs.color) ?? 0
            if left != right { return left < right }
        }
        // Keep ties deterministic so unrelated redraws don't shuffle cards.
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

@MainActor @Observable
final class NoteStore {
    var notes: [StickyNote] = []
    var storageError: String?
    private let key = "paper.stickyNotes.v1"
    private let defaults: UserDefaults
    private let desktopNotesKey = "paper.desktopNotes.v1"
    @ObservationIgnored private var restoredDesktopNotes = false

    private var savedDesktopNoteIDs: [UUID] = []

    var desktopNoteIDs: [UUID] {
        savedDesktopNoteIDs.filter { id in notes.contains { $0.id == id } }
    }

    func setDesktopNoteOpen(_ id: UUID, isOpen: Bool) {
        var ids = desktopNoteIDs.filter { $0 != id }
        if isOpen, notes.contains(where: { $0.id == id }) { ids.append(id) }
        guard ids != savedDesktopNoteIDs else { return }
        savedDesktopNoteIDs = ids
        defaults.set(ids.map(\.uuidString), forKey: desktopNotesKey)
    }

    func desktopNotesToRestore() -> [UUID] {
        guard !restoredDesktopNotes else { return [] }
        restoredDesktopNotes = true
        return desktopNoteIDs
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        savedDesktopNoteIDs = (defaults.stringArray(forKey: desktopNotesKey) ?? []).compactMap(UUID.init(uuidString:))
        guard let data = defaults.data(forKey: key) else {
            notes = StickyNote.examples
            save()
            return
        }
        do {
            notes = try JSONDecoder().decode([StickyNote].self, from: data)
        } catch {
            storageError = "저장된 메모를 읽지 못했습니다. 기존 데이터는 유지됩니다."
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(notes)
            defaults.set(data, forKey: key)
        } catch {
            storageError = "메모를 저장하지 못했습니다: \(error.localizedDescription)"
        }
    }

    func update(_ note: StickyNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        let existing = notes[index]
        guard existing.title != note.title || existing.text != note.text ||
              existing.color != note.color || existing.pinned != note.pinned else { return }
        var updated = note
        updated.updatedAt = Date()
        notes[index] = updated
        save()
    }

    // Resolve the current value on every access so all windows edit the same note.
    func binding(for id: UUID) -> Binding<StickyNote>? {
        guard let fallback = notes.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.notes.first(where: { $0.id == id }) ?? fallback },
            set: { self.update($0) }
        )
    }

    func add(color: NoteColor = .butter, pinned: Bool = false, text: String = "") -> StickyNote {
        let note = StickyNote(title: "", text: text, color: color, pinned: pinned)
        notes.insert(note, at: 0)
        save()
        return note
    }

    func delete(_ note: StickyNote) {
        setDesktopNoteOpen(note.id, isOpen: false)
        notes.removeAll { $0.id == note.id }
        save()
    }
}

private enum PaperStyle {
    static let ink = Color(red: 0.23, green: 0.25, blue: 0.22)
    static let muted = Color(red: 0.47, green: 0.48, blue: 0.43)
    static let background = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let accent = Color(red: 0.30, green: 0.37, blue: 0.25)
}

struct ContentView: View {
    @Environment(NoteStore.self) private var store
    @State private var search = ""
    @State private var selectedFilter: NoteFilter = .all
    @AppStorage("paper.noteSort") private var noteSort: NoteSort = .recentlyUpdated
    @AppStorage("paper.pinnedFirst") private var pinnedFirst = true
    @State private var selectedColor: NoteColor?
    @State private var editingNote: StickyNote?
    @State private var pendingDelete: StickyNote?

    private var filterCounts: [NoteFilter: Int] {
        let desktopIDs = Set(store.desktopNoteIDs)
        return Dictionary(uniqueKeysWithValues: NoteFilter.allCases.map { filter in
            (filter, store.notes.filter { filter.matches($0, desktopIDs: desktopIDs) }.count)
        })
    }

    private var visibleNotes: [StickyNote] {
        let desktopIDs = Set(store.desktopNoteIDs)
        return store.notes.filter {
            selectedFilter.matches($0, desktopIDs: desktopIDs) &&
            (selectedColor == nil || $0.color == selectedColor) &&
            (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.text.localizedCaseInsensitiveContains(search))
        }.sorted {
            noteSort.precedes($0, $1, pinnedFirst: pinnedFirst)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if geometry.size.width > 760 {
                    BoardSidebar(selectedFilter: $selectedFilter, selectedColor: $selectedColor, counts: filterCounts)
                        .frame(width: 224)
                    Rectangle().fill(PaperStyle.ink.opacity(0.08)).frame(width: 1)
                }
                VStack(spacing: 0) {
                    BoardHeader(search: $search, addNote: {
                        editingNote = store.add(color: selectedColor ?? .butter,
                                                pinned: selectedFilter == .pinned,
                                                text: selectedFilter == .tasks ? "- [ ] " : "")
                    })
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            BoardTitle(filter: selectedFilter, count: visibleNotes.count,
                                       sort: $noteSort, pinnedFirst: $pinnedFirst)
                            ActiveFilterChips(filter: $selectedFilter, color: $selectedColor, search: $search)
                            if geometry.size.width <= 760 {
                                CompactNoteFilters(selection: $selectedFilter, counts: filterCounts)
                                ColorFilters(selectedColor: $selectedColor)
                            }
                            if visibleNotes.isEmpty {
                                ContentUnavailableView {
                                    Label(!search.isEmpty ? "검색 결과가 없어요" :
                                            selectedFilter != .all || selectedColor != nil ? "필터에 맞는 메모가 없어요" : "아직 메모가 없어요",
                                          systemImage: "note.text")
                                } description: {
                                    Text(!search.isEmpty ? "검색어나 필터를 바꿔보세요." :
                                            selectedFilter != .all || selectedColor != nil ? "필터를 바꾸거나 새 메모를 만들어보세요." : "새 메모에 생각을 담아보세요.")
                                } actions: {
                                    if !search.isEmpty || selectedFilter != .all || selectedColor != nil {
                                        Button("필터 초기화") {
                                            search = ""
                                            selectedFilter = .all
                                            selectedColor = nil
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 50)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: geometry.size.width < 450 ? 260 : 245), spacing: 22)], spacing: 24) {
                                    ForEach(visibleNotes) { note in
                                        NoteCard(note: note, open: { editingNote = note }, pin: {
                                            var changed = note
                                            changed.pinned.toggle()
                                            store.update(changed)
                                        }, delete: { pendingDelete = note }, changeColor: { color in
                                            guard var changed = store.notes.first(where: { $0.id == note.id }) else { return }
                                            changed.color = color
                                            store.update(changed)
                                        })
                                    }
                                }
                            }
                        }
                        .padding(geometry.size.width > 760 ? 34 : 22)
                    }
                    HStack {
                        Text("이 기기에 자동 저장")
                        Spacer()
                    }
                    .font(.caption2)
                    .foregroundStyle(PaperStyle.muted)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                }
            }
            .background(PaperStyle.background)
            .foregroundStyle(PaperStyle.ink)
        }
        .tint(PaperStyle.accent)
        .preferredColorScheme(.light)
        .sheet(item: $editingNote) { note in
            if let binding = store.binding(for: note.id) {
                NoteEditor(note: binding)
            }
        }
        .alert("메모를 삭제할까요?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("취소", role: .cancel) { pendingDelete = nil }
            Button("삭제", role: .destructive) {
                if let note = pendingDelete { store.delete(note) }
                pendingDelete = nil
            }
        } message: {
            Text("삭제한 메모는 되돌릴 수 없습니다.")
        }
        .alert("저장 알림", isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
            Button("확인") { store.storageError = nil }
        } message: {
            Text(store.storageError ?? "")
        }
    }
}

private struct BoardSidebar: View {
    @Binding var selectedFilter: NoteFilter
    @Binding var selectedColor: NoteColor?
    let counts: [NoteFilter: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil").font(.title2)
                Text("Paperlet").font(.system(size: 28, weight: .semibold, design: .serif))
            }
            .padding(.vertical, 16)
            VStack(alignment: .leading, spacing: 10) {
                Text("나의 공간").font(.caption).foregroundStyle(PaperStyle.muted).padding(.bottom, 5)
                ForEach(NoteFilter.allCases) { filter in
                    SidebarButton(title: filter.name, icon: filter.icon,
                                  count: counts[filter, default: 0], selected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                Text("색상으로 모아보기").font(.caption).foregroundStyle(PaperStyle.muted)
                ColorFilters(selectedColor: $selectedColor)
                if selectedColor != nil {
                    Button("모든 색상 보기") { selectedColor = nil }
                        .font(.caption).buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(24)
        .background(Color(red: 0.94, green: 0.93, blue: 0.89))
    }
}

private struct SidebarButton: View {
    let title: String
    let icon: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(count)").font(.caption).monospacedDigit()
            }
            .font(.subheadline)
            .padding(12)
            .background(selected ? Color.white.opacity(0.7) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        #if os(macOS)
        .allowsWindowActivationEvents()
        #endif
    }
}

private struct BoardHeader: View {
    @Binding var search: String
    let addNote: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(PaperStyle.muted)
                TextField("메모 검색", text: $search).textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("검색 지우기")
                }
            }
            .padding(11)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: 320)
            Spacer(minLength: 0)
            Button(action: addNote) {
                Label("새 메모", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(PaperStyle.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(PaperStyle.ink.opacity(0.08)).frame(height: 1) }
    }
}

private struct BoardTitle: View {
    let filter: NoteFilter
    let count: Int
    @Binding var sort: NoteSort
    @Binding var pinnedFirst: Bool

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(filter == .all ? "나의 메모 보드" : filter.name)
                .font(.system(.largeTitle, design: .serif).weight(.medium))
            Text("\(count)").font(.title3).foregroundStyle(PaperStyle.muted)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("정렬 기준", selection: $sort) {
                ForEach(NoteSort.allCases) { option in
                    Text(option.name).tag(option)
                }
            }
            Divider()
            Toggle("고정 메모 상단 우선", isOn: $pinnedFirst)
        } label: {
            Label(sort.name, systemImage: "arrow.up.arrow.down")
                .font(.subheadline)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.7), in: Capsule())
        .accessibilityLabel("메모 정렬")
        .accessibilityValue(sort.name)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom) {
                title
                Spacer(minLength: 16)
                sortMenu
            }
            VStack(alignment: .leading, spacing: 14) {
                title
                sortMenu
            }
        }
    }
}

private struct CompactNoteFilters: View {
    @Binding var selection: NoteFilter
    let counts: [NoteFilter: Int]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(NoteFilter.allCases) { filter in
                    Button { selection = filter } label: {
                        HStack(spacing: 6) {
                            Label(filter.name, systemImage: filter.icon)
                            Text("\(counts[filter, default: 0])").monospacedDigit()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(selection == filter ? Color.white.opacity(0.9) : Color.white.opacity(0.4), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(PaperStyle.ink.opacity(selection == filter ? 0.18 : 0.06))
                                .allowsHitTesting(false)
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == filter ? .isSelected : [])
                    #if os(macOS)
                    .allowsWindowActivationEvents()
                    #endif
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct ActiveFilterChips: View {
    @Binding var filter: NoteFilter
    @Binding var color: NoteColor?
    @Binding var search: String

    var body: some View {
        if filter != .all || color != nil || !search.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if filter != .all {
                        FilterChip(title: filter.name, icon: filter.icon) { filter = .all }
                    }
                    if let color {
                        FilterChip(title: color.name, icon: "circle.fill", color: color.color) { self.color = nil }
                    }
                    if !search.isEmpty {
                        FilterChip(title: "검색: \(search)", icon: "magnifyingglass") { search = "" }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let icon: String
    var color: Color = PaperStyle.muted
    let clear: () -> Void

    var body: some View {
        Button(action: clear) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).lineLimit(1)
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.6), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .allowsWindowActivationEvents()
        #endif
        .help("\(title) 해제")
        .accessibilityLabel("\(title) 필터 해제")
    }
}

private struct ColorFilters: View {
    @Binding var selectedColor: NoteColor?
    var body: some View {
        HStack(spacing: 10) {
            ForEach(NoteColor.allCases) { color in
                Button { selectedColor = selectedColor == color ? nil : color } label: {
                    Circle().fill(color.color)
                        .frame(width: 25, height: 25)
                        .overlay {
                            if selectedColor == color { Image(systemName: "checkmark").font(.caption.bold()) }
                        }
                        .overlay { Circle().strokeBorder(PaperStyle.ink.opacity(0.14), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.name)
                .accessibilityAddTraits(selectedColor == color ? .isSelected : [])
            }
        }
    }
}

private struct NoteCard: View {
    @Environment(\.openWindow) private var openWindow
    let note: StickyNote
    let open: () -> Void
    let pin: () -> Void
    let delete: () -> Void
    let changeColor: (NoteColor) -> Void
    @State private var hovering = false

    @ViewBuilder
    private var menuActions: some View {
        Button("메모 편집", systemImage: "pencil", action: open)
        #if os(macOS)
        Button("바탕화면에 띄우기", systemImage: "arrow.up.forward.square") {
            openWindow(id: "desktop-note", value: note.id)
        }
        #endif
        Button(note.pinned ? "보드 고정 해제" : "보드 상단에 고정", systemImage: "star", action: pin)
        Menu("색상 변경") {
            ForEach(NoteColor.allCases) { color in
                Button { changeColor(color) } label: {
                    if note.color == color {
                        Label(color.name, systemImage: "checkmark")
                    } else {
                        Text(color.name)
                    }
                }
            }
        }
        Divider()
        Button("삭제", systemImage: "trash", role: .destructive, action: delete)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(note.color.name).font(.caption).foregroundStyle(PaperStyle.ink.opacity(0.8))
                Spacer()
                Button(action: pin) {
                    Image(systemName: note.pinned ? "star.fill" : "star").font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help(note.pinned ? "보드 고정 해제" : "보드 상단에 고정")
                .accessibilityLabel(note.pinned ? "보드 고정 해제" : "보드 상단에 고정")
                #if os(macOS)
                Button {
                    openWindow(id: "desktop-note", value: note.id)
                } label: {
                    Image(systemName: "arrow.up.forward.square").font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("바탕화면에 띄우기")
                .accessibilityLabel("바탕화면에 띄우기")
                #endif
                Menu {
                    menuActions
                } label: {
                    Image(systemName: "ellipsis").frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("메모 메뉴")
            }
            .padding(.bottom, 16)
            Button(action: open) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(note.title.isEmpty ? "제목 없는 메모" : note.title)
                        .font(.title3.weight(.semibold)).lineLimit(2)
                    NoteCardExcerpt(source: note.text, color: note.color.color)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack {
                Text(note.updatedAt, format: .dateTime.month().day())
                Spacer()
            }
            .font(.caption2).opacity(0.55)
            .padding(.top, 14)
        }
        .padding(22)
        .frame(height: 310)
        .background(note.color.color, in: RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.22)).frame(height: 5) }
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(PaperStyle.ink.opacity(hovering ? 0.18 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: PaperStyle.ink.opacity(hovering ? 0.14 : 0.08), radius: hovering ? 9 : 6, x: 0, y: 5)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .contextMenu { menuActions }
    }
}

private struct NoteCardExcerpt: View {
    let source: String
    let color: Color
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let overflowing = contentHeight > geometry.size.height + 1
            MarkdownBody(source: source.isEmpty ? "여기를 눌러 생각을 적어보세요." : source)
                .font(.subheadline)
                .frame(width: geometry.size.width, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .clipped()
                .overlay(alignment: .bottom) {
                    if overflowing {
                        VStack(spacing: 0) {
                            LinearGradient(colors: [color.opacity(0), color], startPoint: .top, endPoint: .bottom)
                                .frame(height: 24)
                            HStack {
                                Text("더 보기").font(.caption.weight(.medium))
                                Image(systemName: "ellipsis").font(.caption)
                                Spacer()
                            }
                            .padding(.top, 4)
                            .background(color)
                        }
                    }
                }
        }
    }
}

private struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NoteStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Binding var note: StickyNote
    @State private var preview = false
    @State private var confirmingDelete = false
    @FocusState private var focusedField: EditorField?

    private enum EditorField: Hashable {
        case title, body
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("메모", systemImage: "note.text").font(.headline)
                Spacer()
                #if os(macOS)
                Button("바탕화면에 띄우기", systemImage: "arrow.up.forward.square") {
                    openWindow(id: "desktop-note", value: note.id)
                }
                .labelStyle(.iconOnly)
                .help("바탕화면에 띄우기")
                #endif
                Button("삭제", systemImage: "trash", role: .destructive) {
                    confirmingDelete = true
                }
                .labelStyle(.iconOnly)
                .help("메모 삭제")
                Button("완료") { dismiss() }.buttonStyle(.borderedProminent)
            }.padding(20)
            HStack {
                ForEach(NoteColor.allCases) { color in
                    Button { note.color = color } label: {
                        Circle().fill(color.color).frame(width: 28, height: 28)
                            .overlay { if note.color == color { Image(systemName: "checkmark").font(.caption.bold()) } }
                    }
                    .buttonStyle(.plain).accessibilityLabel(color.name)
                }
                Spacer()
                Button { note.pinned.toggle() } label: { Image(systemName: note.pinned ? "star.fill" : "star") }
                    .buttonStyle(.plain).help("보드 상단 고정 전환").accessibilityLabel("보드 상단 고정 전환")
            }.padding(.horizontal, 22).padding(.bottom, 18)
            VStack(alignment: .leading, spacing: 18) {
                TextField("제목 없는 메모", text: $note.title)
                    .font(.title2.bold()).textFieldStyle(.plain)
                    .focused($focusedField, equals: .title)
                Picker("보기 방식", selection: $preview) {
                    Text("작성").tag(false)
                    Text("미리보기").tag(true)
                }.pickerStyle(.segmented)
                Button(preview ? "작성으로 전환" : "미리보기로 전환", systemImage: preview ? "pencil" : "eye") {
                    preview.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .keyboardShortcut("p", modifiers: [.command, .shift])
                if preview {
                    ScrollView {
                        MarkdownBody(source: note.text, onToggleTask: { note.toggleTask(at: $0) })
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled).padding(.vertical, 8)
                    }
                } else {
                    TextEditor(text: $note.text)
                        .focused($focusedField, equals: .body)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel("Markdown 메모 내용")
                    Text("# 제목   **굵게**   - 목록   - [ ] 할 일   > 인용")
                        .font(.caption).foregroundStyle(PaperStyle.muted)
                }
            }
            .padding(22)
            .background(note.color.color)
        }
        .background(PaperStyle.background)
        .foregroundStyle(PaperStyle.ink)
        .frame(minWidth: 300, idealWidth: 570, minHeight: 480, idealHeight: 650)
        .onAppear { focusedField = note.title.isEmpty ? .title : .body }
        .onChange(of: preview) { _, showingPreview in
            focusedField = showingPreview ? nil : .body
        }
        .alert("메모를 삭제할까요?", isPresented: $confirmingDelete) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                store.delete(note)
                dismiss()
            }
        } message: {
            Text("삭제한 메모는 되돌릴 수 없습니다.")
        }
    }
}

#if os(macOS)
// Run from either scene, including launches where macOS restores only sticky windows.
struct DesktopNoteRestoration: ViewModifier {
    @Environment(NoteStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.task {
            for id in store.desktopNotesToRestore() {
                openWindow(id: "desktop-note", value: id)
            }
        }
    }
}

// Configure only the window that hosts this view, including its first attachment.
private struct StickyWindowLevel: NSViewRepresentable {
    let alwaysOnTop: Bool
    let noteID: UUID?
    let store: NoteStore

    func makeNSView(context: Context) -> WindowLevelView {
        let view = WindowLevelView()
        view.alwaysOnTop = alwaysOnTop
        view.noteID = noteID
        view.store = store
        return view
    }

    func updateNSView(_ nsView: WindowLevelView, context: Context) {
        nsView.alwaysOnTop = alwaysOnTop
        nsView.applyLevel()
    }

    static func dismantleNSView(_ nsView: WindowLevelView, coordinator: ()) {
        nsView.registrationTask?.cancel()
        NotificationCenter.default.removeObserver(nsView)
    }

    final class WindowLevelView: NSView {
        var alwaysOnTop = false
        var noteID: UUID?
        weak var store: NoteStore?
        var registrationTask: Task<Void, Never>?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard let window, let noteID else { return }
            let frameName = "Paperlet.sticky.\(noteID.uuidString)"
            window.setFrameUsingName(frameName)
            window.setFrameAutosaveName(frameName)
            // Attaching the AppKit view can happen during a SwiftUI update.
            registrationTask?.cancel()
            registrationTask = Task { @MainActor [weak self] in
                guard !Task.isCancelled, let self, self.window != nil else { return }
                self.store?.setDesktopNoteOpen(noteID, isOpen: true)
            }
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowWillClose),
                name: NSWindow.willCloseNotification, object: window)
            applyLevel()
        }

        @objc private func windowWillClose() {
            registrationTask?.cancel()
            // Quitting must retain the session; closing one window must remove it.
            guard !PaperletAppDelegate.isTerminating, let noteID else { return }
            store?.setDesktopNoteOpen(noteID, isOpen: false)
        }

        func applyLevel() {
            window?.level = alwaysOnTop ? .floating : .normal
            window?.hidesOnDeactivate = false
            window?.standardWindowButton(.closeButton)?.isHidden = true
            window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window?.standardWindowButton(.zoomButton)?.isHidden = true
        }
    }
}

struct DesktopNoteWindow: View {
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage private var alwaysOnTop: Bool
    @AppStorage private var isLocked: Bool
    let noteID: UUID?

    init(noteID: UUID?) {
        self.noteID = noteID
        _alwaysOnTop = AppStorage(wrappedValue: false, "paper.desktopNote.\(noteID?.uuidString ?? "unknown").alwaysOnTop")
        _isLocked = AppStorage(wrappedValue: false, "paper.desktopNote.\(noteID?.uuidString ?? "unknown").isLocked")
    }

    private var noteExists: Bool {
        store.notes.contains { $0.id == noteID }
    }

    var body: some View {
        Group {
            if let noteID, let note = store.binding(for: noteID) {
                DesktopNoteContent(note: note, alwaysOnTop: $alwaysOnTop, isLocked: $isLocked)
            } else {
                ContentUnavailableView("메모가 없습니다", systemImage: "note.text",
                                       description: Text("보드에서 메모를 다시 열어주세요."))
            }
        }
        .frame(minWidth: 280, minHeight: 260)
        .preferredColorScheme(.light)
        .tint(PaperStyle.accent)
        .background(StickyWindowLevel(alwaysOnTop: alwaysOnTop, noteID: noteID, store: store))
        .toolbarVisibility(.hidden, for: .windowToolbar)
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: noteExists) { _, exists in
            if !exists { dismiss() }
        }
        .alert("저장 알림", isPresented: Binding(
            get: { store.storageError != nil },
            set: { if !$0 { store.storageError = nil } }
        )) {
            Button("확인") { store.storageError = nil }
        } message: {
            Text(store.storageError ?? "")
        }
    }
}

// Observe this particular window, so switching between notes also changes modes.
private struct NoteWindowFocus: NSViewRepresentable {
    @Binding var isActive: Bool

    func makeNSView(context: Context) -> FocusView {
        let view = FocusView()
        view.onChange = { isActive = $0 }
        return view
    }

    func updateNSView(_ nsView: FocusView, context: Context) {
        nsView.onChange = { isActive = $0 }
    }

    static func dismantleNSView(_ nsView: FocusView, coordinator: ()) {
        nsView.stopObserving()
    }

    final class FocusView: NSView {
        var onChange: ((Bool) -> Void)?
        private var initialUpdate: Task<Void, Never>?
        private var activationUpdate: Task<Void, Never>?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            let center = NotificationCenter.default
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                center.addObserver(self, selector: #selector(focusChanged), name: name, object: window)
            }
            for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
                center.addObserver(self, selector: #selector(focusChanged), name: name, object: nil)
            }
            // Initial attachment can happen during a SwiftUI update.
            initialUpdate = Task { @MainActor [weak self] in
                guard !Task.isCancelled else { return }
                self?.focusChanged()
            }
        }

        @objc private func focusChanged() {
            activationUpdate?.cancel()
            let active = window?.isKeyWindow == true && NSApp.isActive
            guard active, NSEvent.pressedMouseButtons & 1 != 0 else {
                onChange?(active)
                return
            }
            // Let the read-mode checkbox finish its activating click before showing the editor.
            activationUpdate = Task { @MainActor [weak self] in
                while NSEvent.pressedMouseButtons & 1 != 0 {
                    do {
                        try await Task.sleep(for: .milliseconds(16))
                    } catch {
                        return
                    }
                }
                guard !Task.isCancelled, let self else { return }
                self.onChange?(self.window?.isKeyWindow == true && NSApp.isActive)
            }
        }

        func stopObserving() {
            initialUpdate?.cancel()
            initialUpdate = nil
            activationUpdate?.cancel()
            activationUpdate = nil
            NotificationCenter.default.removeObserver(self)
        }
    }
}

private struct DesktopNoteContent: View {
    @Binding var note: StickyNote
    @Binding var alwaysOnTop: Bool
    @Binding var isLocked: Bool
    @State private var isWindowActive = false

    private var editing: Bool { isWindowActive && !isLocked }
    @State private var hovering = false
    @State private var titleSelection: TextSelection?
    @State private var bodySelection: TextSelection?
    @State private var lastFocusedField: EditorField = .body
    @FocusState private var focusedField: EditorField?

    private enum EditorField: Hashable {
        case title, body
    }

    var body: some View {
        VStack(spacing: 0) {
            StickyNoteHeader(color: $note.color, alwaysOnTop: $alwaysOnTop, isLocked: $isLocked, hovering: hovering)
            // Keep both surfaces mounted to retain selection, undo and scroll state.
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("제목 없는 메모", text: $note.title, selection: $titleSelection)
                        .font(.title3.bold()).textFieldStyle(.plain)
                        .focused($focusedField, equals: .title)
                    TextEditor(text: $note.text, selection: $bodySelection)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel("Markdown 메모 내용")
                        .focused($focusedField, equals: .body)
                }
                .disabled(!editing)
                .opacity(editing ? 1 : 0)
                .allowsHitTesting(editing)
                .accessibilityHidden(!editing)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(note.title.isEmpty ? "제목 없는 메모" : note.title).font(.title3.bold())
                        MarkdownBody(source: note.text.isEmpty ? (isLocked ? "잠금을 해제해 생각을 적어보세요." : "메모를 클릭해 생각을 적어보세요.") : note.text,
                                     onToggleTask: { note.toggleTask(at: $0) })
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                .opacity(editing ? 0 : 1)
                .allowsHitTesting(!editing)
                .accessibilityHidden(editing)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(note.color.color)
        .foregroundStyle(PaperStyle.ink)
        .navigationTitle(note.title.isEmpty ? "스티커 메모" : note.title)
        .onHover { hovering = $0 }
        .background(NoteWindowFocus(isActive: $isWindowActive))
        .onChange(of: focusedField) { _, field in
            if let field { lastFocusedField = field }
        }
        .onChange(of: editing) { _, active in
            focusedField = active ? lastFocusedField : nil
        }
    }
}

private struct StickyNoteHeader: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Binding var color: NoteColor
    @Binding var alwaysOnTop: Bool
    @Binding var isLocked: Bool
    let hovering: Bool

    var body: some View {
        ZStack {
            // The adhesive strip also provides a broad window drag surface.
            Rectangle()
                .fill(LinearGradient(
                    colors: [PaperStyle.ink.opacity(0.075), PaperStyle.ink.opacity(0.04), PaperStyle.ink.opacity(0.015)],
                    startPoint: .top, endPoint: .bottom))
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                .help("드래그하여 메모 이동")
                .accessibilityLabel("메모 창 이동")
            HStack(spacing: 4) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 28, height: 28).contentShape(Rectangle())
                }
                .background(PaperStyle.ink.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 5))
                .help("창 닫기 · 메모는 보드에 유지됩니다")
                .accessibilityLabel("메모 창 닫기")
                .opacity(hovering ? 1 : 0.3)
                Spacer(minLength: 24)
                Button {
                    openWindow(id: "board")
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .help("메모 보드 열기")
                .accessibilityLabel("메모 보드 열기")
                .opacity(hovering ? 1 : 0.3)
                .allowsWindowActivationEvents()
                Button { isLocked.toggle() } label: {
                    Image(systemName: isLocked ? "lock.fill" : "lock.open")
                        .frame(width: 28, height: 28)
                        .background(PaperStyle.ink.opacity(isLocked ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 5))
                        .contentShape(Rectangle())
                }
                .opacity(hovering || isLocked ? 1 : 0.3)
                .help(isLocked ? "바탕화면 편집 잠금 해제 · 할 일 체크는 가능" : "바탕화면 편집 잠금 · 할 일 체크는 가능")
                .accessibilityLabel(isLocked ? "바탕화면 편집 잠금 해제" : "바탕화면 편집 잠금")
                .accessibilityValue(isLocked ? "잠김 · 할 일 체크는 가능" : "잠금 해제됨")
                .allowsWindowActivationEvents()
                Button { alwaysOnTop.toggle() } label: {
                    Image(systemName: alwaysOnTop ? "pin.fill" : "pin")
                        .frame(width: 28, height: 26)
                        .background(PaperStyle.ink.opacity(alwaysOnTop ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 5))
                        .contentShape(Rectangle())
                }
                .opacity(hovering || alwaysOnTop ? 1 : 0.3)
                .accessibilityValue(alwaysOnTop ? "켜짐" : "꺼짐")
                .help(alwaysOnTop ? "항상 위에 표시 끄기" : "항상 위에 표시 켜기")
                .accessibilityLabel(alwaysOnTop ? "항상 위에 표시 끄기" : "항상 위에 표시 켜기")
                Menu {
                    Picker("메모 색상", selection: $color) {
                        ForEach(NoteColor.allCases) { color in Text(color.name).tag(color) }
                    }
                } label: {
                    Image(systemName: "circle.lefthalf.filled").frame(width: 24, height: 28)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .background(PaperStyle.ink.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 5))
                .help("메모 색상")
                .accessibilityLabel("메모 색상")
                .opacity(hovering ? 1 : 0.3)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(PaperStyle.ink)
            .padding(.horizontal, 7)
        }
        .frame(height: 34)
        .background(color.color)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.18)).frame(height: 1).allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.15), value: hovering)
    }
}

#endif

// Block layout is explicit because SwiftUI Text renders inline Markdown attributes only.
private struct MarkdownBlock: Identifiable {
    let id: Int
    var text: String
    var kind: Kind
    enum Kind { case paragraph, heading(Int), bullet, ordered(String), task(Bool), quote, code, divider }

    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var codeLines: [String] = []
        var inCode = false
        for (index, raw) in source.components(separatedBy: "\n").enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(MarkdownBlock(id: index, text: codeLines.joined(separator: "\n"), kind: .code))
                    codeLines = []
                }
                inCode.toggle()
                continue
            }
            if inCode { codeLines.append(raw); continue }
            var text = line
            var kind: Kind = .paragraph
            let hashes = line.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") {
                kind = .heading(hashes); text = String(line.dropFirst(hashes + 1))
            } else if line == "- [ ]" || line.lowercased() == "- [x]" ||
                        line.hasPrefix("- [ ] ") || line.lowercased().hasPrefix("- [x] ") {
                kind = .task(line.lowercased().hasPrefix("- [x]")); text = String(line.dropFirst(6))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                kind = .bullet; text = String(line.dropFirst(2))
            } else if line.hasPrefix("> ") {
                kind = .quote; text = String(line.dropFirst(2))
            } else if ["---", "***", "___"].contains(line) {
                kind = .divider
            } else if let dot = line.firstIndex(of: "."), !line[..<dot].isEmpty,
                      line[..<dot].allSatisfy(\.isNumber), line[dot...].hasPrefix(". ") {
                kind = .ordered(String(line[...dot])); text = String(line[line.index(dot, offsetBy: 2)...])
            }
            blocks.append(MarkdownBlock(id: index, text: text, kind: kind))
        }
        if inCode {
            blocks.append(MarkdownBlock(id: source.components(separatedBy: "\n").count, text: codeLines.joined(separator: "\n"), kind: .code))
        }
        return blocks
    }
}

private struct MarkdownBody: View {
    let source: String
    var onToggleTask: ((Int) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(MarkdownBlock.parse(source)) { block in
                MarkdownRow(block: block, onToggleTask: onToggleTask)
            }
        }
    }
}

private struct MarkdownRow: View {
    let block: MarkdownBlock
    var onToggleTask: ((Int) -> Void)? = nil

    private var attributed: AttributedString {
        (try? AttributedString(markdown: block.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(block.text)
    }
    var body: some View {
        switch block.kind {
        case .heading(let level):
            Text(attributed).font(level == 1 ? .title2 : level == 2 ? .title3 : .headline).fontWeight(.semibold)
        case .bullet:
            HStack(alignment: .top, spacing: 8) { Text("•"); Text(attributed) }
        case .ordered(let number):
            HStack(alignment: .top, spacing: 8) { Text(number).monospacedDigit(); Text(attributed) }
        case .task(let done):
            HStack(alignment: .top, spacing: 8) {
                if let onToggleTask {
                    Button { onToggleTask(block.id) } label: {
                        Image(systemName: done ? "checkmark.square.fill" : "square")
                            .padding(.top, 2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(block.text)
                    .accessibilityValue(done ? "완료" : "미완료")
                    .help(done ? "미완료로 표시" : "완료로 표시")
                    #if os(macOS)
                    .allowsWindowActivationEvents()
                    #endif
                } else {
                    Image(systemName: done ? "checkmark.square.fill" : "square").padding(.top, 2)
                }
                Text(attributed).strikethrough(done).opacity(done ? 0.55 : 1)
            }
        case .quote:
            HStack(spacing: 10) {
                Rectangle().fill(PaperStyle.ink.opacity(0.3)).frame(width: 3)
                Text(attributed).italic().foregroundStyle(PaperStyle.muted)
            }.fixedSize(horizontal: false, vertical: true)
        case .code:
            Text(block.text).font(.system(.caption, design: .monospaced))
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        case .divider:
            Divider().padding(.vertical, 4)
        case .paragraph:
            if block.text.isEmpty { Color.clear.frame(height: 5) } else { Text(attributed) }
        }
    }
}

#if os(macOS)
#Preview("포스트잇 메모") {
    DesktopNoteContent(note: .constant(StickyNote.examples[0]), alwaysOnTop: .constant(false), isLocked: .constant(false))
        .frame(width: 340, height: 400)
}
#endif

#Preview {
    ContentView()
        .environment(NoteStore())
        .frame(width: 1120, height: 800)
}
#Preview("좁은 메모 보드") {
    ContentView()
        .environment(NoteStore())
        .frame(width: 700, height: 800)
}

