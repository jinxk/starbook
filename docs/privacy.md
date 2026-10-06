# Privacy

Starbook collects nothing.

It is used by young children, so it is built to have nothing to collect. There is no account, no login, no analytics, no ads, no crash reporter and no in-app purchase. The app declares no internet permission, so it cannot make a network call even by mistake.

## Where data lives

The child's name and picture, the packs you import, the awards given, trophies and reading progress are kept in a SQLite database inside the app's own storage on the phone. Nothing else can read it.

A backup file you save or share yourself is the only copy outside the app. It is one JSON file with the stars, stickers, trophies, habits, this week's tasks, the child's name and picture, the packs and the settings. Starbook sends it nowhere: it goes to the folder or app you pick in the Android share or save dialog. Restoring reads a file you pick, checks it, and changes nothing if it is not a good Starbook backup.

Android's own automatic backup may keep a copy of the app's data in your Google account, as it does for other apps. Turn it off in Android settings, under Backup, if you would rather it did not.

## Read-aloud

Words and stories are played from the recorded voice packs inside the app, with no network. Text that has no recorded clip is spoken by the phone's own text-to-speech engine. Starbook sends it the text to speak and nothing else. If the voice for a language is not downloaded, some engines fetch speech from the internet; the Settings screen shows when that would happen and links to the phone's voice settings so you can download the voice.

## Imported packs

A pack is plain text (JSON). Importing one never runs code. The parent sees the pack's title and contents before it is added. A file opened with Starbook from another app waits behind the parent gate and is read only on the phone.

## Permissions

None.
