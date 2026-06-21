class UserProfile {
  final String uid;
  final String displayName;
  final String avatarEmoji;
  final String? avatarImageDataUrl;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.avatarEmoji,
    this.avatarImageDataUrl,
  });

  bool get isCompleted => displayName.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName.trim(),
        'avatarEmoji': avatarEmoji,
        if (avatarImageDataUrl != null && avatarImageDataUrl!.isNotEmpty)
          'avatarImageDataUrl': avatarImageDataUrl,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        uid: map['uid'] as String? ?? '',
        displayName: (map['displayName'] as String? ?? '').trim(),
        avatarEmoji: (map['avatarEmoji'] as String? ?? '🐣').trim().isEmpty
            ? '🐣'
            : (map['avatarEmoji'] as String? ?? '🐣').trim(),
        avatarImageDataUrl: (map['avatarImageDataUrl'] as String?)?.trim(),
      );

  UserProfile copyWith({
    String? displayName,
    String? avatarEmoji,
    String? avatarImageDataUrl,
    bool clearImage = false,
  }) =>
      UserProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        avatarImageDataUrl:
            clearImage ? null : (avatarImageDataUrl ?? this.avatarImageDataUrl),
      );
}
