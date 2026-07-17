enum AlumniEntrySource {
  adminAdded,
  facultyAdded;

  String get value {
    switch (this) {
      case AlumniEntrySource.adminAdded:
        return 'admin_added';
      case AlumniEntrySource.facultyAdded:
        return 'faculty_added';
    }
  }

  static AlumniEntrySource fromString(String? raw) {
    switch (raw) {
      case 'admin_added':
        return AlumniEntrySource.adminAdded;
      case 'faculty_added':
        return AlumniEntrySource.facultyAdded;
      default:
        return AlumniEntrySource.adminAdded;
    }
  }
}

enum AlumniIndustry {
  softwareDevelopment,
  dataScienceAi,
  cybersecurity,
  hardwareEmbedded,
  academiaResearch,
  entrepreneurship,
  governmentPublicSector,
  financeFintech,
  healthcareTech,
  other;

  String get value {
    switch (this) {
      case AlumniIndustry.softwareDevelopment:
        return 'software_development';
      case AlumniIndustry.dataScienceAi:
        return 'data_science_ai';
      case AlumniIndustry.cybersecurity:
        return 'cybersecurity';
      case AlumniIndustry.hardwareEmbedded:
        return 'hardware_embedded';
      case AlumniIndustry.academiaResearch:
        return 'academia_research';
      case AlumniIndustry.entrepreneurship:
        return 'entrepreneurship';
      case AlumniIndustry.governmentPublicSector:
        return 'government_public_sector';
      case AlumniIndustry.financeFintech:
        return 'finance_fintech';
      case AlumniIndustry.healthcareTech:
        return 'healthcare_tech';
      case AlumniIndustry.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case AlumniIndustry.softwareDevelopment:
        return 'Software Development';
      case AlumniIndustry.dataScienceAi:
        return 'Data Science & AI';
      case AlumniIndustry.cybersecurity:
        return 'Cybersecurity';
      case AlumniIndustry.hardwareEmbedded:
        return 'Hardware & Embedded';
      case AlumniIndustry.academiaResearch:
        return 'Academia & Research';
      case AlumniIndustry.entrepreneurship:
        return 'Entrepreneurship';
      case AlumniIndustry.governmentPublicSector:
        return 'Government & Public Sector';
      case AlumniIndustry.financeFintech:
        return 'Finance & FinTech';
      case AlumniIndustry.healthcareTech:
        return 'Healthcare Tech';
      case AlumniIndustry.other:
        return 'Other';
    }
  }

  static AlumniIndustry fromString(String? raw) {
    switch (raw) {
      case 'software_development':
        return AlumniIndustry.softwareDevelopment;
      case 'data_science_ai':
        return AlumniIndustry.dataScienceAi;
      case 'cybersecurity':
        return AlumniIndustry.cybersecurity;
      case 'hardware_embedded':
        return AlumniIndustry.hardwareEmbedded;
      case 'academia_research':
        return AlumniIndustry.academiaResearch;
      case 'entrepreneurship':
        return AlumniIndustry.entrepreneurship;
      case 'government_public_sector':
        return AlumniIndustry.governmentPublicSector;
      case 'finance_fintech':
        return AlumniIndustry.financeFintech;
      case 'healthcare_tech':
        return AlumniIndustry.healthcareTech;
      case 'other':
      default:
        return AlumniIndustry.other;
    }
  }
}

class AlumniProfile {
  final String id;
  final String fullName;
  final String? profilePhotoUrl;
  final int batchYear;
  final String? studentId;
  final int? graduationYear;
  final double? cgpa;
  final String? thesisTitle;
  final String? notableAchievements;
  final String? currentJobTitle;
  final String? currentCompany;
  final AlumniIndustry? industry;
  final String? currentLocation;
  final int? yearsOfExperience;
  final String? email;
  final String? phone;
  final String? linkedinUrl;
  final String? githubUrl;
  final String? websiteUrl;
  final String? facebookUrl;
  final bool isOpenToMentor;
  final List<String>? mentorAreas;
  final String? mentorAvailability;
  final bool showEmail;
  final bool showPhone;
  final bool showLinkedin;
  final bool showGithub;
  final AlumniEntrySource entrySource;
  final bool isVerified;
  final bool isPublished;
  final String? linkedUserId;
  final String addedBy;
  final String? approvedBy;
  final String? rejectionNote;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;

  AlumniProfile({
    required this.id,
    required this.fullName,
    this.profilePhotoUrl,
    required this.batchYear,
    this.studentId,
    this.graduationYear,
    this.cgpa,
    this.thesisTitle,
    this.notableAchievements,
    this.currentJobTitle,
    this.currentCompany,
    this.industry,
    this.currentLocation,
    this.yearsOfExperience,
    this.email,
    this.phone,
    this.linkedinUrl,
    this.githubUrl,
    this.websiteUrl,
    this.facebookUrl,
    this.isOpenToMentor = false,
    this.mentorAreas,
    this.mentorAvailability,
    this.showEmail = false,
    this.showPhone = false,
    this.showLinkedin = true,
    this.showGithub = true,
    required this.entrySource,
    this.isVerified = false,
    this.isPublished = false,
    this.linkedUserId,
    required this.addedBy,
    this.approvedBy,
    this.rejectionNote,

    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
  });

