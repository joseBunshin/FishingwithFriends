# Supabase email templates

Auth emails (signup confirmation, password recovery, magic link) are
configured in the **Supabase dashboard**, not in code. Paste the HTML
below into **Authentication → Email Templates** for the matching tab.

Each template uses Supabase's `{{ .ConfirmationURL }}` placeholder —
do not edit it.

---

## 1. Confirm signup

**Subject:** `Fishing With Friends Signup`

**Template HTML:**

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Confirm your Fishing with Friends signup</title>
  </head>
  <body style="margin:0;padding:0;background:#F5F7FA;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F5F7FA;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#FFFFFF;border-radius:16px;border:1px solid #E2E8F0;overflow:hidden;">
            <tr>
              <td style="padding:32px 32px 8px 32px;text-align:center;">
                <div style="font-size:14px;font-weight:600;color:#102B47;letter-spacing:2px;text-transform:uppercase;">Fishing with Friends</div>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 24px 32px;text-align:center;">
                <h1 style="margin:0;font-size:24px;line-height:1.3;color:#102B47;font-weight:800;letter-spacing:-0.3px;">
                  Thank you for signing up!
                </h1>
                <p style="margin:16px 0 0 0;font-size:15px;line-height:1.5;color:#4A5568;">
                  We're glad to have you on Fishing with Friends.<br />
                  Please confirm your email to start logging catches.
                </p>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:8px 32px 32px 32px;">
                <table role="presentation" cellpadding="0" cellspacing="0">
                  <tr>
                    <td align="center" style="background:#1E5BA8;border-radius:999px;">
                      <a href="{{ .ConfirmationURL }}"
                         style="display:inline-block;padding:14px 28px;font-size:16px;font-weight:700;color:#FFFFFF;text-decoration:none;letter-spacing:0.2px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
                        🐟 &nbsp; Confirm Email
                      </a>
                    </td>
                  </tr>
                </table>
                <p style="margin:18px 0 0 0;font-size:12px;line-height:1.5;color:#718096;">
                  Button not working? Paste this into your browser:<br />
                  <a href="{{ .ConfirmationURL }}" style="color:#1E5BA8;word-break:break-all;">{{ .ConfirmationURL }}</a>
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:0 32px 24px 32px;border-top:1px solid #E2E8F0;text-align:center;">
                <p style="margin:16px 0 0 0;font-size:12px;line-height:1.5;color:#718096;">
                  Didn't sign up for Fishing with Friends? You can safely ignore this email.
                </p>
              </td>
            </tr>
          </table>
          <p style="margin:16px 0 0 0;font-size:11px;color:#A0AEC0;letter-spacing:1px;text-transform:uppercase;">
            a Bunshin Development Studios product
          </p>
        </td>
      </tr>
    </table>
  </body>
</html>
```

The button uses Supabase's own brand-blue hex (`#1E5BA8`) so the "blue
fish" reads correctly even when the app's orange palette is active. The
🐟 emoji renders consistently across Apple Mail, Gmail (web + iOS +
Android), Outlook web, and Yahoo. Outlook desktop on Windows falls back
to a black-and-white emoji glyph on older versions — still readable, but
not colored. Acceptable.

---

## 2. Reset password

**Subject:** `Fishing With Friends — reset your password`

