# Per-OS build secrets

One JSON file per platform, passed with `--dart-define-from-file`:

```bash
fvm flutter build apk   --release --dart-define-from-file=secrets/android.json
fvm flutter build macos --release --dart-define-from-file=secrets/macos.json
fvm flutter build linux --release --dart-define-from-file=secrets/linux.json
```

The real `*.json` files are gitignored; copy the matching `*.example.json` and fill it in.
Keys the app reads (all via `String.fromEnvironment`):

| Key | Used by | Where it comes from |
|---|---|---|
| `KATA_GOOGLE_WEB_CLIENT_ID` | every platform (`serverClientId` / API audience) | GCP kata-506016 → Web client |
| `KATA_GOOGLE_DESKTOP_CLIENT_ID` / `_SECRET` | desktop loopback PKCE (macOS/Linux/Windows) | GCP kata-506016 → Desktop client |
| `KATA_API` | optional API base override (`http://10.0.2.2:5090` for local dev) | — |

Backups of the filled-in files live on the API VM under `/root/keys/app-secrets/`.
