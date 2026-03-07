import SwiftUI

/// A reusable header for inspector views.
struct InspectorHeaderView: View {
    let title: String
    let subtitle: String?
    let icon: String?
    var protocolBadge: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    
                    if let protocolBadge {
                        Text(protocolBadge)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

/// A generic card container used for sections in the inspector.
struct SectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content
    
    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A view showing active overrides that allows jump-to-field
struct OverridesSummaryView: View {
    let activeFields: [String]
    let scrollViewProxy: ScrollViewProxy
    
    var body: some View {
        SectionCard(nil) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(Color.orange).frame(width: 8, height: 8).padding(.top, 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Overrides Active (\(activeFields.count))")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.orange)
                    
                    // Wrapping layout for tags -> Simplified to Horizontal Scroll for v1 compilation fix
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(activeFields, id: \.self) { field in
                                Button {
                                    withAnimation {
                                        scrollViewProxy.scrollTo(field, anchor: .center)
                                    }
                                } label: {
                                    Text(field)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// A generic collapsible card container used for sections in the inspector.
struct CollapsibleSectionCard<Content: View, Accessory: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    var isFirstSection: Bool = false
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content
    
    init(
        _ title: String,
        isExpanded: Binding<Bool>,
        isFirstSection: Bool = false,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.isFirstSection = isFirstSection
        self.accessory = accessory
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !isFirstSection {
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 1)
                    .opacity(0.7)
                    .padding(.bottom, 6)
            }
            
            DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                accessory()
            }
        }
        .tint(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension CollapsibleSectionCard where Accessory == EmptyView {
    init(
        _ title: String,
        isExpanded: Binding<Bool>,
        isFirstSection: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.isFirstSection = isFirstSection
        self.accessory = { EmptyView() }
        self.content = content
    }
}
