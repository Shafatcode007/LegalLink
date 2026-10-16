import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/advocate_verification_item.dart';

export '../models/advocate_verification_item.dart';

/// State representation for the Admin Verification Queue.
class AdminVerificationState {
  const AdminVerificationState({
    required this.items,
    this.isLoading = false,
    this.filter,
    this.errorMessage,
  });

  final List<AdvocateVerificationItem> items;
  final bool isLoading;
  final VerificationStatus? filter;
  final String? errorMessage;

  List<AdvocateVerificationItem> get filteredItems {
    if (filter == null) return items;
    return items.where((item) => item.status == filter).toList();
  }

  int get pendingCount =>
      items.where((item) => item.status == VerificationStatus.pending).length;

  int get approvedCount =>
      items.where((item) => item.status == VerificationStatus.approved).length;

  int get rejectedCount =>
      items.where((item) => item.status == VerificationStatus.rejected).length;

  AdminVerificationState copyWith({
    List<AdvocateVerificationItem>? items,
    bool? isLoading,
    VerificationStatus? filter,
    bool clearFilter = false,
    String? errorMessage,
  }) {
    return AdminVerificationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      filter: clearFilter ? null : (filter ?? this.filter),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Initial mock advocate data for Bangladesh legal context
final List<AdvocateVerificationItem> _mockAdvocates = [
  AdvocateVerificationItem(
    id: 'adv-001',
    fullName: 'এডভোকেট মোহাম্মদ রফিকুল ইসলাম (Mohammad Rafiqul Islam)',
    barCouncilNo: 'BC-DH-2014-8841',
    courtDivision: 'ঢাকা জেলা ও দায়রা জজ আদালত (Dhaka District Court)',
    sanadDocUrl: 'https://storage.legallink.bd/sanad/BC-DH-2014-8841.pdf',
    status: VerificationStatus.pending,
    phone: '+880 1712-345678',
    specialization: 'ফৌজদারি ও জামিন পিটিশন (Criminal & Bail)',
    yearsOfExperience: 10,
    submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  AdvocateVerificationItem(
    id: 'adv-002',
    fullName: 'ব্যারিস্টার নুসরাত জাহান (Barrister Nusrat Jahan)',
    barCouncilNo: 'BC-CTG-2018-4521',
    courtDivision: 'চট্টগ্রাম মহানগর দায়রা জজ আদালত (Chattogram Sessions Court)',
    sanadDocUrl: 'https://storage.legallink.bd/sanad/BC-CTG-2018-4521.pdf',
    status: VerificationStatus.pending,
    phone: '+880 1819-987654',
    specialization: 'দেওয়ানি ও সাইবার আইন (Civil & Cyber Law)',
    yearsOfExperience: 6,
    submittedAt: DateTime.now().subtract(const Duration(hours: 7)),
  ),
  AdvocateVerificationItem(
    id: 'adv-003',
    fullName: 'এডভোকেট কাজী তারিকুল হাসান (Kazi Tariqul Hasan)',
    barCouncilNo: 'BC-SYL-2011-1923',
    courtDivision: 'সিলেট জেলা জজ আদালত ও হাইকোর্ট (Sylhet & High Court)',
    sanadDocUrl: 'https://storage.legallink.bd/sanad/BC-SYL-2011-1923.pdf',
    status: VerificationStatus.pending,
    phone: '+880 1914-112233',
    specialization: 'জরুরি গ্রেপ্তার ও রিমান্ড (Emergency SOS & Remand)',
    yearsOfExperience: 13,
    submittedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  AdvocateVerificationItem(
    id: 'adv-004',
    fullName: 'এডভোকেট আনিসুল হক চৌধুরী (Anisul Haque Chowdhury)',
    barCouncilNo: 'BC-DH-2009-3321',
    courtDivision: 'বাংলাদেশ সুপ্রিম কোর্ট হাইকোর্ট বিভাগ (Supreme Court)',
    sanadDocUrl: 'https://storage.legallink.bd/sanad/BC-DH-2009-3321.pdf',
    status: VerificationStatus.approved,
    phone: '+880 1711-445566',
    specialization: 'সাংবিধানিক রিট ও ফৌজদারি আপিল (Constitutional Writs)',
    yearsOfExperience: 15,
    submittedAt: DateTime.now().subtract(const Duration(days: 4)),
  ),
];

/// Modern Riverpod 3.x Notifier for managing admin verification operations.
class AdminVerificationNotifier extends Notifier<AdminVerificationState> {
  @override
  AdminVerificationState build() {
    return AdminVerificationState(items: _mockAdvocates);
  }

  /// Filter items by status (null = show all)
  void setFilter(VerificationStatus? filter) {
    if (filter == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filter: filter);
    }
  }

  /// Approve advocate and transition state to approved
  Future<void> approve(String id) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 600));

    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(status: VerificationStatus.approved);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated, isLoading: false);
  }

  /// Reject advocate and transition state to rejected
  Future<void> reject(String id) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 600));

    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(status: VerificationStatus.rejected);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated, isLoading: false);
  }

  /// Simulates refreshing data from backend with custom loading metaphor
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 900));
    state = state.copyWith(isLoading: false);
  }

  /// Retrieve a single advocate by ID
  AdvocateVerificationItem? getById(String id) {
    try {
      return state.items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Provider instance for the admin verification queue
final adminVerificationProvider =
    NotifierProvider<AdminVerificationNotifier, AdminVerificationState>(
  AdminVerificationNotifier.new,
);
