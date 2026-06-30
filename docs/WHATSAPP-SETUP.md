# WhatsApp Setup (Meta WhatsApp Cloud API)

The WhatsApp join channel is **already built** in Queue.ai:
- Inbound webhook: `apps/web/src/app/api/whatsapp/route.ts` (a patient texts `JOIN <code>` → joins the queue → gets their tracker link).
- Outbound: the worker sends WhatsApp messages for notifications whose `channel = 'whatsapp'`.
- Join page CTA: a "Join on WhatsApp" button appears when `NEXT_PUBLIC_WHATSAPP_NUMBER` is set.

It is **dormant until you connect a Meta WhatsApp Business number**. This is account setup (no code changes). Budget ~1–2 days, mostly Meta's verification waiting.

> For an early Nigeria pilot, SMS via Termii is faster to stand up and covers the same "your turn / leave now" alerts. Treat WhatsApp as a phase-2 channel.

---

## Step 1 — Create the Meta assets
1. Go to **https://developers.facebook.com** → create a **Meta Business** account if you don't have one.
2. Create an **App** → type **Business** → add the **WhatsApp** product.
3. In **WhatsApp → API Setup** you'll get a **test phone number** and a temporary **access token**. Note the **Phone number ID** (not the phone number itself).

## Step 2 — Get a permanent token
The test token expires in 24h. For production:
1. **Business Settings → Users → System users** → create a system user (Admin).
2. **Add Assets** → assign your WhatsApp app.
3. **Generate token** → select `whatsapp_business_messaging` + `whatsapp_business_management` → copy the long-lived token. This is your `WHATSAPP_TOKEN`.

## Step 3 — Set environment variables
Add to the **web app** (and the worker, for outbound):

```
WHATSAPP_TOKEN=<system-user token from step 2>
WHATSAPP_PHONE_NUMBER_ID=<Phone number ID from step 1>
WHATSAPP_VERIFY_TOKEN=<any random string you choose, e.g. queue-ai-7f3k>
NEXT_PUBLIC_WHATSAPP_NUMBER=<the WhatsApp number in E.164 without +, e.g. 2348012345678>
NEXT_PUBLIC_APP_URL=https://your-deployed-app.com
```

Redeploy so the variables take effect.

## Step 4 — Register the webhook
1. In the Meta app → **WhatsApp → Configuration → Webhook** → **Edit**.
2. **Callback URL:** `https://your-deployed-app.com/api/whatsapp`
3. **Verify token:** the exact same string you set as `WHATSAPP_VERIFY_TOKEN`.
4. Click **Verify and save** — Meta calls your `GET /api/whatsapp`; it should succeed (returns the challenge).
5. **Subscribe** to the **`messages`** field.

## Step 5 — Test
1. From your phone, message your WhatsApp Business number: `JOIN <branch-code>`
   - The `<branch-code>` is the branch `qr_token` (see Admin → Structure → Branch access; the wa.me CTA pre-fills it).
2. You should get a reply: *"You're in the queue at <branch>. Estimated wait: …"* with a tracker link.
3. The patient now appears in **Reception**.

## Going live (production number)
- The test number only messages pre-approved recipients. To message any patient, add and verify your **own business phone number** in **WhatsApp → Phone numbers**, and submit the business for verification.
- Outbound messages **initiated by you** (not replies within 24h) require **approved message templates**. Our notifications ("your turn", "leave now") are short alerts — create matching templates in **WhatsApp → Message templates** if you'll message patients outside the 24-hour reply window.

## Troubleshooting
- **Webhook won't verify:** `WHATSAPP_VERIFY_TOKEN` mismatch, or the app isn't deployed at a public HTTPS URL.
- **No reply to JOIN:** check the worker/web logs; confirm `WHATSAPP_TOKEN` + `WHATSAPP_PHONE_NUMBER_ID` are set and the token hasn't expired.
- **"JOIN" not recognized:** the message must start with `JOIN ` followed by the branch code (the wa.me link formats this automatically).
