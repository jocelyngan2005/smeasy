/**
 * Firestore Seed Script — MyInvoisMate
 * Project ID: myinvoicemate
 *
 * Usage:
 *   1. Download a service account key from Firebase Console:
 *      Project Settings → Service Accounts → Generate new private key
 *      Save as: scripts/service-account-key.json
 *
 *   2. In this folder run:
 *      npm install
 *      npm run seed                                # seed with default UID 'test-user-001'
 *      npm run seed -- --uid=<your_firebase_uid>   # seed with your real Firebase Auth UID
 *      npm run seed:wipe -- --uid=<uid>            # wipe + re-seed with your real UID
 *
 *   How to find your Firebase Auth UID:
 *     - Sign in to the app and check the Firestore query error in logcat — the UID appears
 *       after "createdBy==" in the error message.
 *     - Or: Firebase Console → Authentication → Users → copy the UID column.
 */

const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id, // read from the key file to avoid mismatches
});

const db = admin.firestore();
// Explicitly target the default database in the correct region
db.settings({ databaseId: '(default)', ignoreUndefinedProperties: true });

const TS = (date) => admin.firestore.Timestamp.fromDate(new Date(date));

const WIPE = process.argv.includes('--wipe');

// --uid=<firebase_uid>  Override the default seed owner UID.
// Use this when your real Firebase Auth UID differs from the placeholder
// (e.g. you saw "createdBy==scP8LrwpCOgBrqJouQxlqAqnsMt2" in a Firestore error).
const UID_ARG = process.argv.find((a) => a.startsWith('--uid='));
const SEED_UID = UID_ARG ? UID_ARG.split('=')[1] : 'test-user-001';

if (SEED_UID !== 'test-user-001') {
  console.log(`\n🔑  Seeding with custom UID: ${SEED_UID}`);
}

/**
 * Deep-replace every 'test-user-001' occurrence with SEED_UID.
 * Uses a recursive walk instead of JSON.stringify so that Firestore Timestamp
 * instances are preserved (JSON.stringify would convert them to plain maps,
 * causing a 'type _Map<String,dynamic> is not a subtype of Timestamp' crash
 * when the Flutter app reads the documents back).
 */
function withUid(data) {
  if (data instanceof admin.firestore.Timestamp) return data;
  if (Array.isArray(data)) return data.map(withUid);
  if (data !== null && typeof data === 'object') {
    return Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, withUid(v)])
    );
  }
  if (typeof data === 'string') return data.split('test-user-001').join(SEED_UID);
  return data;
}

// ─────────────────────────────────────────────
// COLLECTION NAMES (mirrors FirestoreCollections.dart)
// ─────────────────────────────────────────────
const COLLECTIONS = {
  users: 'users',
  invoices: 'invoices',
  customers: 'customers',
  complianceAlerts: 'compliance_alerts',
  complianceQuestions: 'compliance_questions',
  supportLocations: 'support_locations',
  analyticsCache: 'analytics_cache',
};

// ─────────────────────────────────────────────
// SEED DATA
// ─────────────────────────────────────────────

// Shared vendor used across all invoices (represents the SME owner)
const VENDOR = {
  name: 'SME Easy Sdn Bhd',
  tin: 'C1234567890',
  registrationNumber: '202501234567',
  identificationNumber: '000000000000',
  contactNumber: '+60123456789',
  sstNumber: 'SST-0001-20250001',
  email: 'billing@smeasy.my',
  phone: '+60123456789',
  contactPerson: 'Aida Binti Rahman',
  address: {
    line1: 'Unit 5-3, Menara SME',
    line2: 'Jalan Semarak',
    line3: null,
    city: 'Kuala Lumpur',
    state: 'WP Kuala Lumpur',
    postalCode: '50450',
    country: 'MY',
  },
  msicCode: '620',
  businessActivityDescription: 'Information Technology Services',
};

// ── USERS ──────────────────────────────────────────────────────────────────
const USERS = [
  {
    id: 'test-user-001',
    email: 'aida@smeasy.my',
    businessName: 'SME Easy Sdn Bhd',
    businessType: 'Technology Services',
    ssmNumber: '202501234567',
    tin: 'C1234567890',
    phone: '+60123456789',
    address: 'Unit 5-3, Menara SME, Jalan Semarak, 50450 Kuala Lumpur',
    createdAt: TS('2026-01-02T08:00:00'),
    isVerified: true,
  },
  {
    id: 'test-user-002',
    email: 'haziq@techsolutions.my',
    businessName: 'HaziqTech Solutions',
    businessType: 'IT Consulting',
    ssmNumber: '202401987654',
    tin: 'C9876543210',
    phone: '+60112223344',
    address: 'A-12-5, Damansara Perdana, 47820 Petaling Jaya, Selangor',
    createdAt: TS('2026-01-10T09:30:00'),
    isVerified: false,
  },
];

