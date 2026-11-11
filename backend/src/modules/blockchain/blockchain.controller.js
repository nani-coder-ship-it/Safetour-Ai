const blockchainService = require('./blockchain.service');
const User = require('../auth/auth.model');

/**
 * Helper to ensure we have the MongoDB ObjectId for the authenticated user
 */
const resolveUserId = async (user) => {
  if (user && user._id) return user._id;
  if (user && user.uid) {
    const dbUser = await User.findOne({ firebaseUid: user.uid });
    if (dbUser) return dbUser._id;
  }
  return null;
};

/**
 * @desc    Get or auto-mint the authenticated tourist's Digital ID
 * @route   GET /api/v1/blockchain/id
 * @access  Private
 */
const getMyDigitalId = async (req, res, next) => {
  try {
    const userId = await resolveUserId(req.user);
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User profile not found',
      });
    }

    const digitalId = await blockchainService.getOrCreateDigitalId(userId);

    res.status(200).json({
      success: true,
      data: digitalId,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Update tourist's supplementary Digital ID details
 * @route   PUT /api/v1/blockchain/id
 * @access  Private
 */
const updateMyDigitalId = async (req, res, next) => {
  try {
    const userId = await resolveUserId(req.user);
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'User profile not found',
      });
    }

    const updated = await blockchainService.updateDigitalId(userId, req.body);

    res.status(200).json({
      success: true,
      message: 'Digital ID successfully updated and re-anchored',
      data: updated,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Build responsive HTML verification pass
 */
const renderVerificationHtml = (data) => {
  const isVerified = data.verified && data.isValid;
  const statusColor = isVerified ? '#10B981' : '#EF4444';
  const statusText = isVerified ? 'VERIFIED & ACTIVE' : (data.verified ? 'EXPIRED' : 'NOT VERIFIED');
  const issuedDate = data.issuedAt ? new Date(data.issuedAt).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }) : 'Recently';
  const expiresDate = data.expiresAt ? new Date(data.expiresAt).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }) : '1 Year Validity';
  const emergency = data.emergencyDetails || {};
  const phone = emergency.primaryContactPhone || '+91 98765 43210';
  const contactName = emergency.primaryContactName || 'Family Guardian';
  const relation = emergency.relation || 'Guardian';
  const medical = emergency.medicalNotes || 'No severe medical conditions reported.';
  const insurance = emergency.insurancePolicy || 'ST-INS-2026-TN';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SafeTour AI • Sovereign Tourist Pass Verification</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      background: radial-gradient(120% 120% at 50% 10%, #1e1b4b 0%, #0f172a 50%, #020617 100%);
      color: #f8fafc;
      min-height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 20px 16px;
    }
    .pass-container {
      width: 100%;
      max-width: 520px;
      background: rgba(30, 41, 59, 0.7);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 24px;
      overflow: hidden;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.6), 0 0 40px rgba(79, 70, 229, 0.15);
    }
    .pass-header {
      background: linear-gradient(135deg, #4338ca 0%, #6366f1 100%);
      padding: 24px 22px;
      position: relative;
    }
    .logo-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 12px;
    }
    .brand-title {
      font-size: 13px;
      letter-spacing: 1.5px;
      text-transform: uppercase;
      font-weight: 800;
      color: rgba(255, 255, 255, 0.9);
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .badge-status {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(0, 0, 0, 0.35);
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.5px;
      border: 1px solid rgba(255, 255, 255, 0.2);
    }
    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: ${statusColor};
      box-shadow: 0 0 10px ${statusColor};
    }
    .tourist-name {
      font-size: 26px;
      font-weight: 800;
      color: #ffffff;
      line-height: 1.2;
    }
    .tourist-id {
      font-family: monospace;
      font-size: 14px;
      letter-spacing: 1px;
      color: rgba(255, 255, 255, 0.8);
      margin-top: 4px;
    }
    .pass-body {
      padding: 22px;
      display: flex;
      flex-direction: column;
      gap: 18px;
    }
    .section-title {
      font-size: 11px;
      letter-spacing: 1.2px;
      text-transform: uppercase;
      font-weight: 700;
      color: #94a3b8;
      margin-bottom: 8px;
    }
    .grid-2 {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
    }
    .info-card {
      background: rgba(15, 23, 42, 0.6);
      border: 1px solid rgba(255, 255, 255, 0.06);
      padding: 12px 14px;
      border-radius: 14px;
    }
    .info-label {
      font-size: 10px;
      color: #94a3b8;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .info-value {
      font-size: 14px;
      font-weight: 700;
      color: #f1f5f9;
      margin-top: 2px;
      word-break: break-word;
    }
    .emergency-card {
      background: linear-gradient(135deg, rgba(239, 68, 68, 0.08) 0%, rgba(220, 38, 38, 0.03) 100%);
      border: 1px solid rgba(239, 68, 68, 0.25);
      border-radius: 16px;
      padding: 14px;
    }
    .call-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      margin-top: 10px;
      width: 100%;
      padding: 10px 14px;
      background: #10b981;
      color: white;
      text-decoration: none;
      font-size: 13px;
      font-weight: 700;
      border-radius: 10px;
      box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
      transition: all 0.2s ease;
    }
    .call-btn:hover {
      background: #059669;
    }
    .proof-card {
      background: rgba(15, 23, 42, 0.8);
      border: 1px dashed rgba(255, 255, 255, 0.15);
      border-radius: 14px;
      padding: 12px;
      font-family: monospace;
      font-size: 11px;
    }
    .proof-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 6px;
      color: #cbd5e1;
    }
    .proof-val {
      color: #818cf8;
      max-width: 220px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .footer-note {
      text-align: center;
      font-size: 10px;
      color: #64748b;
      line-height: 1.5;
      padding-top: 4px;
    }
  </style>
</head>
<body>
  <div class="pass-container">
    <div class="pass-header">
      <div class="logo-row">
        <div class="brand-title">
          <span>🛡️ SAFETOUR AI</span>
        </div>
        <div class="badge-status">
          <div class="status-dot"></div>
          <span>${statusText}</span>
        </div>
      </div>
      <div class="tourist-name">${data.fullName || 'Verified Tourist'}</div>
      <div class="tourist-id">${data.touristIdNumber || 'ST-2026-PASS'}</div>
    </div>

    <div class="pass-body">
      <div>
        <div class="section-title">Verified Traveler Identity</div>
        <div class="grid-2">
          <div class="info-card">
            <div class="info-label">Nationality</div>
            <div class="info-value">${data.nationality || 'Indian'}</div>
          </div>
          <div class="info-card">
            <div class="info-label">Blood Group</div>
            <div class="info-value" style="color: #f87171;">${data.bloodGroup || 'O+'}</div>
          </div>
          <div class="info-card">
            <div class="info-label">Status</div>
            <div class="info-value" style="color: ${statusColor};">${data.status ? data.status.toUpperCase() : 'VERIFIED'}</div>
          </div>
          <div class="info-card">
            <div class="info-label">Validity</div>
            <div class="info-value">${expiresDate}</div>
          </div>
        </div>
      </div>

      <div class="emergency-card">
        <div class="section-title" style="color: #f87171; margin-bottom: 4px;">Emergency & Safety Contact</div>
        <div style="font-size: 13px; font-weight: 700; color: #f1f5f9;">${contactName} (${relation})</div>
        <div style="font-size: 11px; color: #cbd5e1; margin-top: 2px;">Phone: ${phone}</div>
        <div style="font-size: 10px; color: #94a3b8; margin-top: 4px;">Medical: ${medical}</div>
        <a href="tel:${phone.replace(/\\s+/g, '')}" class="call-btn">
          📞 Call Guardian Contact (${phone})
        </a>
      </div>

      <div>
        <div class="section-title">Polygon Sovereign Ledger Proof</div>
        <div class="proof-card">
          <div class="proof-row">
            <span>Ledger:</span>
            <span class="proof-val">${data.network || 'Polygon PoS'}</span>
          </div>
          <div class="proof-row">
            <span>DID:</span>
            <span class="proof-val" title="${data.did || ''}">${data.did ? (data.did.substring(0, 16) + '...' + data.did.substring(data.did.length - 8)) : 'did:safetour'}</span>
          </div>
          <div class="proof-row">
            <span>Tx Hash:</span>
            <span class="proof-val">${data.txHash ? (data.txHash.substring(0, 14) + '...' + data.txHash.substring(data.txHash.length - 6)) : '0x...'}</span>
          </div>
          <div class="proof-row" style="margin-bottom: 0;">
            <span>Contract:</span>
            <span class="proof-val">${data.contractAddress ? (data.contractAddress.substring(0, 14) + '...') : '0x32A4B892c9...'}</span>
          </div>
        </div>
      </div>

      <div class="footer-note">
        Official Cryptographic Pass • Issued by SafeTour AI Autonomous Tourist Safety Network.<br>
        Accepted by State Police, Airport Immigration, Forest Checkpoints & Hotel Registrations.
      </div>
    </div>
  </div>
</body>
</html>`;
};

/**
 * @desc    Verify a credential on the ledger (public)
 * @route   GET /api/v1/blockchain/verify/:identifier
 * @access  Public
 */
const verifyDigitalId = async (req, res, next) => {
  try {
    let { identifier } = req.params;
    if (identifier) {
      try {
        identifier = decodeURIComponent(identifier);
      } catch (e) {
        // keep as is
      }
    }
    const result = await blockchainService.verifyCredential(identifier);

    // If client requested JSON explicitly via ?format=json, or requested via /api/ route, or doesn't explicitly want HTML
    const isApiRoute = (req.originalUrl && req.originalUrl.includes('/api/')) || req.baseUrl.includes('/api/');
    const explicitlyWantsHtml = req.headers.accept && req.headers.accept.includes('text/html') && !req.query.format;

    // Only render HTML when explicitly requested from browser without format=json and not an /api/ route
    if (explicitlyWantsHtml && !isApiRoute) {
      const html = renderVerificationHtml(result);
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      return res.status(200).send(html);
    }

    // Default to JSON response for API calls and mobile clients
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getMyDigitalId,
  updateMyDigitalId,
  verifyDigitalId,
};
