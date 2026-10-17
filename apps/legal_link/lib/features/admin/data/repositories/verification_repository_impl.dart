/// Mock repository implementation for advocate verification.
///
/// In Sprint 1 this holds in-memory mock data. In later sprints it will be
/// replaced by a Supabase-backed implementation that calls `submit_verification`
/// and `admin_decide` RPCs.
library;

import '../../domain/entities/advocate_verification_item.dart';

abstract class VerificationRepository {
  Future<List<AdvocateVerificationItem>> getAll();
  Future<void> approve(String id);
  Future<void> reject(String id, {String? reason});
  Future<void> refresh();
  AdvocateVerificationItem? getById(String id);
}

class VerificationRepositoryImpl implements VerificationRepository {
  final List<AdvocateVerificationItem> _items = [
    AdvocateVerificationItem(
      id: 'adv-001',
      fullName: 'এডভোকেট মোহাম্মদ রফিকুল ইসলাম (Mohammad Rafiqul Islam)',
      barCouncilNo: 'BC-DH-2014-8841',
      sanadUrl: 'https://storage.legallink.bd/sanad/BC-DH-2014-8841.pdf',
      status: VerificationStatus.pending,
      yearsOfExperience: 10,
      specializations: ['ফৌজদারি ও জামিন পিটিশন (Criminal & Bail)'],
      courts: ['ঢাকা জেলা ও দায়রা জজ আদালত (Dhaka District Court)'],
      districts: [],
      languages: ['bn'],
      submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AdvocateVerificationItem(
      id: 'adv-002',
      fullName: 'ব্যারিস্টার নুসরাত জাহান (Barrister Nusrat Jahan)',
      barCouncilNo: 'BC-CTG-2018-4521',
      sanadUrl: 'https://storage.legallink.bd/sanad/BC-CTG-2018-4521.pdf',
      status: VerificationStatus.pending,
      yearsOfExperience: 6,
      specializations: ['দেওয়ানি ও সাইবার আইন (Civil & Cyber Law)'],
      courts: ['চট্টগ্রাম মহানগর দায়রা জজ আদালত (Chattogram Sessions Court)'],
      districts: [],
      languages: ['bn'],
      submittedAt: DateTime.now().subtract(const Duration(hours: 7)),
    ),
    AdvocateVerificationItem(
      id: 'adv-003',
      fullName: 'এডভোকেট কাজী তারিকুল হাসান (Kazi Tariqul Hasan)',
      barCouncilNo: 'BC-SYL-2011-1923',
      sanadUrl: 'https://storage.legallink.bd/sanad/BC-SYL-2011-1923.pdf',
      status: VerificationStatus.pending,
      yearsOfExperience: 13,
      specializations: ['জরুরি গ্রেপ্তার ও রিমান্ড (Emergency SOS & Remand)'],
      courts: ['সিলেট জেলা জজ আদালত ও হাইকোর্ট (Sylhet & High Court)'],
      districts: [],
      languages: ['bn'],
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AdvocateVerificationItem(
      id: 'adv-004',
      fullName: 'এডভোকেট আনিসুল হক চৌধুরী (Anisul Haque Chowdhury)',
      barCouncilNo: 'BC-DH-2009-3321',
      sanadUrl: 'https://storage.legallink.bd/sanad/BC-DH-2009-3321.pdf',
      status: VerificationStatus.approved,
      yearsOfExperience: 15,
      specializations: [
        'সাংবিধানিক রিট ও ফৌজদারি আপিল (Constitutional Writs)'
      ],
      courts: ['বাংলাদেশ সুপ্রিম কোর্ট হাইকোর্ট বিভাগ (Supreme Court)'],
      districts: [],
      languages: ['bn'],
      submittedAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  @override
  Future<List<AdvocateVerificationItem>> getAll() async {
    return List<AdvocateVerificationItem>.from(_items);
  }

  @override
  Future<void> approve(String id) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(status: VerificationStatus.approved);
  }

  @override
  Future<void> reject(String id, {String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(
      status: VerificationStatus.rejected,
      rejectionReason: reason,
    );
  }

  @override
  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 900));
  }

  @override
  AdvocateVerificationItem? getById(String id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