**Template HTML:**

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Reset your Fishing with Friends password</title>
  </head>
  <body style="margin:0;padding:0;background:#F5F7FA;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F5F7FA;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#FFFFFF;border-radius:16px;border:1px solid #E2E8F0;overflow:hidden;">
            <tr>
              <td style="padding:32px 32px 8px 32px;text-align:center;">
                <div style="font-size:14px;font-weight:600;color:#102B47;letter-spacing:2px;text-transform:uppercase;">Fishing with Friends</div>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 24px 32px;text-align:center;">
                <h1 style="margin:0;font-size:24px;line-height:1.3;color:#102B47;font-weight:800;letter-spacing:-0.3px;">
                  Reset your password
                </h1>
                <p style="margin:16px 0 0 0;font-size:15px;line-height:1.5;color:#4A5568;">
                  Tap the button below to set a new password.<br />
                  This link expires in 1 hour.
                </p>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:8px 32px 32px 32px;">
                <table role="presentation" cellpadding="0" cellspacing="0">
                  <tr>
                    <td align="center" style="background:#1E5BA8;border-radius:999px;">
                      <a href="{{ .ConfirmationURL }}"
                         style="display:inline-block;padding:14px 28px;font-size:16px;font-weight:700;color:#FFFFFF;text-decoration:none;letter-spacing:0.2px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
                        🐟 &nbsp; Reset Password
                      </a>
                    </td>
                  </tr>
                </table>
                <p style="margin:18px 0 0 0;font-size:12px;line-height:1.5;color:#718096;">
                  Button not working? Paste this into your browser:<br />
                  <a href="{{ .ConfirmationURL }}" style="color:#1E5BA8;word-break:break-all;">{{ .ConfirmationURL }}</a>
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:0 32px 24px 32px;border-top:1px solid #E2E8F0;text-align:center;">
                <p style="margin:16px 0 0 0;font-size:12px;line-height:1.5;color:#718096;">
                  Didn't ask to reset your password? You can safely ignore this email — your account stays as it is.
                </p>
              </td>
            </tr>
          </table>
          <p style="margin:16px 0 0 0;font-size:11px;color:#A0AEC0;letter-spacing:1px;text-transform:uppercase;">
            a Bunshin Development Studios product
          </p>
        </td>
      </tr>
    </table>
  </body>
</html>
```

---

## Dashboard configuration steps

Per template, in the Supabase dashboard:

1. **Auth → URL Configuration**
   - **Site URL:** `https://app.fishingwithfriends.bunshin.io` (or your production domain). For dev, `http://localhost:5100` works while running `flutter run -d chrome`.
   - **Redirect URLs (allowlist):** add every URL the recovery + signup-confirm links may target — at minimum the Site URL above plus any local dev port you use (`http://localhost:5100`, `http://localhost:5200`, etc.). Without these, Supabase rejects the redirect and the email link 404s.

2. **Auth → Email Templates → Confirm signup**
   - Subject: `Fishing With Friends Signup`
   - Body: paste the **Confirm signup** HTML above.

3. **Auth → Email Templates → Reset Password**
   - Subject: `Fishing With Friends — reset your password`
   - Body: paste the **Reset password** HTML above.

4. **Auth → Providers → Email**
   - Confirm signup: **enabled** (otherwise users skip the email entirely).
   - Secure password change: **enabled**.

---

## Mobile deep linking (post-launch)

For the email button to open the iOS / Android app directly (instead of
the browser), wire a custom scheme:

- **iOS:** add `CFBundleURLTypes` entry with scheme `fwf` in `ios/Runner/Info.plist`.
- **Android:** add an `<intent-filter>` for `fwf://` in `android/app/src/main/AndroidManifest.xml` on the `MainActivity`.
- Add `fwf://reset-password` to the Supabase redirect allowlist.
- Pass `redirectTo: 'fwf://reset-password'` to `auth.resetPasswordForEmail` and `auth.signUp`.

Skipped in v1 — web fallback works for both signup confirmation and
password recovery, which covers the iOS + Android cold-start cases for
the launch milestone. Wire native deep links once the app is in TestFlight
/ Play internal track.

---

## Testing the templates

1. Send a real signup email to a personal address by creating an account
   in the app or invoking `supabase.auth.signUp(...)` from the SQL editor.
2. Send a real recovery email by clicking "Forgot password?" on the
   sign-in screen.
3. Render the HTML in [putsmail.com](https://putsmail.com/) or
   [litmus.com](https://litmus.com/) for cross-client previews before
   shipping any template change.
