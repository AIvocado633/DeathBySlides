# Building a test release

How to put a signed build of the game on testers' phones through Google
Play's internal testing track: up to 100 testers, invited by email,
installing from the Play Store with no public listing.

## Once: the upload key

Play only accepts builds signed with your **upload key**. The repository
never holds it.

1. Create it, somewhere outside the repository:

   ```bash
   keytool -genkey -v -keystore ~/keys/death-by-slides-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Back it up now**, with its passwords: in a password manager, and a copy
   offline. Write down where the backup is, outside this repository.

   Enrol the app in **Play App Signing** when Play offers it (it is the
   default for new apps). Google then holds the key that signs what players
   install, and a lost upload key can be reset through Play support instead
   of meaning a new app under a new ID. Losing it is still days of trouble,
   so keep the backup.

3. Tell the build where it is, in `android/key.properties`:

   ```properties
   storeFile=/home/you/keys/death-by-slides-upload.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```

   A relative `storeFile` is read from `android/app/`. Both this file and
   `*.jks` are git-ignored; never commit either.

Without `android/key.properties`, release builds are signed with the debug
key, so `flutter run --release` keeps working on any machine. Play rejects
those builds, which is how you notice.

## Every build

1. **Bump the version** in `pubspec.yaml`. Test builds are `0.x`, so that
   `1.0.0` means the release. The number after the `+` must go up with every
   upload: Play refuses a build number it has seen.

   ```yaml
   version: 0.1.0+2
   ```

2. **Build the bundle:**

   ```bash
   flutter build appbundle
   ```

   It writes `build/app/outputs/bundle/release/app-release.aab`.

3. **Check it is signed with the upload key**, not the debug one:

   ```bash
   keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
   ```

   The owner should be whoever you named when creating the key, not
   `CN=Android Debug`.

4. Upload it to **Testing ▸ Internal testing** in the Play Console, and send
   the testers the opt-in link.

## Once: the Play Console

Done by hand, in the [Play Console](https://play.google.com/console):

- **Create the app.** Its application ID, `com.deathbyslides.death_by_slides`
  (in `android/app/build.gradle.kts`), is **permanent** once the first build
  is uploaded. Change it before that or never.
- **Internal testing:** create the track and a tester list (email addresses).
- **Data safety:** the game collects no data and shares none. It has no
  network access, no accounts, no ads and no analytics; progress and
  settings stay on the device.
- **Privacy policy:** Play requires a URL even when nothing is collected.
  [`docs/privacy.md`](privacy.md) is the policy. Link to it on GitHub, or
  publish it with GitHub Pages if the repository is private.
- **Content rating:** fill in the questionnaire. Cartoon shapes, no blood,
  no chat, no purchases.

## Trademarks

The game is about slideware in general, and names no product in the app, its
name or its icon. Keep it that way in the store listing too: no product names
or logos in the title, the icon or the screenshots. The README's line goes
in the description:

> Not affiliated with or endorsed by the makers of any presentation software.

If the description ever does name a product, add its trademark notice as
well, for example *"PowerPoint is a trademark of Microsoft Corporation."*
Read Play's impersonation and intellectual property policies before
submitting.

## Before inviting testers

A tester should be able to install from the Play link, reach the title slide,
play a fight or two, and find their progress still there after closing and
reopening the app.