// ── CUSTOMERS ───────────────────────────────────────────────────────────────
const CUSTOMERS = [
  {
    id: 'CUST20260105001',
    name: 'ABC Trading Sdn Bhd',
    tin: 'C9988776655',
    registrationNumber: '201901234567',
    identificationNumber: '000000000000',
    contactNumber: '+60198887766',
    sstNumber: 'SST-0002-20190001',
    email: 'ap@abctrading.my',
    contactPerson: 'Lim Kah Wai',
    addresses: [
      {
        id: 'CUST20260105001_addr_1',
        line1: 'No 9, Jalan Industri 3',
        line2: 'Taman Industri PJ',
        line3: null,
        city: 'Petaling Jaya',
        state: 'Selangor',
        postalCode: '46000',
        country: 'MY',
        isPrimary: true,
        label: 'Primary',
      },
    ],
    invoiceCount: 3,
    totalRevenue: 38272.0,
    lastInvoiceDate: TS('2026-02-15T00:00:00'),
    createdAt: TS('2026-01-05T10:00:00'),
    updatedAt: TS('2026-02-15T10:00:00'),
    createdBy: 'test-user-001',
    isFavorite: true,
    notes: 'Long-term client. Net 30 payment terms.',
  },
  {
    id: 'CUST20260120001',
    name: 'Mega Retail Bhd',
    tin: 'C1122334455',
    registrationNumber: '200901122334',
    identificationNumber: '000000000000',
    contactNumber: '+60322334455',
    sstNumber: 'SST-0003-20090001',
    email: 'procurement@megaretail.my',
    contactPerson: 'Siti Noor',
    addresses: [
      {
        id: 'CUST20260120001_addr_1',
        line1: 'Lot 45, Wisma Mega',
        line2: 'Jalan Raja Laut',
        line3: null,
        city: 'Kuala Lumpur',
        state: 'WP Kuala Lumpur',
        postalCode: '50350',
        country: 'MY',
        isPrimary: true,
        label: 'Primary',
      },
    ],
    invoiceCount: 1,
    totalRevenue: 12720.0,
    lastInvoiceDate: TS('2026-02-01T00:00:00'),
    createdAt: TS('2026-01-20T11:00:00'),
    updatedAt: TS('2026-02-01T11:00:00'),
    createdBy: 'test-user-001',
    isFavorite: false,
    notes: null,
  },
  {
    id: 'CUST20260205001',
    name: 'Primavera Catering & Events',
    tin: 'EI00000000011',
    registrationNumber: null,
    identificationNumber: '810212045678',
    contactNumber: '+60176655443',
    sstNumber: 'NA',
    email: 'primavera.catering@gmail.com',
    contactPerson: 'Nora Binti Aziz',
    addresses: [
      {
        id: 'CUST20260205001_addr_1',
        line1: 'No 3, Lorong Damai 7',
        line2: null,
        line3: null,
        city: 'Ampang',
        state: 'Selangor',
        postalCode: '68000',
        country: 'MY',
        isPrimary: true,
        label: 'Primary',
      },
    ],
    invoiceCount: 1,
    totalRevenue: 4770.0,
    lastInvoiceDate: TS('2026-02-10T00:00:00'),
    createdAt: TS('2026-02-05T09:00:00'),
    updatedAt: TS('2026-02-10T09:00:00'),
    createdBy: 'test-user-001',
    isFavorite: false,
    notes: 'Individual business owner. No SST registration.',
  },
  {
    id: 'CUST20260115001',
    name: 'Greentech Solutions Sdn Bhd',
    tin: 'C5566778899',
    registrationNumber: '201801003344',
    identificationNumber: '000000000000',
    contactNumber: '+60322556677',
    sstNumber: 'SST-0004-20180001',
    email: 'finance@greentech.my',
    contactPerson: 'Raj Kumar',
    addresses: [
      {
        id: 'CUST20260115001_addr_1',
        line1: 'Suite 12-05, Menara Greentech',
        line2: 'Persiaran Multimedia',
        line3: null,
        city: 'Cyberjaya',
        state: 'Selangor',
        postalCode: '63000',
        country: 'MY',
        isPrimary: true,
        label: 'Primary',
      },
    ],
    invoiceCount: 1,
    totalRevenue: 13780.0,
    lastInvoiceDate: TS('2026-01-28T00:00:00'),
    createdAt: TS('2026-01-15T14:00:00'),
    updatedAt: TS('2026-01-28T14:00:00'),
    createdBy: 'test-user-001',
    isFavorite: true,
    notes: 'Requires purchase order reference on all invoices.',
  },
  {
    id: 'CUST20260218001',
    name: 'Northern Star Enterprise',
    tin: 'C3344556677',
    registrationNumber: '202201556677',
    identificationNumber: '000000000000',
    contactNumber: '+60454445566',
    sstNumber: 'NA',
    email: 'accounts@nstar.my',
    contactPerson: 'Chong Wei Liang',
    addresses: [
      {
        id: 'CUST20260218001_addr_1',
        line1: 'No 88, Jalan Perak',
        line2: 'Georgetown',
        line3: null,
        city: 'George Town',
        state: 'Pulau Pinang',
        postalCode: '10000',
        country: 'MY',
        isPrimary: true,
        label: 'Primary',
      },
    ],
    invoiceCount: 0,
    totalRevenue: 0.0,
    lastInvoiceDate: null,
    createdAt: TS('2026-02-18T08:00:00'),
    updatedAt: TS('2026-02-18T08:00:00'),
    createdBy: 'test-user-001',
    isFavorite: false,
    notes: 'Prospect. Follow up due March 2026.',
  },
];

