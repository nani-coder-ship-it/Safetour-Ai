import 'package:intl/intl.dart';

class DigitalIdModel {
  final String id;
  final String did;
  final String touristIdNumber;
  final String status;
  final String documentType;

  // Blockchain Anchor
  final String network;
  final String txHash;
  final int blockNumber;
  final String merkleRoot;
  final String signature;
  final String contractAddress;

  // Personal Details
  final String fullName;
  final String nationality;
  final String bloodGroup;
  final String dob;
  final String gender;
  final String idDocumentNumber;

  // Emergency & Medical Details
  final String primaryContactName;
  final String primaryContactPhone;
  final String relation;
  final String medicalNotes;
  final String insurancePolicy;

  // Timestamps & QR
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String qrPayload;

  const DigitalIdModel({
    required this.id,
    required this.did,
    required this.touristIdNumber,
    required this.status,
    required this.documentType,
    required this.network,
    required this.txHash,
    required this.blockNumber,
    required this.merkleRoot,
    required this.signature,
    required this.contractAddress,
    required this.fullName,
    required this.nationality,
    required this.bloodGroup,
    required this.dob,
    required this.gender,
    required this.idDocumentNumber,
    required this.primaryContactName,
    required this.primaryContactPhone,
    required this.relation,
    required this.medicalNotes,
    required this.insurancePolicy,
    required this.issuedAt,
    required this.expiresAt,
    required this.qrPayload,
  });

  factory DigitalIdModel.fromJson(Map<String, dynamic> json) {
    final anchor = json['blockchainAnchor'] as Map<String, dynamic>? ?? {};
    final personal = json['personalDetails'] as Map<String, dynamic>? ?? {};
    final emergency = json['emergencyDetails'] as Map<String, dynamic>? ?? {};

    return DigitalIdModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      did: json['did']?.toString() ?? '',
      touristIdNumber: json['touristIdNumber']?.toString() ?? 'ST-2026-00000',
      status: json['status']?.toString().toLowerCase() ?? 'verified',
      documentType: json['documentType']?.toString() ?? 'GLOBAL_TOURIST_SAFETY_CREDENTIAL',
      network: anchor['network']?.toString() ?? 'Polygon PoS / SafeTour Sovereign Ledger',
      txHash: anchor['txHash']?.toString() ?? '',
      blockNumber: anchor['blockNumber'] is num ? (anchor['blockNumber'] as num).toInt() : 48920114,
      merkleRoot: anchor['merkleRoot']?.toString() ?? '',
      signature: anchor['signature']?.toString() ?? '',
      contractAddress: anchor['contractAddress']?.toString() ?? '',
      fullName: personal['fullName']?.toString() ?? 'Tourist',
      nationality: personal['nationality']?.toString() ?? 'Indian',
      bloodGroup: personal['bloodGroup']?.toString() ?? 'O+',
      dob: personal['dob']?.toString() ?? '1999-08-24',
      gender: personal['gender']?.toString() ?? 'Tourist Verified',
      idDocumentNumber: personal['idDocumentNumber']?.toString() ?? '•••• •••• 5821',
      primaryContactName: emergency['primaryContactName']?.toString() ?? 'Guardian Contact',
      primaryContactPhone: emergency['primaryContactPhone']?.toString() ?? '+91 98765 43210',
      relation: emergency['relation']?.toString() ?? 'Family',
      medicalNotes: emergency['medicalNotes']?.toString() ?? 'No severe drug or food allergies recorded.',
      insurancePolicy: emergency['insurancePolicy']?.toString() ?? 'ST-INS-2026-TN',
      issuedAt: json['issuedAt'] != null
          ? DateTime.tryParse(json['issuedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString()) ?? DateTime.now().add(const Duration(days: 365))
          : DateTime.now().add(const Duration(days: 365)),
      qrPayload: 'http://192.168.29.197:5000/verify/${json['touristIdNumber'] ?? 'ST-2026-PASS'}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'did': did,
      'touristIdNumber': touristIdNumber,
      'status': status,
      'documentType': documentType,
      'blockchainAnchor': {
        'network': network,
        'txHash': txHash,
        'blockNumber': blockNumber,
        'merkleRoot': merkleRoot,
        'signature': signature,
        'contractAddress': contractAddress,
      },
      'personalDetails': {
        'fullName': fullName,
        'nationality': nationality,
        'bloodGroup': bloodGroup,
        'dob': dob,
        'gender': gender,
        'idDocumentNumber': idDocumentNumber,
      },
      'emergencyDetails': {
        'primaryContactName': primaryContactName,
        'primaryContactPhone': primaryContactPhone,
        'relation': relation,
        'medicalNotes': medicalNotes,
        'insurancePolicy': insurancePolicy,
      },
      'issuedAt': issuedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'qrPayload': qrPayload,
    };
  }

  String get maskedDid {
    if (did.length > 20) {
      return '${did.substring(0, 16)}...${did.substring(did.length - 6)}';
    }
    return did;
  }

  String get maskedTxHash {
    if (txHash.length > 16) {
      return '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 6)}';
    }
    return txHash;
  }

  String get formattedIssuedDate {
    return DateFormat('MMM dd, yyyy').format(issuedAt);
  }

  String get formattedExpiryDate {
    return DateFormat('MMM dd, yyyy').format(expiresAt);
  }

  bool get isValid => expiresAt.isAfter(DateTime.now()) && status == 'verified';
}
