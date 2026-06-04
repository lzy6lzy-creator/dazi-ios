import SwiftUI

struct EventFeedbackView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    let eventId: String

    @State private var rating: Int = 0
    @State private var experienceComment = ""
    @State private var partnerRating: Int = 0
    @State private var partnerComment = ""
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            if submitted {
                thankYouView
            } else {
                feedbackForm
            }
        }
    }

    private var feedbackForm: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "star.bubble")
                        .font(.system(size: 44))
                        .foregroundStyle(AppTheme.primaryColor)

                    Text("活动评价")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("你的评价将帮助我们更好地为你匹配搭子")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("活动体验")
                        .font(.headline)

                    StarRating(rating: $rating)

                    TextField("分享你的活动体验...", text: $experienceComment, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))
                }
                .padding(16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))

                VStack(alignment: .leading, spacing: 12) {
                    Text("搭子评价")
                        .font(.headline)

                    StarRating(rating: $partnerRating)

                    TextField("评价你的搭子...", text: $partnerComment, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMD))

                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("评价完全匿名，对方不可见")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))

                Button {
                    submitFeedback()
                } label: {
                    Text("提交评价")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(rating > 0 ? AppTheme.primaryColor : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
                }
                .disabled(rating == 0)
            }
            .padding()
        }
        .background(AppTheme.backgroundColor)
        .navigationTitle("活动评价")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { dismiss() }
            }
        }
    }

    private var thankYouView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("感谢你的评价！")
                .font(.title2)
                .fontWeight(.bold)

            Text("你的反馈将帮助点点更好地了解你的偏好")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(AppTheme.backgroundColor)
    }

    private func submitFeedback() {
        let fullComment = [experienceComment, partnerComment]
            .filter { !$0.isEmpty }
            .joined(separator: " | ")

        dataStore.submitFeedback(
            eventId: eventId,
            rating: rating,
            comment: fullComment
        )

        withAnimation {
            submitted = true
        }
    }
}

struct StarRating: View {
    @Binding var rating: Int
    var maxRating: Int = 5

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.2)) {
                            rating = star
                        }
                    }
            }
        }
    }
}
