const mongoose = require('mongoose');

const digitalIdSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    did: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    touristIdNumber: {
      type: String,
      required: true,
      unique: true,
    },
    status: {
      type: String,
      enum: ['verified', 'pending', 'revoked'],
      default: 'verified',
    },
    documentType: {
      type: String,
      default: 'GLOBAL_TOURIST_SAFETY_CREDENTIAL',
    },
    blockchainAnchor: {
      network: {
        type: String,
        default: 'Polygon PoS / SafeTour Sovereign Ledger',
      },
      txHash: {
        type: String,
        required: true,
      },
      blockNumber: {
        type: Number,
        default: 48920114,
      },
      merkleRoot: {
        type: String,
        required: true,
      },
      signature: {
        type: String,
        required: true,
      },
      contractAddress: {
        type: String,
        default: '0x32A4B892c943Fa078cDe72B28B8394eFaB119420',
      },
    },
    personalDetails: {
      fullName: {
        type: String,
        required: true,
      },
      nationality: {
        type: String,
        default: 'Indian',
      },
      bloodGroup: {
        type: String,
        default: 'O+',
      },
      dob: {
        type: String,
        default: '1999-08-24',
      },
      gender: {
        type: String,
        default: 'Not Specified',
      },
      idDocumentNumber: {
        type: String,
        default: '•••• •••• 5821',
      },
    },
    emergencyDetails: {
      primaryContactName: {
        type: String,
        default: 'Family Contact',
      },
      primaryContactPhone: {
        type: String,
        default: '+91 98765 43210',
      },
      relation: {
        type: String,
        default: 'Guardian',
      },
      medicalNotes: {
        type: String,
        default: 'No severe drug or food allergies recorded.',
      },
      insurancePolicy: {
        type: String,
        default: 'ST-INS-2026-IN4928',
      },
    },
    issuedAt: {
      type: Date,
      default: Date.now,
    },
    expiresAt: {
      type: Date,
      default: () => new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // 1 year validity
    },
    qrPayload: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('DigitalId', digitalIdSchema);