// ── Helper to build a line item ─────────────────────────────────────────────
function lineItem(id, desc, qty, unitPrice, taxRate, taxType, productCode, classification) {
  const subtotal = qty * unitPrice;
  const taxAmount = taxRate ? subtotal * (taxRate / 100) : 0;
  const totalAmount = subtotal + taxAmount;
  return {
    id,
    description: desc,
    quantity: qty,
    unit: 'pcs',
    unitPrice,
    subtotal,
    discountAmount: 0,
    taxRate: taxRate || null,
    taxAmount,
    totalAmount,
    productCode: productCode || null,
    classification: classification || '022', // IRBM 3-digit classification code
    taxType,
  };
}

// ── INVOICES (5) ────────────────────────────────────────────────────────────
// buyer references match customers above for consistency
const buyer = (c) => ({
  name: c.name,
  tin: c.tin,
  registrationNumber: c.registrationNumber || null,
  identificationNumber: c.identificationNumber,
  contactNumber: c.contactNumber,
  sstNumber: c.sstNumber,
  email: c.email,
  phone: c.contactNumber,
  contactPerson: c.contactPerson,
  address: c.addresses[0],
});

const INVOICES = [
  // ── INV20260115001: Accepted (submitted & approved by MyInvois, > RM10k) ────
  (() => {
    const items = [
      lineItem('INV20260115001-LI-1', 'Enterprise Software Subscription (Annual)', 1, 10000, 6, 'sst_6', 'SUB-ENT-01', '022'),
      lineItem('INV20260115001-LI-2', 'Implementation & Setup', 1, 3000, 6, 'sst_6', 'SVC-IMPL-01', '008'),
      lineItem('INV20260115001-LI-3', 'User Training (3 Sessions)', 3, 500, 6, 'sst_6', 'SVC-TRN-01', '013'),
    ];
    const subtotal = items.reduce((s, i) => s + i.subtotal, 0);
    const taxAmount = items.reduce((s, i) => s + i.taxAmount, 0);
    return {
      id: 'INV20260115001',
      invoiceNumber: 'INV20260115001',
      type: 'invoice',
      issueDate: TS('2026-01-15T09:00:00'),
      dueDate: TS('2026-02-14T09:00:00'),
      currency: 'MYR',
      vendor: VENDOR,
      buyer: buyer(CUSTOMERS[0]),
      lineItems: items,
      subtotal,
      taxAmount,
      totalAmount: subtotal + taxAmount,
      discountAmount: 0,
      tin: VENDOR.tin,
      sst: VENDOR.sstNumber,
      complianceStatus: 'valid',
      myInvoisStatus: 2, // LHDN SDK: Valid — successful invoice validation
      myInvoisReferenceId: 'MYINVOIS-2026-ABC123DEF456',
      submissionDate: TS('2026-01-15T11:30:00'),
      isWithinRelaxationPeriod: false,
      requiresSubmission: true,
      shippingRecipient: null,
      notes: 'Annual subscription renewal. PO: PO-ABC-2026-001.',
      metadata: { poNumber: 'PO-ABC-2026-001', aiConfidence: null },
      createdAt: TS('2026-01-15T09:00:00'),
      updatedAt: TS('2026-01-15T11:30:00'),
      createdBy: 'test-user-001',
      source: 'manual',
      isDeleted: false,
    };
  })(),

  // ── INV20260201001: Validated (ready to submit to MyInvois, > RM10k) ────────
  (() => {
    const items = [
      lineItem('INV20260201001-LI-1', 'Cloud Infrastructure Setup', 1, 8000, 6, 'sst_6', 'SVC-CLOUD-01', '008'),
      lineItem('INV20260201001-LI-2', 'Monthly Managed Services (Jan)', 1, 2000, 6, 'sst_6', 'SVC-MGMT-01', '014'),
      lineItem('INV20260201001-LI-3', 'SSL Certificate (1 Year)', 2, 300, 6, 'sst_6', 'PROD-SSL-01', '022'),
    ];
    const subtotal = items.reduce((s, i) => s + i.subtotal, 0);
    const taxAmount = items.reduce((s, i) => s + i.taxAmount, 0);
    return {
      id: 'INV20260201001',
      invoiceNumber: 'INV20260201001',
      type: 'invoice',
      issueDate: TS('2026-02-01T10:00:00'),
      dueDate: TS('2026-03-03T10:00:00'),
      currency: 'MYR',
      vendor: VENDOR,
      buyer: buyer(CUSTOMERS[1]),
      lineItems: items,
      subtotal,
      taxAmount,
      totalAmount: subtotal + taxAmount,
      discountAmount: 0,
      tin: VENDOR.tin,
      sst: VENDOR.sstNumber,
      complianceStatus: 'submitted',
      myInvoisStatus: 1, // LHDN SDK: Submitted — passed initial structure validations, awaiting additional validations
      myInvoisReferenceId: 'MYINVOIS-2026-PEND-002',
      submissionDate: TS('2026-02-01T11:00:00'),
      isWithinRelaxationPeriod: false,
      requiresSubmission: true,
      shippingRecipient: null,
      notes: 'Cloud setup for Mega Retail e-commerce platform. Awaiting MyInvois validation.',
      metadata: { poNumber: null, aiConfidence: null },
      createdAt: TS('2026-02-01T10:00:00'),
      updatedAt: TS('2026-02-01T10:00:00'),
      createdBy: 'test-user-001',
      source: 'manual',
      isDeleted: false,
    };
  })(),

  // ── INV20260210001: Draft (< RM10k, below submission threshold) ─────────────
  (() => {
    const items = [
      lineItem('INV20260210001-LI-1', 'Website Maintenance (Feb 2026) [Ref: RCP-20260210-001]', 1, 1500, null, 'none', 'SVC-WEB-01', '014'),
      lineItem('INV20260210001-LI-2', 'Content Update Service (5 sessions) [Ref: RCP-20260210-002 to RCP-20260210-006]', 5, 300, null, 'none', 'SVC-CONT-01', '008'),
      lineItem('INV20260210001-LI-3', 'SEO Audit Report [Ref: RCP-20260210-007]', 1, 750, null, 'none', 'SVC-SEO-01', '008'),
    ];
    const subtotal = items.reduce((s, i) => s + i.subtotal, 0);
    const taxAmount = 0;
    return {
      id: 'INV20260210001',
      invoiceNumber: 'INV20260210001',
      type: 'invoice',
      issueDate: TS('2026-02-10T14:00:00'),
      dueDate: TS('2026-02-25T14:00:00'),
      currency: 'MYR',
      vendor: VENDOR,
      // Consolidated e-Invoice: mandatory LHDN placeholder values (sub-RM10k, supplier-issued)
      buyer: {
        name: 'General Public',
        tin: 'EI00000000010',
        registrationNumber: 'NA',
        identificationNumber: 'NA',
        contactNumber: 'NA',
        sstNumber: 'NA',
        email: null,
        phone: 'NA',
        contactPerson: null,
        address: {
          line1: 'NA',
          line2: null,
          line3: null,
          city: 'NA',
          state: 'NA',
          postalCode: 'NA',
          country: 'MY',
        },
      },
      lineItems: items,
      subtotal,
      taxAmount,
      totalAmount: subtotal + taxAmount,
      discountAmount: 0,
      tin: VENDOR.tin,
      sst: VENDOR.sstNumber,
      complianceStatus: 'draft',
      myInvoisStatus: 5, // LHDN SDK: Draft — below RM10k threshold, not submitted
      myInvoisReferenceId: null,
      submissionDate: null,
      isWithinRelaxationPeriod: true,
      requiresSubmission: false,
      shippingRecipient: null,
      notes: 'Consolidated e-Invoice (below RM10k threshold). Buyer fields set to LHDN General Public placeholder (EI00000000010). Relaxation period applies.',
      metadata: { aiConfidence: 0.91, originalInput: 'website maintenance and SEO for Primavera' },
      createdAt: TS('2026-02-10T14:00:00'),
      updatedAt: TS('2026-02-10T14:00:00'),
      createdBy: 'test-user-001',
      source: 'voice',
      isDeleted: false,
    };
  })(),

  // ── INV20260128001: Submitted (awaiting MyInvois response, > RM10k) ─────────
  (() => {
    const items = [
      lineItem('INV20260128001-LI-1', 'DevOps Consulting (Jan 2026)', 10, 900, 6, 'sst_6', 'SVC-DEV-01', '008'),
      lineItem('INV20260128001-LI-2', 'CI/CD Pipeline Setup', 1, 2500, 6, 'sst_6', 'SVC-CICD-01', '022'),
      lineItem('INV20260128001-LI-3', 'Server Hardening Audit', 1, 1500, 6, 'sst_6', 'SVC-SEC-01', '008'),
    ];
    const subtotal = items.reduce((s, i) => s + i.subtotal, 0);
    const taxAmount = items.reduce((s, i) => s + i.taxAmount, 0);
    return {
      id: 'INV20260128001',
      invoiceNumber: 'INV20260128001',
      type: 'invoice',
      issueDate: TS('2026-01-28T08:30:00'),
      dueDate: TS('2026-02-27T08:30:00'),
      currency: 'MYR',
      vendor: VENDOR,
      buyer: buyer(CUSTOMERS[3]),
      lineItems: items,
      subtotal,
      taxAmount,
      totalAmount: subtotal + taxAmount,
      discountAmount: 0,
      tin: VENDOR.tin,
      sst: VENDOR.sstNumber,
      complianceStatus: 'submitted',
      myInvoisStatus: 1, // LHDN SDK: Submitted — passed initial structure validations, awaiting additional validations
      myInvoisReferenceId: 'MYINVOIS-2026-PENDING-789',
      submissionDate: TS('2026-01-28T10:00:00'),
      isWithinRelaxationPeriod: false,
      requiresSubmission: true,
      shippingRecipient: null,
      notes: 'PO: PO-GRN-2026-007. Awaiting MyInvois validation.',
      metadata: { poNumber: 'PO-GRN-2026-007', aiConfidence: null },
      createdAt: TS('2026-01-28T08:30:00'),
      updatedAt: TS('2026-01-28T10:00:00'),
      createdBy: 'test-user-001',
      source: 'manual',
      isDeleted: false,
    };
  })(),

  // ── INV20260205001: Rejected (MyInvois rejected due to TIN mismatch) ─────────
  (() => {
    const items = [
      lineItem('INV20260205001-LI-1', 'Annual Support Contract', 1, 6000, 6, 'sst_6', 'SVC-SUP-01', '014'),
      lineItem('INV20260205001-LI-2', 'Disaster Recovery Planning', 1, 4500, 6, 'sst_6', 'SVC-DR-01', '008'),
      lineItem('INV20260205001-LI-3', 'Backup Solution Licence', 2, 750, 6, 'sst_6', 'PROD-BCK-01', '022'),
    ];
    const subtotal = items.reduce((s, i) => s + i.subtotal, 0);
    const taxAmount = items.reduce((s, i) => s + i.taxAmount, 0);
    return {
      id: 'INV20260205001',
      invoiceNumber: 'INV20260205001',
      type: 'invoice',
      issueDate: TS('2026-02-05T13:00:00'),
      dueDate: TS('2026-03-07T13:00:00'),
      currency: 'MYR',
      vendor: VENDOR,
      buyer: buyer(CUSTOMERS[0]), // ABC Trading — re-used
      lineItems: items,
      subtotal,
      taxAmount,
      totalAmount: subtotal + taxAmount,
      discountAmount: 0,
      tin: VENDOR.tin,
      sst: VENDOR.sstNumber,
      complianceStatus: 'invalid',
      myInvoisStatus: 3, // LHDN SDK: Invalid — submitted invoice with validation issues (buyer TIN mismatch)
      myInvoisReferenceId: 'MYINVOIS-2026-REJ-321',
      submissionDate: TS('2026-02-05T14:00:00'),
      isWithinRelaxationPeriod: false,
      requiresSubmission: true,
      shippingRecipient: null,
      notes: 'REJECTED: Buyer TIN could not be verified. Please update buyer TIN and resubmit.',
      metadata: {
        rejectionReason: 'BUYER_TIN_MISMATCH',
        rejectionCode: 'E-INV-4002',
      },
      createdAt: TS('2026-02-05T13:00:00'),
      updatedAt: TS('2026-02-05T15:00:00'),
      createdBy: 'test-user-001',
      source: 'manual',
      isDeleted: false,
    };
  })(),
];

