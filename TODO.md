# TODO — centipede

Offene Punkte sammeln und abhaken (gilt über Kontextwechsel hinaus; siehe
globale CLAUDE.md „TODO.md pro Projekt“). Neueste Einträge oben. Ältere
offene Punkte stehen noch in `CLAUDE.md` → „Bekannte offene Punkte“.

## Offen

- [ ] Alte, von Hand hochgeladene Dateien auf itch.io löschen (macht der Nutzer: https://itch.io/game/edit/…, Seite `centipede-clone`) und beim Upload des Channels `web` „This file will be played in the browser“ setzen.
- [ ] Übrige Punkte aus `CLAUDE.md` „Bekannte offene Punkte“ hierher
      übernehmen.

Ideen für später (Einschätzung 2026-10-03, noch nicht beauftragt):
- [x] 2026-10-05 2 Spieler abwechselnd (wie der Automat): eigenes Pilzfeld
      pro Spieler, Players-Menü wie mario-clone.
- [x] 2026-10-05 Zwei Geräte per LAN/WLAN und Online (Relay): Duell — jedes
      Gerät spielt sein eigenes Spiel gleichzeitig, gleicher Seed, Gegner-
      Stand live im HUD, Rematch, Rundenstand. (Kein Host-rechnet-Gast-zeigt:
      das Spiel braucht es nicht, siehe CLAUDE.md „Mehrspieler".)
- [ ] Coop gleichzeitig: zwei Schützen in der Spielerzone. Mechanisch
      passt das gut (geteilte Tastatur / zwei Pads / Maus + Pad), Spinne
      zielt auf den nächsten. Mittlerer Nutzen.
- [ ] Inhalt im Stil von Millipede: neue Gegner (Biene, Ohrwurm),
      DDT-Bomben im Pilzfeld, wechselnde Farben/Themen pro Welle.
- Empfehlung: abwechselnd ja (billig); Coop nur, wenn Galaga-Coop schon
  steht (dieselben Bausteine).

Gemeinsam für die Serie (Vorlage: mario-clone v1.6–v1.9):
- [ ] Bausteine aus mario-clone übernehmen statt neu erfinden: `CoopInput`
      + Beitreten-Bildschirm (jeder drückt A auf seinem Gerät),
      `NetLink`/`NetHost`/`NetClient` (Host rechnet, Gast zeigt; LAN +
      Online), Team-Eintrag in der Bestenliste, Spielstand/Continue,
      F12-Screenshot.
- [ ] Ein Relay für alle Spiele: `server/relay.js` um eine Spiel-Kennung
      in „host“/„join“ erweitern (sonst landet ein Galaga-Gast in einem
      Mario-Raum), Pfad bleibt `wss://broesel.net/mario-relay` oder ein
      neutraler Name.
- Hinweise: Hochkant-Spiele auf dem Handy zu zweit nur per Netz (zwei
  Leute an einem Handy-Bildschirm ist unpraktisch); lokal zu zweit am PC
  (geteilte Tastatur / zwei Pads) bzw. im Browser. Das RG552 kann wegen
  des kaputten Bluetooth kein zweites Pad.

## Erledigt

- [x] 2026-09-29 itch.io jetzt per `butler` in die Channels linux / android / windows / web (`theodorthg/centipede-clone`, wie bei mario-clone); Patch-Release v1.0.1: Stand seit v1.0.0 (Splash mit Ladebalken, Cover-Art, App-Icons, weißer Android-Startbildschirm) — damit Windows-Release und itch.io aktuell sind.
- [x] 2026-09-27 Android-System-Startbildschirm (vor dem Splash) einheitlich
      reines Weiß: `splash_screen/icon` = transparentes
      `assets/icon/android_splash_blank.png`, `branding_image` leer (Nutzer-
      wunsch, ohne Gradle-Build; Hintergrundfarbe ließe sich nur per Gradle
      ändern).
- [x] 2026-09-27 RG552: alte debug-signierte Version auf Nutzerwunsch
      deinstalliert, neuer release-Build installiert (+ APK im Download-
      Ordner aktualisiert).
- [x] 2026-09-27 Cover-Art (Nutzer): Hochformat-Bild für Splash +
      Startbildschirm hochkant, Querformat-Bild (18.09., Text auf „PRESS
      START“ umgestellt) quer; „PRESS START“-Wartebildschirm vor dem
      Start-Menü; neues App-Icon aus dem Kopf des Tausendfüßlers,
      Android-Icon-Verweise auf `tetris-icon …` korrigiert.
- [x] 2026-09-26 Neuer Splash (Nutzer-Grafik „ULTIMATE CENTIPEDE CLONE“)
      mit weichgezeichnetem Hintergrund für Hochformat.
- [x] 2026-09-26 Handy (CPH2581): alte debug-signierte Version auf
      Nutzerwunsch deinstalliert, release-Build installiert.
- [x] 2026-09-26 Splash mit Fake-Ladebalken (`splash.gd`), Boot-Splash-
      Mindestzeit 0,5 s.
