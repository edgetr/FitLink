import SwiftUI

struct FilledDataDetailsView: View {
    let details: [String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                        .padding(.top, 24)
                    
                    Text("Auto-Filled Data")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Some details in your plan were automatically filled to ensure completeness. Here's what was adjusted:")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    List {
                        ForEach(details, id: \.self) { detail in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "pencil.and.scribble")
                                    .foregroundStyle(.orange)
                                Text(detail)
                                    .font(.subheadline)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    
                    Spacer()
                    
                    GlassTextPillButton("Got it", isProminent: true) {
                        dismiss()
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FilledDataDetailsView(details: [
        "Day 1 Breakfast: Added cooking time",
        "Day 2 Lunch: Adjusted calories to match goal"
    ])
}
