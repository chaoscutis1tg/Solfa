/// Hệ thống bảo vệ toàn vẹn dữ liệu cục bộ & chống chỉnh sửa gian lận (Anti-Tamper & Clock Guard).
/// - Ký số kiểm tra (Salted Checksum Signature) cho số dư Gem, số Gem đã dùng, lượt ủng hộ và điểm kỷ lục.
/// - Phát hiện hành vi chỉnh sửa trực tiếp file SQLite / SharedPreferences hoặc tua ngược đồng hồ thiết bị.
class SolfaIntegrityGuard {
  static const int _secretSaltA = 0x5A17F09D;
  static const int _secretSaltB = 0x3C8E2B41;

  /// Tính chữ ký toàn vẹn (Hex Signature) cho ví Gem của người dùng.
  static String computeWalletSignature({
    required int supportedCount,
    required int bonusGems,
    required int spentGems,
  }) {
    int hash = 0x811C9DC5;
    final payload =
        'solfa_gem_v1|$supportedCount|$bonusGems|$spentGems|$_secretSaltA|$_secretSaltB';
    for (int i = 0; i < payload.length; i++) {
      hash ^= payload.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    final mixed = ((hash ^ (supportedCount * 131) ^ (bonusGems * 37) ^ (spentGems * 17)) &
            0x7FFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return ' sfg_$mixed'.trim();
  }

  /// Xác thực chữ ký toàn vẹn của ví Gem.
  /// Trả về `true` nếu dữ liệu hợp lệ hoặc chưa có chữ ký (lần đầu nâng cấp).
  static bool verifyWalletSignature({
    required int supportedCount,
    required int bonusGems,
    required int spentGems,
    required String? savedSignature,
  }) {
    if (supportedCount < 0 || bonusGems < 0 || spentGems < 0) {
      return false;
    }
    if (supportedCount > 100000 || bonusGems > 10000000) {
      return false;
    }
    if (savedSignature == null || savedSignature.trim().isEmpty) {
      // Lần đầu tiên khởi tạo chữ ký từ phiên bản cũ -> chỉ chấp nhận nếu số liệu hợp lý
      return supportedCount <= 5000 && bonusGems <= 500000;
    }
    final expected = computeWalletSignature(
      supportedCount: supportedCount,
      bonusGems: bonusGems,
      spentGems: spentGems,
    );
    return savedSignature.trim() == expected;
  }

  /// Kiểm tra chống tua ngược đồng hồ hệ thống (Anti-Clock Rollback).
  /// Trả về `true` nếu thời gian hợp lệ (không bị chỉnh lùi quá 15 phút so với mốc xác thực gần nhất).
  static bool isSystemClockValid({
    required int? lastVerifiedEpochMs,
    required int currentEpochMs,
  }) {
    if (lastVerifiedEpochMs == null || lastVerifiedEpochMs <= 0) {
      return true;
    }
    // Cho phép sai số đồng bộ NTP tối đa 15 phút (900,000 ms)
    const int maxAllowedDriftMs = 15 * 60 * 1000;
    return (currentEpochMs + maxAllowedDriftMs) >= lastVerifiedEpochMs;
  }
}

