# Releasing Drawspeak to TestFlight

One script archives, exports, validates and uploads the iPad app:

```sh
scripts/testflight.sh --no-upload   # archive + export + IPA checks + altool --validate-app
scripts/testflight.sh               # the same, then altool --upload-package
```

- Build number: `date -u +%Y%m%d%H%M` (override with `DS_BUILD_NUMBER`), passed as
  `CURRENT_PROJECT_VERSION` on the command line. Marketing version comes from
  `MARKETING_VERSION` in `App/project.yml`.
- Output: `/tmp/ds-release/<build>/` (archive, IPA, logs) and the receipt
  `/tmp/ds-release/receipt-<build>.json` (version, build, git commit, profile UUID,
  IPA SHA-256, validate/upload status, delivery id). Derived data: `/tmp/ds-archive-dd`.
- `xcodebuild archive` and `-exportArchive` run through `~/.local/bin/heavy-check`.
  Exit 75/77 means the step did not run.
- The script runs `xcodegen generate`, so the checked-in `Drawspeak.xcodeproj` is
  regenerated from `App/project.yml`.
- Delete `/tmp/ds-release/<build>` after a dry run; an archive is a few hundred MB.

The IPA checks fail the run when: bundle id is not `com.wydrox.drawspeak`,
`CFBundleVersion` is not the build number, `ITSAppUsesNonExemptEncryption` is not
`false`, the compiled iPad icon is missing, the embedded profile is not the installed
"Drawspeak App Store" profile, or the app is not signed with Apple Distribution.

## App Store Connect resources

| Resource | Value |
|---|---|
| Team | `7S3F9767BM` |
| App | "Drawspeak", app id `6830611699` |
| Bundle id | `com.wydrox.drawspeak`, resource id `8PJVSXTDA2` (UNIVERSAL) |
| Distribution certificate | "Apple Distribution: Apprife Konrad Alfaro (7S3F9767BM)", ASC id `6FZRAKRSVG`, serial `4573B54943172B85084FCAD4480686A1`, SHA-1 `B8A4C499ADE22A6FD1BCFA46DA1FF1BD62B9C136`, expires 2027-08-28 |
| Provisioning profile | "Drawspeak App Store", IOS_APP_STORE, id `CKCCNX6FL8`, UUID `284d1c08-8f34-41d2-bfed-196890d8d152`, expires 2027-08-28 |
| Installed at | `~/Library/Developer/Xcode/UserData/Provisioning Profiles/284d1c08-8f34-41d2-bfed-196890d8d152.mobileprovision` |
| Internal beta group | "Drawspeak", id `08d424ca-98ac-4a21-86c2-ebdfdf84b181`, `isInternalGroup` true, `hasAccessToAllBuilds` true |
| Tester | wyderkarafal@gmail.com, betaTester id `630d3926-394d-4e93-a50f-8ef5b59883a5` (in the group) |
| API key | key id `2PX9L952HH`, issuer `21e40dd1-5b96-4c70-a35e-f5b49ba22361`, file `~/.appstoreconnect/private_keys/AuthKey_2PX9L952HH.p8` (never copy it into the repo) |

Because the group has access to all builds, every processed build reaches the tester
without a manual "add build to group" step.

## ASC API client

`scripts/asc.py` is a minimal client. GET is unrestricted; writes are allow-listed
(profiles, beta groups, beta testers, encryption declarations, build-to-group).

```sh
uv run -q --no-project --with pyjwt --with cryptography python -I scripts/asc.py GET /v1/apps/6830611699/builds
```

Exit 2 means HTTP 409. Use a wrapper script rather than storing the command in a zsh
variable (zsh does not word-split it).

## Re-creating the profile

When the certificate is renewed, the profile becomes invalid. Create a new one with the
same name, decode `attributes.profileContent` (base64) and save it as
`<uuid>.mobileprovision` in the directory above:

```sh
scripts/asc.py POST /v1/profiles '{"data":{"type":"profiles","attributes":{"name":"Drawspeak App Store","profileType":"IOS_APP_STORE"},"relationships":{"bundleId":{"data":{"type":"bundleIds","id":"8PJVSXTDA2"}},"certificates":{"data":[{"type":"certificates","id":"<cert id>"}]}}}}'
```

Then update the table above.

## Required signing settings in `App/project.yml`

The script refuses to run without these lines in the `Drawspeak` target:

```yaml
    settings:
      base:
        ...
      configs:
        Release:
          CODE_SIGN_STYLE: Manual
          CODE_SIGN_IDENTITY: Apple Distribution
          PROVISIONING_PROFILE_SPECIFIER: Drawspeak App Store
```

Debug builds keep automatic signing.

## Gotchas

- Signing is manual. The API key cannot use cloud-managed certificates, so automatic
  signing with `-allowProvisioningUpdates` fails at export.
  `scripts/ExportOptions.plist` uses `method app-store-connect`, `signingStyle manual`
  and a `provisioningProfiles` map.
- Do not pass `PROVISIONING_PROFILE_SPECIFIER` on the `xcodebuild archive` command
  line. Command-line settings apply to every target, including SwiftPM resource
  bundles: `DrawspeakKit_HTMLKit does not support provisioning profiles, but
  provisioning profile Drawspeak App Store has been manually specified`. The setting
  must be target-scoped (above).
- With `set -o pipefail`, `cmd | grep -q` can fail when grep exits early and `cmd`
  gets SIGPIPE (seen with `codesign -dvv`). The script captures output first.
- Commit `c3341cd` does not resolve the package: `Tests/DrawspeakCoreTests` is not
  committed, while `Package.swift` declares that test target.
- Adding an existing betaTester record (created for another app) to the new group
  fails with `409 STATE_ERROR "Tester(s) cannot be assigned"`. `POST /v1/betaTesters`
  with the email and a `betaGroups` relationship works; the tester stays
  `NOT_INVITED` until the first build is processed.
- `ITSAppUsesNonExemptEncryption` must stay `false` in `App/project.yml`; otherwise
  every build waits for an export-compliance answer.
- The ASC app record has an App Store version 1.0 (PREPARE_FOR_SUBMISSION), while
  `MARKETING_VERSION` is 0.1.0. TestFlight accepts this; for App Store submission the
  build version and the store version must match.
- altool in Xcode 27 documents `--api-key/--api-issuer` (the older
  `--apiKey/--apiIssuer` still works). It finds the key in
  `~/.appstoreconnect/private_keys`.
- The App Store rejects icons with an alpha channel. Regenerate the icon with
  `swift scripts/make-icon.swift App/Drawspeak/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
  (through heavy-check) and check it with `sips -g hasAlpha -g pixelWidth`.
