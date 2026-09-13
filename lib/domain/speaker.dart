typedef VoiceStatus = ({bool installed, bool offline});

abstract interface class Speaker {
  /// Speaks one word. True when the read ran to the end or failed, false when
  /// [stop] or a newer read cut it. Stops the read in progress first.
  Future<bool> speakWord(String text, String language, {bool slow = false});

  /// Speaks a sentence; [onWord] gets the index of the word being spoken. The
  /// result is the same as for [speakWord].
  Future<bool> speakSentence(
    String text,
    String language, {
    bool slow = false,
    void Function(int word)? onWord,
  });

  /// Cuts the read in progress.
  Future<void> stop();

  /// Whether the phone has a voice for [language] and whether it works offline.
  Future<VoiceStatus> voiceStatus(String language);
}
