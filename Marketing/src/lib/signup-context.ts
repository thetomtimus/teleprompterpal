// Only known campaign labels may reach HubSpot. Never forward arbitrary URL
// parameters, referrers, user-written text, or a visitor identifier.
const STORAGE_KEY = 'teleprompter-pal-referral-v1';
const CAMPAIGNS = new Set([
  'free-reader',
  'free-guide-youtube',
  'free-guide-presentations',
  'free-guide-podcasts',
  'free-guide-zoom',
  'free-guide-mirror',
]);

type Referral = { source: 'free-teleprompter-online'; medium: 'referral'; campaign: string };
type ReferralStorage = Pick<Storage, 'getItem' | 'setItem'>;

function knownReferral(value: unknown): value is Referral {
  if (!value || typeof value !== 'object') return false;
  const referral = value as Record<string, unknown>;
  return referral.source === 'free-teleprompter-online'
    && referral.medium === 'referral'
    && typeof referral.campaign === 'string'
    && CAMPAIGNS.has(referral.campaign);
}

export function signupPageContext(href: string, storage?: ReferralStorage) {
  const page = new URL('https://teleprompterpal.com/');
  let referral: Referral | undefined;
  try {
    const params = new URL(href).searchParams;
    const incoming = {
      source: params.get('utm_source'),
      medium: params.get('utm_medium'),
      campaign: params.get('utm_campaign'),
    };
    if (knownReferral(incoming)) {
      referral = incoming;
      try { storage?.setItem(STORAGE_KEY, JSON.stringify(referral)); } catch { /* Signup still works without storage. */ }
    } else {
      try {
        const saved: unknown = JSON.parse(storage?.getItem(STORAGE_KEY) || 'null');
        if (knownReferral(saved)) referral = saved;
      } catch { /* Unavailable or malformed session data is ignored. */ }
    }
  } catch { /* An invalid input URL produces a clean canonical signup context. */ }

  if (referral) {
    page.searchParams.set('utm_source', referral.source);
    page.searchParams.set('utm_medium', referral.medium);
    page.searchParams.set('utm_campaign', referral.campaign);
  }
  return {
    pageUri: page.href,
    pageName: 'Teleprompter Pal Product Updates',
  };
}
