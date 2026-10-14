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
- Schnelles Einfügen mit ⌘1 bis ⌘9, Bearbeiten und Umbenennen von Karten
- **Als reiner Text einfügen** (⌥⇧⌘V, in den Einstellungen änderbar): fügt die Zwischenablage überall ohne Formatierung ein

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

## Installieren (für Freunde)

1. Unter **Releases** auf GitHub die neueste `Pastely-….dmg` laden und öffnen.
2. Pastely in den Ordner **Applications** ziehen und starten.
3. macOS meldet beim ersten Start, dass es die App nicht prüfen kann. Dann **System Settings → Privacy & Security** öffnen, ganz nach unten scrollen und bei Pastely **Open Anyway** wählen, danach noch einmal bestätigen.
4. Unter **System Settings → Privacy & Security → Accessibility** Pastely erlauben, damit es in andere Apps einfügen kann.

Leiste öffnen mit ⇧⌘V. Eine neue Version installiert man genauso: Sie ersetzt die alte, die Accessibility-Freigabe bleibt erhalten, nur Schritt 3 kann nochmals nötig sein.

## Weitergeben

```bash
VERSION=1.0.1 BUILD=2 bash scripts/release.sh
```

Das legt `packaging/Pastely-<Version>.dmg` ab, signiert mit dem eigenen Zertifikat „Pastely Developer“. Die Datei als Release auf GitHub hochladen:

```bash
gh release create v1.0.1 packaging/Pastely-1.0.1.dmg --title "Pastely 1.0.1"
```

Optional ohne die Warnung aus Schritt 3: Mit einem **Developer ID Application**-Zertifikat (Xcode → Settings → Accounts → Manage Certificates) und einem gespeicherten Notarisierungs-Profil (`xcrun notarytool store-credentials pastely-notary --apple-id … --team-id B9A464EMSV`, mit einem App-spezifischen Passwort) lässt `release.sh` die App zusätzlich von Apple notarisieren.

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