  AlumniProfile copyWith({
    String? id,
    String? fullName,
    String? profilePhotoUrl,
    int? batchYear,
    String? studentId,
    int? graduationYear,
    double? cgpa,
    String? thesisTitle,
    String? notableAchievements,
    String? currentJobTitle,
    String? currentCompany,
    AlumniIndustry? industry,
    String? currentLocation,
    int? yearsOfExperience,
    String? email,
    String? phone,
    String? linkedinUrl,
    String? githubUrl,
    String? websiteUrl,
    String? facebookUrl,
    bool? isOpenToMentor,
    List<String>? mentorAreas,
    String? mentorAvailability,
    bool? showEmail,
    bool? showPhone,
    bool? showLinkedin,
    bool? showGithub,
    AlumniEntrySource? entrySource,
    bool? isVerified,
    bool? isPublished,
    String? linkedUserId,
    String? addedBy,
    String? approvedBy,
    String? rejectionNote,

    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? approvedAt,
  }) {
    return AlumniProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      batchYear: batchYear ?? this.batchYear,
      studentId: studentId ?? this.studentId,
      graduationYear: graduationYear ?? this.graduationYear,
      cgpa: cgpa ?? this.cgpa,
      thesisTitle: thesisTitle ?? this.thesisTitle,
      notableAchievements: notableAchievements ?? this.notableAchievements,
      currentJobTitle: currentJobTitle ?? this.currentJobTitle,
      currentCompany: currentCompany ?? this.currentCompany,
      industry: industry ?? this.industry,
      currentLocation: currentLocation ?? this.currentLocation,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      isOpenToMentor: isOpenToMentor ?? this.isOpenToMentor,
      mentorAreas: mentorAreas ?? this.mentorAreas,
      mentorAvailability: mentorAvailability ?? this.mentorAvailability,
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      showLinkedin: showLinkedin ?? this.showLinkedin,
      showGithub: showGithub ?? this.showGithub,
      entrySource: entrySource ?? this.entrySource,
      isVerified: isVerified ?? this.isVerified,
      isPublished: isPublished ?? this.isPublished,
      linkedUserId: linkedUserId ?? this.linkedUserId,
      addedBy: addedBy ?? this.addedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionNote: rejectionNote ?? this.rejectionNote,

      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'profile_photo_url': profilePhotoUrl,
      'batch_year': batchYear,
      'student_id': studentId,
      'graduation_year': graduationYear,
      'cgpa': cgpa,
      'thesis_title': thesisTitle,
      'notable_achievements': notableAchievements,
      'current_job_title': currentJobTitle,
      'current_company': currentCompany,
      'industry': industry?.value,
      'current_location': currentLocation,
      'years_of_experience': yearsOfExperience,
      'email': email,
      'phone': phone,
      'linkedin_url': linkedinUrl,
      'github_url': githubUrl,
      'website_url': websiteUrl,
      'facebook_url': facebookUrl,
      'is_open_to_mentor': isOpenToMentor,
      'mentor_areas': mentorAreas,
      'mentor_availability': mentorAvailability,
      'show_email': showEmail,
      'show_phone': showPhone,
      'show_linkedin': showLinkedin,
      'show_github': showGithub,
      'entry_source': entrySource.value,
      'is_verified': isVerified,
      'is_published': isPublished,
      'linked_user_id': linkedUserId,
      'added_by': addedBy,
      'approved_by': approvedBy,
      'rejection_note': rejectionNote,

      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
    };
  }

  factory AlumniProfile.fromMap(Map<String, dynamic> map) {
    return AlumniProfile(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      profilePhotoUrl: map['profile_photo_url'],
      batchYear: map['batch_year'] is int ? map['batch_year'] : int.tryParse(map['batch_year']?.toString() ?? '1') ?? 1,
      studentId: map['student_id'],
      graduationYear: map['graduation_year'] is int ? map['graduation_year'] : int.tryParse(map['graduation_year']?.toString() ?? ''),
      cgpa: map['cgpa'] != null ? double.tryParse(map['cgpa'].toString()) : null,
      thesisTitle: map['thesis_title'],
      notableAchievements: map['notable_achievements'],
      currentJobTitle: map['current_job_title'],
      currentCompany: map['current_company'],
      industry: map['industry'] != null ? AlumniIndustry.fromString(map['industry']) : null,
      currentLocation: map['current_location'],
      yearsOfExperience: map['years_of_experience'] is int ? map['years_of_experience'] : int.tryParse(map['years_of_experience']?.toString() ?? ''),
      email: map['email'],
      phone: map['phone'],
      linkedinUrl: map['linkedin_url'],
      githubUrl: map['github_url'],
      websiteUrl: map['website_url'],
      facebookUrl: map['facebook_url'],
      isOpenToMentor: map['is_open_to_mentor'] == true,
      mentorAreas: map['mentor_areas'] != null ? List<String>.from(map['mentor_areas']) : null,
      mentorAvailability: map['mentor_availability'],
      showEmail: map['show_email'] == true,
      showPhone: map['show_phone'] == true,
      showLinkedin: map['show_linkedin'] != false, // Default to true if not set
      showGithub: map['show_github'] != false, // Default to true if not set
      entrySource: AlumniEntrySource.fromString(map['entry_source']),
      isVerified: map['is_verified'] == true,
      isPublished: map['is_published'] == true,
      linkedUserId: map['linked_user_id'],
      addedBy: map['added_by'] ?? '',
      approvedBy: map['approved_by'],
      rejectionNote: map['rejection_note'],

      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      approvedAt: map['approved_at'] != null ? DateTime.tryParse(map['approved_at']) : null,
    );
  }
}