// ── COMPLIANCE ALERTS ───────────────────────────────────────────────────────
const COMPLIANCE_ALERTS = [
  {
    id: 'alert-001',
    userId: 'test-user-001',
    title: 'INV20260205001 Rejected — Action Required',
    message: 'MyInvois rejected INV20260205001 due to buyer TIN mismatch (Error E-INV-4002). Update buyer TIN and resubmit within 72 hours to avoid penalties.',
    type: 'error',
    category: 'lhdn',
    severity: 'critical',
    deadline: TS('2026-02-08T14:00:00'),
    createdAt: TS('2026-02-05T15:00:00'),
    isRead: false,
    relatedInvoiceId: 'INV20260205001',
    metadata: { rejectionReason: 'BUYER_TIN_MISMATCH', rejectionCode: 'E-INV-4002' },
  },
  {
    id: 'alert-002',
    userId: 'test-user-001',
    title: 'INV20260201001 Awaiting Validation',
    message: 'Invoice INV20260201001 (RM12,720) has been submitted to MyInvois and is awaiting validation. Reference: MYINVOIS-2026-PEND-002.',
    type: 'warning',
    category: 'lhdn',
    severity: 'high',
    deadline: TS('2026-02-04T10:00:00'),
    createdAt: TS('2026-02-01T11:00:00'),
    isRead: false,
    relatedInvoiceId: 'INV20260201001',
    metadata: null,
  },
  {
    id: 'alert-003',
    userId: 'test-user-001',
    title: 'Monthly Compliance Report Due',
    message: 'Your February 2026 consolidated invoice report for transactions below RM10,000 is due by 28 February 2026. Please review and submit.',
    type: 'deadline',
    category: 'lhdn',
    severity: 'medium',
    deadline: TS('2026-02-28T23:59:00'),
    createdAt: TS('2026-02-01T08:00:00'),
    isRead: false,
    relatedInvoiceId: null,
    metadata: null,
  },
  {
    id: 'alert-004',
    userId: 'test-user-001',
    title: 'SST Filing Reminder — Q1 2026',
    message: 'Your Q1 2026 SST return (January–March) is due on 30 April 2026. Ensure all invoices are reconciled.',
    type: 'info',
    category: 'lhdn',
    severity: 'low',
    deadline: TS('2026-04-30T23:59:00'),
    createdAt: TS('2026-02-01T08:00:00'),
    isRead: true,
    relatedInvoiceId: null,
    metadata: null,
  },
];

