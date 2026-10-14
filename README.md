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
bash scripts/build_app.sh && open packaging/Pastely.app
```

Damit Pastely direkt in andere Apps einfügen und den Paste Stack weiterschalten kann, braucht es die Berechtigung **Bedienungshilfen**.

## Tests

```bash
swift test
```

## Lizenz

MIT, siehe [LICENSE](LICENSE). Der ursprüngliche Copyright-Hinweis von Pesty bleibt erhalten.
