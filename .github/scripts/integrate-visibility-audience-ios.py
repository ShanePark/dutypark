"""One-time, idempotent native integration for PR #422; removed before handoff."""
import ast
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
assert subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip() == 'feat/visibility-audience-preview'

path = ROOT / 'ios/Dutypark/Components/DPVisibilityAudiencePreview.swift'
text = path.read_text()
text = text.replace('DPColor.surface)', 'DPColor.backgroundCard)')
path.write_text(text)

path = ROOT / 'ios/Dutypark/Features/Settings/SettingsView.swift'
text = path.read_text()
if 'DPVisibilityAudiencePreview' not in text:
    start = text.index('private struct VisibilitySettingsModal: View {')
    end = text.index('private struct PolicyView: View {', start)
    text = text[:start] + r'''private struct VisibilitySettingsModal: View {
    @ObservedObject var model: SettingsViewModel
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    @State private var selected: Visibility
    private let options: [Visibility] = [.publicAccess, .friends, .family, .privateAccess]

    init(model: SettingsViewModel, maximumHeight: CGFloat, dismiss: @escaping () -> Void) {
        self.model = model
        self.maximumHeight = maximumHeight
        self.dismiss = dismiss
        _selected = State(initialValue: model.member?.calendarVisibility ?? .friends)
    }

    private var canSave: Bool {
        model.member?.id != nil && !model.isWorking && selected != model.member?.calendarVisibility
    }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            SettingsModalHeader(
                titleKey: "settings.visibility.modalTitle",
                closeDisabled: model.isWorking,
                close: dismiss
            )
        } content: {
            bodyContent
        } footer: {
            SettingsModalActions {
                Button(action: dismiss) {
                    Text(VisibilityAudienceLocalization.string("cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(model.isWorking)

                Button {
                    guard canSave else { return }
                    let ownerID = model.member?.id
                    let value = selected
                    Task {
                        await model.updateVisibility(value)
                        if model.member?.id == ownerID, model.member?.calendarVisibility == value {
                            dismiss()
                        }
                    }
                } label: {
                    Group {
                        if model.isWorking { ProgressView() }
                        else { Text(VisibilityAudienceLocalization.string("save")) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(!canSave)
                .accessibilityIdentifier("settings.visibility.save")
            }
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            SettingsLocalization.text("settings.visibility.modalDescription")
                .font(DPTypography.body)
                .foregroundStyle(DPColor.textSecondary)
            Text(VisibilityAudienceLocalization.string("selectionHint"))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(options, id: \.rawValue) { option in
                visibilityOption(option)
            }
            if let ownerID = model.member?.id {
                DPVisibilityAudiencePreview(ownerID: ownerID, visibility: selected)
            }
        }
        .padding(DPSpacing.large)
    }

    private func visibilityOption(_ option: Visibility) -> some View {
        let isSelected = selected == option
        return Button {
            guard selected != option, !model.isWorking else { return }
            selected = option
            DPHapticCenter.shared.emit(.selection)
        } label: {
            VStack(alignment: .leading, spacing: DPSpacing.small) {
                HStack(spacing: DPSpacing.compact) {
                    Circle().fill(optionColor(option)).frame(width: 12, height: 12)
                    SettingsLocalization.text(optionLabel(option))
                        .font(DPTypography.bodyMedium)
                        .foregroundStyle(DPColor.textPrimary)
                    Spacer()
                    if isSelected { Image(systemName: "checkmark").foregroundStyle(DPColor.accent) }
                }
                SettingsLocalization.text(optionDescription(option))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .padding(.leading, DPSpacing.large)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DPSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? DPColor.accentSoft : DPColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(isSelected ? DPColor.accent : DPColor.borderPrimary, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(model.isWorking)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

''' + text[end:]
    path.write_text(text)

path = ROOT / 'ios/Dutypark/Features/Calendar/CalendarView.swift'
text = path.read_text()
if 'DPVisibilityAudiencePreview' not in text:
    anchor = '''            formRow("calendar.schedule.attachments", alignment: .top) {'''
    assert text.count(anchor) == 1
    text = text.replace(anchor, '''            if model.isMyCalendar, let ownerID = model.me?.id {
                DPVisibilityAudiencePreview(ownerID: ownerID, visibility: visibility, scope: .schedule)
            }

''' + anchor, 1)
    path.write_text(text)

# Keep the new native table and web copy aligned without modifying existing tables.
web_copy = (ROOT / 'frontend/src/i18n/messages/visibilityAudience.ts').read_text()
ko_block, en_block = web_copy.split('const en:', 1)
def parse_copy(block):
    return {key: ast.literal_eval(literal) for key, literal in re.findall(r"^  (\w+): ('(?:[^'\\]|\\.)*'),?$", block, re.MULTILINE)}
ko = parse_copy(ko_block)
en = parse_copy(en_block)
assert ko and set(ko) == set(en)
ko.update(expanded='펼쳐짐', collapsed='접힘')
en.update(expanded='Expanded', collapsed='Collapsed')
catalog = {
    'sourceLanguage': 'en',
    'strings': {
        key: {
            'extractionState': 'manual',
            'localizations': {
                language: {'stringUnit': {'state': 'translated', 'value': copy[key]}}
                for language, copy in [('en', en), ('ko', ko)]
            },
        }
        for key in sorted(ko)
    },
    'version': '1.0',
}
path = ROOT / 'ios/Dutypark/Resources/VisibilityAudience.xcstrings'
path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
print('Scoped iPhone settings/editor integration and matching localized copy are ready.')