// ── COMPLIANCE QUESTIONS (FAQ) ──────────────────────────────────────────────
const COMPLIANCE_QUESTIONS = [
  {
    id: 'faq-001',
    question: 'What is the RM10,000 threshold rule for MyInvois?',
    answer: 'All B2B transactions with a total value of RM10,000 or above must be submitted to the MyInvois system within 72 hours of the transaction date. This applies per individual transaction, not cumulative totals. Both the seller and buyer must have a valid TIN. During the relaxation period (Jan 2026 – Dec 2027), micro-SMEs may consolidate sub-RM10,000 invoices monthly.',
    sources: ['LHDN Circular No. 3/2026, Section 2.1', 'LHDN MyInvois Implementation Roadmap 2026-2028'],
    relatedTopics: ['TIN', 'Submission Deadline', 'Relaxation Period'],
    confidenceScore: 0.97,
    timestamp: TS('2026-01-01T00:00:00'),
    category: 'einvoicing',
  },
  {
    id: 'faq-002',
    question: 'What is the MyInvois relaxation period and who qualifies?',
    answer: 'The relaxation period runs from January 2026 to December 2027. During this time, SMEs can consolidate invoices below RM10,000 and submit them monthly instead of within 72 hours. Transactions of RM10,000 and above still require immediate submission. First-time offenders receive a 50% penalty reduction. Full compliance is mandatory from 1 January 2028.',
    sources: ['LHDN MyInvois Implementation Roadmap 2026-2028'],
    relatedTopics: ['RM10k Threshold', 'Penalties', 'SME'],
    confidenceScore: 0.95,
    timestamp: TS('2026-01-01T00:00:00'),
    category: 'einvoicing',
  },
  {
    id: 'faq-003',
    question: 'What happens if my buyer does not have a TIN?',
    answer: 'If the buyer is a Malaysian individual without a TIN, you may use their MyKad/MyTentera/Passport number as the identification number and set the TIN field to the default value "EI00000000010". For B2C transactions below RM10,000, a consolidated invoice can be issued. Always verify TIN via MyTax portal before issuing invoices.',
    sources: ['LHDN Technical Guidelines v4.6, Chapter 4.6', 'MyTax Portal: https://mytax.hasil.gov.my'],
    relatedTopics: ['TIN', 'B2C', 'MyKad', 'Individual Buyer'],
    confidenceScore: 0.92,
    timestamp: TS('2026-01-01T00:00:00'),
    category: 'taxation',
  },
  {
    id: 'faq-004',
    question: 'What are the penalties for failing to submit e-invoices on time?',
    answer: 'Under the Income Tax Act 1967 and the MyInvois regulations, failure to submit a mandatory e-invoice within 72 hours can result in fines between RM200 and RM20,000 per infraction, or imprisonment up to 6 months. During the relaxation period (2026–2027), first-time offenders receive a 50% penalty reduction. Repeated offences attract the full penalty. Severe or persistent non-compliance may be referred for criminal prosecution.',
    sources: ['Income Tax Act 1967, Section 120', 'LHDN Circular No. 3/2026, Section 7'],
    relatedTopics: ['Penalties', 'Compliance', 'Submission Deadline'],
    confidenceScore: 0.93,
    timestamp: TS('2026-01-01T00:00:00'),
    category: 'penalties',
  },
  {
    id: 'faq-005',
    question: 'What are the mandatory fields on a MyInvois e-invoice?',
    answer: 'A compliant e-invoice must include: (1) Invoice number, type, issue date, currency; (2) Seller: registered name, TIN, BRN/IC, SST number, full address, contact; (3) Buyer: registered name, TIN, identification number, SST number, contact; (4) Line items: description, quantity, unit price, subtotal, SST, total; (5) Invoice totals: subtotal, total SST, total payable. Missing mandatory fields result in automatic rejection by MyInvois.',
    sources: ['LHDN Technical Guidelines v4.6, Section 4.1', 'LHDN MyInvois API Specification v2.0'],
    relatedTopics: ['Invoice Fields', 'TIN', 'SST', 'Validation'],
    confidenceScore: 0.96,
    timestamp: TS('2026-01-01T00:00:00'),
    category: 'einvoicing',
  },
];

