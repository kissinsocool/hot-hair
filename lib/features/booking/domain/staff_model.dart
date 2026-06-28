class StaffProfile {
  final String id;
  final String name;
  final String role;
  final String experience;
  final int extraServiceFee;
  final String imageUrl;
  final String bio;
  final double rating;
  final List<Review> reviews;

  StaffProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.experience,
    this.extraServiceFee = 0,
    required this.imageUrl,
    required this.bio,
    required this.rating,
    required this.reviews,
  });
}

class Review {
  final String userName;
  final double rating;
  final String comment;
  final String date;
  final List<String> imageUrls;
  final String merchantReply;
  final String merchantReplyDate;

  Review({
    required this.userName,
    required this.rating,
    required this.comment,
    required this.date,
    this.imageUrls = const [],
    this.merchantReply = '',
    this.merchantReplyDate = '',
  });
}

// 统一模拟数据列表，方便全局引用
final List<StaffProfile> mockStaffList = [
  StaffProfile(
    id: '1',
    name: 'Sato 先生',
    role: '首席发型师',
    experience: '8年专业经验 | 擅长极简剪发与质感染发',
    imageUrl: 'assets/images/salon_placeholder.svg',
    bio: '你好！我是 Sato。我致力于通过精准的剪裁和自然的色彩，挖掘每个人潜藏的独特气质。',
    rating: 4.8,
    reviews: [
      Review(
          userName: 'Alice',
          rating: 5,
          comment: '剪得非常自然，强烈推荐！',
          date: '2026-05-20'),
      Review(
          userName: 'Bob',
          rating: 4,
          comment: '服务很细致，染发颜色非常正。',
          date: '2026-05-15'),
    ],
  ),
  StaffProfile(
    id: '2',
    name: 'Yumi 小姐',
    role: '创意总监',
    experience: '10年经验 | 擅长日系轻盈剪裁',
    imageUrl: 'assets/images/salon_placeholder.svg',
    bio: '追求自然与流畅的线条感，让发型成为你穿搭的一部分。',
    rating: 4.9,
    reviews: [],
  ),
  StaffProfile(
    id: '3',
    name: 'Ken 先生',
    role: '色彩专家',
    experience: '6年经验 | 专注于高明度色系',
    imageUrl: 'assets/images/salon_placeholder.svg',
    bio: '色彩是改变心情最快的方式。',
    rating: 4.7,
    reviews: [],
  ),
];

// 保留单个 mockStaff 方便之前的部分代码直接调用
final StaffProfile mockStaff = mockStaffList[0];
