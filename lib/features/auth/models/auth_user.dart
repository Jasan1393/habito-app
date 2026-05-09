class AuthUser {
  final int id;
  final String email;
  final String firstName;
  final String middleName;
  final String lastName;
  final String displayName;
  final String phone;
  final String birthday;
  final String address;
  final String contactType;
  final String businessName;
  final String identificationType;
  final String taxNumber;
  final String province;
  final String city;
  final String photoUrl;
  final int? ameliaCustomerId;
  final int? wooCustomerId;
  final String? syncStatus;
  final bool pushNotificationsEnabled;
  final bool pointsEnabled;
  final double pointsBalance;
  final double pointsTotalEarned;
  final String pointsType;
  final String pointsLabel;
  final int? pointsNextGoal;
  final bool pointsRedeemEnabled;
  final bool pointsRedeemProductsEnabled;
  final bool pointsRedeemBookingsEnabled;
  final double pointsRedeemPointsPerUsd;
  final double pointsRedeemMinPoints;
  final double pointsRedeemMaxPercent;

  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    required this.displayName,
    required this.phone,
    required this.birthday,
    required this.address,
    this.contactType = 'individual',
    this.businessName = '',
    this.identificationType = 'cedula',
    this.taxNumber = '',
    this.province = '',
    this.city = '',
    required this.photoUrl,
    this.ameliaCustomerId,
    this.wooCustomerId,
    this.syncStatus,
    this.pushNotificationsEnabled = true,
    this.pointsEnabled = false,
    this.pointsBalance = 0,
    this.pointsTotalEarned = 0,
    this.pointsType = 'mycred_default',
    this.pointsLabel = 'Puntos',
    this.pointsNextGoal,
    this.pointsRedeemEnabled = false,
    this.pointsRedeemProductsEnabled = false,
    this.pointsRedeemBookingsEnabled = false,
    this.pointsRedeemPointsPerUsd = 100,
    this.pointsRedeemMinPoints = 1,
    this.pointsRedeemMaxPercent = 50,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final rawFirstName = readString(['first_name', 'firstName']);
    final explicitMiddleName = readString(['middle_name', 'middleName']);
    final givenNames = _splitGivenNames(
      rawFirstName,
      explicitMiddleName: explicitMiddleName,
    );
    final firstName = givenNames['firstName'] ?? '';
    final middleName = givenNames['middleName'] ?? '';
    final lastName = readString(['last_name', 'lastName']);
    final displayName = readString([
      'display_name',
      'displayName',
      'name',
      'full_name',
    ]);
    final businessName = readString([
      'business_name',
      'businessName',
      'billing_company',
    ]);

    return AuthUser(
      id: _parseInt(json['id']) ?? 0,
      email: readString(['email']),
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      displayName: displayName.isNotEmpty
          ? displayName
          : (businessName.isNotEmpty
              ? businessName
              : '$firstName $middleName $lastName'
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim()),
      phone: readString(['phone', 'mobile', 'phone_number']),
      birthday: readString(['birthday', 'birth_date', 'birthdate']),
      address: readString(['address', 'address_1', 'street_address']),
      contactType: readString([
        'contact_type',
        'contactType',
      ]).isNotEmpty
          ? readString(['contact_type', 'contactType'])
          : 'individual',
      businessName: businessName,
      identificationType: readString([
        'identification_type',
        'identificationType',
      ]).isNotEmpty
          ? readString(['identification_type', 'identificationType'])
          : 'cedula',
      taxNumber: readString([
        'tax_number',
        'taxNumber',
        'document_number',
        'documentNumber',
      ]),
      province: readString([
        'province',
        'billing_state',
        'state',
      ]),
      city: readString([
        'city',
        'billing_city',
      ]),
      photoUrl: readString([
        'photo_url',
        'photoUrl',
        'avatar',
        'avatar_url',
        'profile_image',
      ]),
      ameliaCustomerId: _parseInt(
        json['amelia_customer_id'] ?? json['ameliaCustomerId'],
      ),
      wooCustomerId: _parseInt(
        json['woo_customer_id'] ??
            json['wooCustomerId'] ??
            json['woocommerce_customer_id'] ??
            json['woocommerceCustomerId'],
      ),
      syncStatus: (json['sync_status'] ?? json['syncStatus'])?.toString(),
      pushNotificationsEnabled: _parseBool(
            json['push_notifications_enabled'] ??
                json['pushNotificationsEnabled'],
          ) ??
          true,
      pointsEnabled:
          _parseBool(json['points_enabled'] ?? json['pointsEnabled']) ?? false,
      pointsBalance: _parseDouble(
            json['points_balance'] ?? json['pointsBalance'],
          ) ??
          0,
      pointsTotalEarned: _parseDouble(
            json['points_total_earned'] ?? json['pointsTotalEarned'],
          ) ??
          0,
      pointsType: readString(['points_type', 'pointsType']).isNotEmpty
          ? readString(['points_type', 'pointsType'])
          : 'mycred_default',
      pointsLabel: readString(['points_label', 'pointsLabel']).isNotEmpty
          ? readString(['points_label', 'pointsLabel'])
          : 'Puntos',
      pointsNextGoal: _parseInt(
        json['points_next_goal'] ?? json['pointsNextGoal'],
      ),
      pointsRedeemEnabled: _parseBool(
            json['points_redeem_enabled'] ?? json['pointsRedeemEnabled'],
          ) ??
          false,
      pointsRedeemProductsEnabled: _parseBool(
            json['points_redeem_products_enabled'] ??
                json['pointsRedeemProductsEnabled'],
          ) ??
          false,
      pointsRedeemBookingsEnabled: _parseBool(
            json['points_redeem_bookings_enabled'] ??
                json['pointsRedeemBookingsEnabled'],
          ) ??
          false,
      pointsRedeemPointsPerUsd: _parseDouble(
            json['points_redeem_points_per_usd'] ??
                json['pointsRedeemPointsPerUsd'],
          ) ??
          100,
      pointsRedeemMinPoints: _parseDouble(
            json['points_redeem_min_points'] ?? json['pointsRedeemMinPoints'],
          ) ??
          1,
      pointsRedeemMaxPercent: _parseDouble(
            json['points_redeem_max_percent'] ?? json['pointsRedeemMaxPercent'],
          ) ??
          50,
    );
  }

  AuthUser copyWith({
    int? id,
    String? email,
    String? firstName,
    String? middleName,
    String? lastName,
    String? displayName,
    String? phone,
    String? birthday,
    String? address,
    String? contactType,
    String? businessName,
    String? identificationType,
    String? taxNumber,
    String? province,
    String? city,
    String? photoUrl,
    int? ameliaCustomerId,
    int? wooCustomerId,
    String? syncStatus,
    bool? pushNotificationsEnabled,
    bool? pointsEnabled,
    double? pointsBalance,
    double? pointsTotalEarned,
    String? pointsType,
    String? pointsLabel,
    int? pointsNextGoal,
    bool? pointsRedeemEnabled,
    bool? pointsRedeemProductsEnabled,
    bool? pointsRedeemBookingsEnabled,
    double? pointsRedeemPointsPerUsd,
    double? pointsRedeemMinPoints,
    double? pointsRedeemMaxPercent,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      birthday: birthday ?? this.birthday,
      address: address ?? this.address,
      contactType: contactType ?? this.contactType,
      businessName: businessName ?? this.businessName,
      identificationType: identificationType ?? this.identificationType,
      taxNumber: taxNumber ?? this.taxNumber,
      province: province ?? this.province,
      city: city ?? this.city,
      photoUrl: photoUrl ?? this.photoUrl,
      ameliaCustomerId: ameliaCustomerId ?? this.ameliaCustomerId,
      wooCustomerId: wooCustomerId ?? this.wooCustomerId,
      syncStatus: syncStatus ?? this.syncStatus,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      pointsEnabled: pointsEnabled ?? this.pointsEnabled,
      pointsBalance: pointsBalance ?? this.pointsBalance,
      pointsTotalEarned: pointsTotalEarned ?? this.pointsTotalEarned,
      pointsType: pointsType ?? this.pointsType,
      pointsLabel: pointsLabel ?? this.pointsLabel,
      pointsNextGoal: pointsNextGoal ?? this.pointsNextGoal,
      pointsRedeemEnabled: pointsRedeemEnabled ?? this.pointsRedeemEnabled,
      pointsRedeemProductsEnabled:
          pointsRedeemProductsEnabled ?? this.pointsRedeemProductsEnabled,
      pointsRedeemBookingsEnabled:
          pointsRedeemBookingsEnabled ?? this.pointsRedeemBookingsEnabled,
      pointsRedeemPointsPerUsd:
          pointsRedeemPointsPerUsd ?? this.pointsRedeemPointsPerUsd,
      pointsRedeemMinPoints:
          pointsRedeemMinPoints ?? this.pointsRedeemMinPoints,
      pointsRedeemMaxPercent:
          pointsRedeemMaxPercent ?? this.pointsRedeemMaxPercent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'display_name': displayName,
      'phone': phone,
      'birthday': birthday,
      'address': address,
      'contact_type': contactType,
      'business_name': businessName,
      'identification_type': identificationType,
      'tax_number': taxNumber,
      'province': province,
      'city': city,
      'photo_url': photoUrl,
      'amelia_customer_id': ameliaCustomerId,
      'woo_customer_id': wooCustomerId,
      'sync_status': syncStatus,
      'push_notifications_enabled': pushNotificationsEnabled,
      'points_enabled': pointsEnabled,
      'points_balance': pointsBalance,
      'points_total_earned': pointsTotalEarned,
      'points_type': pointsType,
      'points_label': pointsLabel,
      'points_next_goal': pointsNextGoal,
      'points_redeem_enabled': pointsRedeemEnabled,
      'points_redeem_products_enabled': pointsRedeemProductsEnabled,
      'points_redeem_bookings_enabled': pointsRedeemBookingsEnabled,
      'points_redeem_points_per_usd': pointsRedeemPointsPerUsd,
      'points_redeem_min_points': pointsRedeemMinPoints,
      'points_redeem_max_percent': pointsRedeemMaxPercent,
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static Map<String, String> _splitGivenNames(
    String rawFirstName, {
    String explicitMiddleName = '',
  }) {
    final trimmedFirst = rawFirstName.trim();
    final trimmedMiddle = explicitMiddleName.trim();

    if (trimmedMiddle.isNotEmpty) {
      return {
        'firstName': trimmedFirst,
        'middleName': trimmedMiddle,
      };
    }

    final parts = trimmedFirst
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return const {
        'firstName': '',
        'middleName': '',
      };
    }

    if (parts.length == 1) {
      return {
        'firstName': parts.first,
        'middleName': '',
      };
    }

    return {
      'firstName': parts.first,
      'middleName': parts.sublist(1).join(' '),
    };
  }
}