// ── SUPPORT LOCATIONS ───────────────────────────────────────────────────────
const SUPPORT_LOCATIONS = [
  {
    id: 'loc-001',
    name: 'LHDN Kuala Lumpur City Centre Branch',
    type: 'lhdn_office',
    address: 'Menara Hasil, Persiaran Rimba Permai, Cyber 8, 63000 Cyberjaya, Selangor',
    latitude: 2.9213,
    longitude: 101.6559,
    phone: '+60388134000',
    website: 'https://www.hasil.gov.my',
    services: ['Tax Filing', 'TIN Registration', 'e-Invoice Enquiry', 'Tax Audit', 'MyInvois Support'],
    openingHours: 'Mon–Fri 8:00am – 5:00pm',
  },
  {
    id: 'loc-002',
    name: 'SME Corp Malaysia – Kuala Lumpur',
    type: 'sme_center',
    address: '2370 Jalan Usahawan 1, 63000 Cyberjaya, Selangor',
    latitude: 2.9247,
    longitude: 101.6505,
    phone: '+60392127799',
    website: 'https://www.smecorp.gov.my',
    services: ['SME Advisory', 'Business Registration', 'Grant Facilitation', 'MyInvois Guidance'],
    openingHours: 'Mon–Fri 8:30am – 5:30pm',
  },
  {
    id: 'loc-003',
    name: 'Malaysia Digital Economy Corporation (MDEC)',
    type: 'sme_center',
    address: '2360 Persiaran APEC, 63000 Cyberjaya, Selangor',
    latitude: 2.9281,
    longitude: 101.6482,
    phone: '+60388805000',
    website: 'https://www.mdec.my',
    services: ['Digital Transformation', 'e-Invoice Platform Advisory', 'Tech Grant', 'Digitalisation Support'],
    openingHours: 'Mon–Fri 9:00am – 6:00pm',
  },
  {
    id: 'loc-004',
    name: 'LHDN Petaling Jaya Branch',
    type: 'lhdn_office',
    address: 'Tingkat 1-7, Wisma LHDN, Jalan Parlimen, 46200 Petaling Jaya, Selangor',
    latitude: 3.1087,
    longitude: 101.6368,
    phone: '+60378020999',
    website: 'https://www.hasil.gov.my',
    services: ['Tax Filing', 'TIN Registration', 'e-Invoice Enquiry', 'Corporate Tax'],
    openingHours: 'Mon–Fri 8:00am – 5:00pm',
  },
  {
    id: 'loc-005',
    name: 'Dewan Perniagaan Melayu Malaysia (DPMM) – Advisory',
    type: 'tax_support',
    address: 'Plaza Damansara, 45 Jalan Medan Setia 1, Bukit Damansara, 50490 Kuala Lumpur',
    latitude: 3.1585,
    longitude: 101.6631,
    phone: '+60320951277',
    website: 'https://www.dpmm.org.my',
    services: ['Tax Advisory', 'e-Invoicing Consultation', 'SME Support', 'Business Networking'],
    openingHours: 'Mon–Fri 9:00am – 5:00pm',
  },
];

