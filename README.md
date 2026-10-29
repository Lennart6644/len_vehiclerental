# len_vehiclerental

Autor: Lennart

## Voraussetzungen

- es_extended (ESX Legacy)
- oxmysql
- OneSync (Infinity oder Legacy)

## Installation

1. Ordner `len_vehiclerental` in deinen `resources`-Ordner kopieren.
2. Die Datei `sql/len_vehiclerental.sql` in deiner Datenbank ausführen.
3. In der `server.cfg` hinzufügen:

```
ensure oxmysql
ensure es_extended
ensure len_vehiclerental
```

4. Die Datei `config.lua` anpassen (Sprache, Stationen, Preise, Versicherungen, Schlüsselsystem).

## Sprache

In `config.lua` unter `Config.Locale` auf `'de'` oder `'en'` stellen. Alle Texte stehen in `locales/de.lua` und `locales/en.lua`.

## Fahrzeugbilder

Lege Bilder unter `html/img/vehicles/` ab, benannt nach dem Spawnnamen:

- `m4f82.webp` oder `m4f82.png`

Fehlt ein Bild, wird ein Platzhalter angezeigt. Zusätzlich gibt es im Spiel eine Live-Vorschau: Beim Auswählen eines Fahrzeugs erscheint das Spawnmodell am Spawnpunkt mit einer rotierenden Kamera (nur für den Spieler sichtbar).

## Schlüsselsystem

`Config.Keys.system` kann auf `'auto'` stehen oder auf einen dieser Werte:

- `Renewed-Vehiclekeys`
- `qs-vehiclekeys`
- `wasabi_carlock`
- `qb-vehiclekeys`
- `esx_vehiclelock`
- `none`

Bitte prüfe die Export-Namen in `client/keys.lua` gegen die Version deines Schlüsselsystems.

## Ablauf

- Mieten an den Stationen (E), Kaution und Versicherung werden beim Mieten bezahlt.
- Kilometer werden während der Fahrt automatisch abgerechnet.
- Schäden werden anhand der Fahrzeugbeschädigung berechnet, Versicherungen reduzieren die Kosten.
- Nach Ablauf der Mietzeit wird eine Verspätungsgebühr fällig. Nach `Config.Penalties.stolenAfter` Minuten werden Polizisten alarmiert.
- Fahrzeuge verschwinden nicht automatisch: Sie müssen an der Rückgabestelle abgegeben werden.
- Nicht bezahlbare Beträge werden als Schulden gespeichert. Solange Schulden offen sind, kann kein neues Fahrzeug gemietet werden.
