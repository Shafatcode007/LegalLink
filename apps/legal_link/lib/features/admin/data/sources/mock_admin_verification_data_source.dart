import '../../domain/entities/advocate_verification_item.dart';

/// In-memory mock data source for Bangladesh legal advocate verification queue.
class MockAdminVerificationDataSource {
  MockAdminVerificationDataSource() {
    _items = [
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
        courtDivision:
            'চট্টগ্রাম মহানগর দায়রা জজ আদালত (Chattogram Sessions Court)',
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
  }

  late List<AdvocateVerificationItem> _items;

  List<AdvocateVerificationItem> get items => List.unmodifiable(_items);

  void updateStatus(String id, VerificationStatus status) {
    _items = _items.map((item) {
      if (item.id == id) {
        return item.copyWith(status: status);
      }
      return item;
    }).toList();
  }
}