// ── ANALYTICS CACHE ──────────────────────────────────────────────────────────
const ANALYTICS_CACHE = [
  {
    id: 'test-user-001',
    salesTrend: [
      { period: 'Sep 2025', amount: 8500, count: 2 },
      { period: 'Oct 2025', amount: 12000, count: 3 },
      { period: 'Nov 2025', amount: 9800, count: 2 },
      { period: 'Dec 2025', amount: 15200, count: 4 },
      { period: 'Jan 2026', amount: 26592, count: 3 },
      { period: 'Feb 2026', amount: 30262, count: 4 },
    ],
    statusBreakdown: [
      { status: 'accepted', count: 1 },
      { status: 'submitted', count: 1 },
      { status: 'validated', count: 1 },
      { status: 'draft', count: 1 },
      { status: 'rejected', count: 1 },
    ],
    totalRevenue: 68854.0,
    averageInvoiceValue: 13770.8,
    totalInvoices: 5,
    topCustomers: {
      'ABC Trading Sdn Bhd': 27272.0,
      'Mega Retail Bhd': 12720.0,
      'Greentech Solutions Sdn Bhd': 13780.0,
      'Primavera Catering & Events': 4770.0,
    },
    complianceScore: 72.0,
    lastUpdated: TS('2026-02-22T00:00:00'),
  },
];

// ─────────────────────────────────────────────
// PREFLIGHT CHECK
// ─────────────────────────────────────────────

async function preflight() {
  console.log('── Preflight check ───────────────────────────');
  console.log(`    Service account project : ${serviceAccount.project_id}`);
  console.log(`    Service account email   : ${serviceAccount.client_email}`);
  try {
    // A lightweight read to confirm Firestore is reachable
    await db.collection('_seed_ping').limit(1).get();
    console.log('    Firestore connection    : ✅ OK\n');
  } catch (err) {
    if (err.code === 5) {
      console.error('\n❌  FIRESTORE DATABASE NOT FOUND');
      console.error('   The Firestore database has not been created yet in your Firebase project.');
      console.error('   Please do the following:');
      console.error('     1. Go to https://console.firebase.google.com/project/' + serviceAccount.project_id + '/firestore');
      console.error('     2. Click "Create database"');
      console.error('     3. Choose "Start in production mode" (or test mode for dev)');
      console.error('     4. Select a region (asia-southeast1 recommended for Malaysia)');
      console.error('     5. Click "Enable", then re-run: npm run seed\n');
    } else if (err.code === 7) {
      console.error('\n❌  PERMISSION DENIED');
      console.error('   The service account does not have Firestore access.');
      console.error('   In Firebase Console → Project Settings → Service Accounts,');
      console.error('   ensure the account has the "Cloud Datastore User" or "Firebase Admin" role.\n');
    } else if (err.code === 16) {
      console.error('\n❌  AUTHENTICATION FAILED');
      console.error('   The service-account-key.json may be expired or revoked.');
      console.error('   Generate a new key from Firebase Console → Project Settings → Service Accounts.\n');
    } else {
      console.error('\n❌  Preflight failed:', err.message);
    }
    process.exit(1);
  }
}

// ─────────────────────────────────────────────
// WRITE HELPERS
// ─────────────────────────────────────────────

