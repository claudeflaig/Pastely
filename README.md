# Pastely

Ein Zwischenablage-Manager für macOS im Stil von [Paste](https://pasteapp.io): eine Kartenleiste am Bildschirmrand, Pinboards für Vorlagen und alles, was du kopierst, durchsuchbar.

Pastely ist ein Fork von [Pesty](https://github.com/momenbasel/pesty) von Moamen Basel (MIT-Lizenz) und baut darauf auf.

## Funktionen

- **Kartenleiste im Paste-Stil**, unten oder oben am Bildschirm, hell, dunkel oder passend zum System
- **Pinboards** als Vorlagen-Sammlungen: Karte auf einen Tab ziehen speichert sie dort, Farben pro Pinboard
- **Link-Vorschau** mit Seitenbild, Favicon und Titel
- **Farbkarten**, die die ganze Karte mit der Farbe füllen
- **CleanShot X**: der Aufnahme-Verlauf erscheint automatisch als eigener Tab
- **Suche** über Text, Links, Dateien und erkannten Text in Bildern und Screenshots (OCR)
- **Filter** nach Typ, Quell-App und Datum
- **Paste Stack** (⇧⌘C): mehrere Einträge sammeln und mit ⌘V der Reihe nach einfügen
- Schnelles Einfügen mit ⌘1 bis ⌘9, Einfügen als reiner Text, Bearbeiten und Umbenennen von Karten

## Bauen und starten

Voraussetzung: macOS 14 oder neuer, Xcode bzw. die Swift-Toolchain.

```bash
swift build && .build/debug/Pastely --demo
```

`--demo` füllt die Leiste mit Beispielkarten. Als richtige App:

```bash
bash scripts/build_app.sh && open /Applications/Pastely.app
```

Damit Pastely direkt in andere Apps einfügen und den Paste Stack weiterschalten kann, braucht es die Berechtigung **Bedienungshilfen**.

### Berechtigungen dauerhaft behalten

Ohne Zertifikat signiert das Build-Skript Pastely „ad hoc“. macOS hält dann jeden Neubau für eine neue App und vergisst die Freigaben (Accessibility, Full Disk Access, Downloads). Ein eigenes Zertifikat behebt das, einmalig:

1. **Keychain Access** öffnen → Menü **Keychain Access → Certificate Assistant → Create a Certificate…**
2. Name: `Pastely Developer`, Identity Type: **Self Signed Root**, Certificate Type: **Code Signing** → **Create**.
3. `bash scripts/build_app.sh` erneut ausführen. Fragt macOS, ob `codesign` den Schlüssel verwenden darf: **Always Allow**.
4. Die Freigaben ein letztes Mal erteilen. Ab dann bleiben sie bei jedem Neubau erhalten.

## An Freunde weitergeben

Das eigene Zertifikat gilt nur auf diesem Mac. Für andere Macs signiert `scripts/release.sh` mit einer Developer ID, lässt Apple die App prüfen (Notarisierung) und legt `packaging/Pastely-<Version>.dmg` ab. Diese Datei öffnet sich überall ohne Warnung.

Einmalig einrichten (braucht die Mitgliedschaft im Apple Developer Program):

1. **Xcode → Settings → Accounts** → Apple-ID wählen → **Manage Certificates…** → **+** → **Developer ID Application**.
2. Auf [account.apple.com](https://account.apple.com) unter **Sign-In and Security → App-Specific Passwords** ein Passwort für „Pastely Notarisierung“ erzeugen.
3. Die Zugangsdaten im Schlüsselbund speichern (fragt nach dem Passwort aus Schritt 2):
   ```bash
   xcrun notarytool store-credentials pastely-notary --apple-id DEINE_APPLE_ID --team-id B9A464EMSV
   ```

Danach für jede Version:

```bash
VERSION=1.0.1 BUILD=2 bash scripts/release.sh
```

Bei den Freunden: DMG öffnen, Pastely in **Applications** ziehen, starten und unter **System Settings → Privacy & Security → Accessibility** erlauben. Updates gibt es nur so, wie man sie verschickt: eine neue DMG, die die alte App ersetzt.

## Tests

```bash
swift test
```

Liegt das Projekt in einem über iCloud synchronisierten Ordner (z. B. Dokumente), hängt iCloud Zusatzinfos an die Build-Dateien und die Signierung der Tests schlägt fehl. Dann mit einem Build-Ordner außerhalb von iCloud testen:

```bash
swift test --scratch-path ~/Library/Caches/Pastely-build
```

## Aus Pasty umziehen

Unter Einstellungen → History → „Import from Pasty“ übernimmt Pastely alle Pinboards samt Vorlagen-Titeln aus Pasty. macOS verlangt dafür einmalig Zugriff auf Pastys Daten (Festplattenvollzugriff für Pastely).

## Lizenz

MIT, siehe [LICENSE](LICENSE). Der ursprüngliche Copyright-Hinweis von Pesty bleibt erhalten.
