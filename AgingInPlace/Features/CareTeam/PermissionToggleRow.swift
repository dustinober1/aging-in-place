import SwiftUI
import SwiftData

struct PermissionToggleRow: View {
    let category: PermissionCategory
    @Bindable var member: CareTeamMember
    @Environment(\.modelContext) private var modelContext

    @State private var showUndoToast: Bool = false
    @State private var rotationTask: Task<Void, Never>?

    private var isGranted: Bool {
        member.grantedCategories.contains(category)
    }

    var body: some View {
        HStack {
            Text(category.displayName)
                .font(.body)
            Spacer()
            Toggle(
                isOn: Binding(
                    get: { isGranted },
                    set: { newValue in
                        handleToggle(newValue: newValue)
                    }
                )
            ) {
                EmptyView()
            }
            .labelsHidden()
            .frame(minWidth: A11y.minTouchTarget, minHeight: A11y.minTouchTarget)
        }
        .frame(minHeight: A11y.minTouchTarget)
        .overlay(alignment: .bottom) {
            if showUndoToast {
                UndoToastView(
                    categoryName: category.displayName,
                    onUndo: {
                        performUndo()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showUndoToast)
    }

    private func handleToggle(newValue: Bool) {
        if newValue {
            // Grant: add category if not already present
            if !member.grantedCategories.contains(category) {
                member.grantedCategories.append(category)
                member.lastModified = Date()
                try? modelContext.save()
            }
        } else {
            // Revoke: remove category, show undo toast, schedule key rotation
            member.grantedCategories.removeAll { $0 == category }
            member.lastModified = Date()
            try? modelContext.save()

            // Cancel any pending rotation from a previous revoke
            rotationTask?.cancel()

            // Show undo toast
            withAnimation {
                showUndoToast = true
            }

            // Schedule key rotation after 3 seconds if not undone
            rotationTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation {
                        showUndoToast = false
                    }
                }

                // Rotate key in background
                try? EncryptionService.rotateKey(for: category)
            }
        }
    }

    private func performUndo() {
        // Cancel scheduled rotation
        rotationTask?.cancel()
        rotationTask = nil

        // Restore category
        if !member.grantedCategories.contains(category) {
            member.grantedCategories.append(category)
            member.lastModified = Date()
            try? modelContext.save()
        }

        withAnimation {
            showUndoToast = false
        }
    }
}

// MARK: - Undo Toast View

private struct UndoToastView: View {
    let categoryName: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(categoryName) access revoked")
                .font(.footnote)
                .foregroundStyle(.white)
            Spacer()
            Button("Undo") {
                onUndo()
            }
            .font(.footnote.bold())
            .foregroundStyle(.white)
            .frame(minWidth: A11y.minTouchTarget, minHeight: A11y.minTouchTarget)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