async function wipeCollection(name) {
  console.log(`  🗑  Wiping ${name}…`);
  const snap = await db.collection(name).get();
  if (snap.empty) return;
  // Firestore limits batches to 500 ops
  const chunks = [];
  for (let i = 0; i < snap.docs.length; i += 450) {
    chunks.push(snap.docs.slice(i, i + 450));
  }
  for (const chunk of chunks) {
    const batch = db.batch();
    chunk.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
  console.log(`     deleted ${snap.size} docs`);
}

async function seedCollection(name, documents, idField = 'id') {
  console.log(`  📥  Seeding ${name} (${documents.length} docs)…`);
  const batch = db.batch();
  for (const doc of documents) {
    const ref = db.collection(name).doc(doc[idField]);
    const data = { ...doc };
    delete data[idField]; // don't double-store the ID inside the doc
    batch.set(ref, data);
  }
  await batch.commit();
  console.log(`     ✅ done`);
}

// ─────────────────────────────────────────────
// AUTH USERS
// ─────────────────────────────────────────────

// Firebase Auth users whose UIDs MUST match the `createdBy` field used in
// the seeded Firestore documents. Without this, every Firestore query that
// filters by `createdBy == userId` returns zero results after login.
const AUTH_USERS = [
  {
    uid: 'test-user-001',
    email: 'aida@smeasy.my',
    password: 'Test@12345',
    displayName: 'Aida Binti Rahman',
  },
  {
    uid: 'test-user-002',
    email: 'haziq@techsolutions.my',
    password: 'Test@12345',
    displayName: 'Haziq',
  },
];

async function seedAuthUsers() {
  console.log('── Creating Firebase Auth users ──────────────');
  for (const user of withUid(AUTH_USERS)) {
    try {
      await admin.auth().createUser(user);
      console.log(`     ✅ Created auth user: ${user.email} (uid: ${user.uid})`);
    } catch (err) {
      if (err.code === 'auth/uid-already-exists' || err.code === 'auth/email-already-exists') {
        // Update the existing user to ensure password matches
        await admin.auth().updateUser(user.uid, {
          email: user.email,
          password: user.password,
          displayName: user.displayName,
        }).catch(() => {}); // ignore if UID doesn't match email; just log
        console.log(`     ♻️  Auth user already exists (updated): ${user.email}`);
      } else {
        console.warn(`     ⚠️  Could not create auth user ${user.email}:`, err.message);
      }
    }
  }
  console.log();
}

// ─────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────

async function main() {
  console.log('\n🚀  MyInvoisMate — Firestore Seed Script');
  console.log(`    Project: ${serviceAccount.project_id}`);
  console.log(`    Mode   : ${WIPE ? 'WIPE + SEED' : 'SEED (merge)'}\n`);

  await preflight();
  await seedAuthUsers();

  if (WIPE) {
    console.log('── Wiping existing data ──────────────────────');
    for (const col of Object.values(COLLECTIONS)) {
      await wipeCollection(col);
    }
    console.log();
  }

  console.log('── Writing seed data ─────────────────────────');
  await seedCollection(COLLECTIONS.users, withUid(USERS));
  await seedCollection(COLLECTIONS.customers, withUid(CUSTOMERS));
  await seedCollection(COLLECTIONS.invoices, withUid(INVOICES));
  await seedCollection(COLLECTIONS.complianceAlerts, withUid(COMPLIANCE_ALERTS));
  await seedCollection(COLLECTIONS.complianceQuestions, withUid(COMPLIANCE_QUESTIONS));
  await seedCollection(COLLECTIONS.supportLocations, withUid(SUPPORT_LOCATIONS));
  await seedCollection(COLLECTIONS.analyticsCache, withUid(ANALYTICS_CACHE));

  console.log('\n✨  All collections seeded successfully!');
  console.log('\n📋  Summary:');
  console.log(`    users               : ${USERS.length}`);
  console.log(`    customers           : ${CUSTOMERS.length}`);
  console.log(`    invoices            : ${INVOICES.length}`);
  console.log(`    compliance_alerts   : ${COMPLIANCE_ALERTS.length}`);
  console.log(`    compliance_questions: ${COMPLIANCE_QUESTIONS.length}`);
  console.log(`    support_locations   : ${SUPPORT_LOCATIONS.length}`);
  console.log(`    analytics_cache     : ${ANALYTICS_CACHE.length}`);
  console.log('\n💡  Login credentials:');
  console.log('      Email   : aida@smeasy.my');
  console.log('      Password: Test@12345');
  console.log(`      UID     : ${SEED_UID}  (matches all seeded createdBy fields)`);
  if (SEED_UID === 'test-user-001') {
    console.log('\n⚠️   The UID is the placeholder \'test-user-001\'. If your app shows no data,');
    console.log('    re-run with your real Firebase Auth UID:');
    console.log('      npm run seed:wipe -- --uid=<your_uid>');
    console.log('    (Find your UID in Firebase Console → Authentication → Users)');
  }
  process.exit(0);
}

main().catch((err) => {
  console.error('❌  Seed failed:', err);
  process.exit(1);
});
