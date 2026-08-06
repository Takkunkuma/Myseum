# Push notifications setup (event invites)

End-to-end: someone inserts an `event_shares` row → a Database Webhook calls the
`notify-invite` Edge Function → it sends an APNs push to the invitee's devices.

> Push only works on a **real iPhone** (the Simulator has no APNs token).

## 1. Database
Run `supabase/schema_d3.sql` in the SQL Editor (creates `device_tokens`).

## 2. APNs auth key (Apple Developer portal)
1. developer.apple.com → Certificates, Identifiers & Profiles → **Keys** → **+**.
2. Enable **Apple Push Notifications service (APNs)**, register, **download the `.p8`** (one-time).
3. Note the **Key ID** (10 chars) and your **Team ID** (top-right of the portal).
4. Under **Identifiers → com.myseum.app**, ensure **Push Notifications** is enabled.
   (Building to a device from Xcode with automatic signing also enables it.)

## 3. Deploy the Edge Function
```sh
# from the Myseum/ folder, with the Supabase CLI installed
supabase login
supabase link --project-ref zhqzpzjgdfoszkkkuurs
supabase functions deploy notify-invite --no-verify-jwt

supabase secrets set \
  APNS_KEY_ID=XXXXXXXXXX \
  APNS_TEAM_ID=YYYYYYYYYY \
  APNS_TOPIC=com.myseum.app \
  APNS_HOST=api.sandbox.push.apple.com
supabase secrets set APNS_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"
```
`APNS_HOST` = `api.sandbox.push.apple.com` for dev/Xcode builds, `api.push.apple.com`
for TestFlight/App Store builds.

## 4. Database Webhook
Dashboard → **Database → Webhooks → Create a new hook**:
- Table: `public.event_shares`
- Events: **Insert**
- Type: **Supabase Edge Functions** → `notify-invite`

## 5. Run on device & test
1. Open `Myseum.xcodeproj`, select your Team, run on your iPhone.
2. Allow notifications, sign in (this stores your device token).
3. From a second account, invite you to an event → push arrives. 🎉

## Troubleshooting
- Check the function logs in the dashboard (Edge Functions → notify-invite → Logs).
- `BadDeviceToken` usually means the `APNS_HOST` sandbox/prod choice doesn't match the build type.
