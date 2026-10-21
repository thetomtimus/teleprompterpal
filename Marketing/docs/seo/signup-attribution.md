# Signup referral labels

Capture known Free Teleprompter Online labels on every Astro marketing page, including guide and pricing arrivals. Keep them only in this tab's session storage. The homepage signup reads the saved labels into its sanitized HubSpot page context. No tracking request is made when a visitor merely opens a page.

The source is `free-teleprompter-online`, the medium is `referral`, and the campaign must be one of `free-reader`, `free-guide-youtube`, `free-guide-presentations`, `free-guide-podcasts`, `free-guide-zoom`, `free-guide-mirror` or `free-guide-camera`.

The previously published camera-guide link used the exact pair `utm_source=freeteleprompteronline` and `utm_campaign=camera_workflow`, with `utm_medium=referral`. Accept and normalize only that exact legacy combination to the current camera labels so cached links still work. Do not accept arbitrary aliases or campaign text.

A fresh direct tab produces the canonical homepage context without campaign parameters. A tab with an earlier recognized referral keeps that referral across subsequent direct-looking page navigations. A new recognized referral replaces the previous campaign. An absent label does not prove a direct visit: untagged referrals, new tabs and denied storage can also lose attribution.

The saved value contains only fixed source, medium and campaign strings. Exclude email addresses, script text, recording data, URL fragments, arbitrary query strings and visitor identifiers. Storage denial must never block the form. This is labeled-source attribution, not a complete click-to-signup conversion rate or proof of organic acquisition.

Run the focused regression checks with Node 24 or later:

```sh
node --test tests/signup-context.test.ts
```

They cover guide-to-pricing-to-signup navigation, the exact legacy camera alias, direct context, later referrals, private-parameter exclusion and unavailable/malformed storage. The Astro build must include the shared capture script on the homepage, guide and pricing page. Real HubSpot acceptance, contact deduplication and owner notifications require separate approved live signup tests; a local test pass is not that evidence.
