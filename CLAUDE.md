# CLAUDE.md — Centipede

Projekteigene Ergänzungen zur globalen
`~/GodotDev/learn_2d_gamedev_godot_4_0.57.0_linux/CLAUDE.md` (gilt zusätzlich,
nicht ersetzend). Genrevorbild:
[Centipede (Atari, 1981)](https://en.wikipedia.org/wiki/Centipede_(video_game)#Gameplay).

## Design-Entscheidungen (beim Anlegen abgefragt, Stand 2026-09-16)

- **Ausrichtung: Kabinett-Modus wie Galaga.** Mobile/Touch/Web-auf-Handy
  bleiben Hochkant (Design-Canvas 540×960, wie im globalen Standard).
  Desktop-Fenster (Windows/Linux, auch Web im Desktop-Browser bei breitem
  Fenster) schalten bei `Fensterbreite > Fensterhöhe` automatisch in
  Querformat um (`CONTENT_SCALE_ASPECT_EXPAND` + fester `Camera2D` auf die
  Design-Canvas-Mitte + `set_cabinet_lane()` auf Hud/Menus/TouchControls).
  Anders als bei Galaga **keine** Kabinett-Rand-Grafik (`arcade-screen*.png`)
  — der Hintergrund ist ohnehin schwarz (Farbschema, s. u.), die Ränder
  neben der 540px-Spur sind einfach der normale schwarze `Viewport`-Clear,
  ohne Zusatzaufwand. `window/size/window_width_override=960`/
  `window_height_override=540` in `project.godot`, damit das Fenster ohne
  sichtbaren Resize-Sprung startet.
- **Bewegungszone des Spielers ist konfigurabel** (Nutzerwunsch, weicht vom
  reinen Original ab) — `Settings` → „Movement area": **Original** (unterste
  4 Reihen, nah am Trackball-Feeling), **Half** (untere Hälfte des Feldes,
  Default) oder **Full** (ganzes Spielfeld, eher Galaga-artig frei).
  Implementiert in `field_grid.gd` (`FieldGrid.Zone`, `zone_top_row()`) und
  live angewendet in `player.gd`/`game.gd::_apply_settings()`.
- **Vollständiger Gegner-Satz** (Stand 2026-09-16, zweite Ausbaustufe nach dem
  Web-MVP): Centipede (Segment-Splitting + Pilz-Spawn), Spider, **Flea**
  (`flea.gd`, fällt spaltengerade senkrecht, sät dabei neue Pilze —
  ausgelöst von `game.gd::_maybe_spawn_flea()`, sobald die Pilzdichte
  INNERHALB der aktuellen Bewegungszone unter `FLEA_MUSHROOM_THRESHOLD`
  fällt) und **Scorpion** (`scorpion.gd`, kriecht geradlinig durch eine Reihe
  außerhalb der Spielerzone, vergiftet jeden gekreuzten Pilz via
  `mushroom.gd::poison()` — rot eingefärbt). Ein Centipede-Kopf, der beim
  Seitwärtsschritt auf einen vergifteten Pilz trifft, wendet NICHT, sondern
  taucht spaltengerade senkrecht durch (`centipede_chain.gd`'s `_diving`),
  bis er die unterste Reihe erreicht, und macht danach mit der zuvor
  gehaltenen Richtung normal weiter.
- **Farbschema**: Hintergrund Schwarz, Akzent Giftgrün (`#39ff14`,
  `UiStyle.ACCENT`), Text/Spielfiguren-Kontur Weiß. Panel-Rahmen, Button-Rahmen
  und Fokus-Rahmen konsequent giftgrün (`ui_style.gd`).

## Steuerung

- **Bewegung**: Pfeiltasten/WASD (`move_*`-Actions, kontinuierlich mit
  SPEED-Deckel — bei Digital-Eingabe richtig, da es keine „aktuelle
  Zielposition" gibt), Maus-Drag und Finger-Drag (Touch) dagegen **direktes
  1:1-Snapping** auf die Zeigerposition (`player.gd::_snap_to()`, nur bei
  tatsächlicher `InputEventMouseMotion`/`MouseButton`/Touch-Aktivität, siehe
  `player.gd`'s retroaktiver Input-Flip) — **kein**
  `move_toward()`/geschwindigkeitsgedeckeltes Verfolgen, das läse sich sonst
  wie Nachziehen/Verzögerung, sobald der Zeiger schneller springt als das
  Tempo-Limit (derselbe Fund/Fix wie bei Galagas `ship.gd`, jetzt als
  Standard in die globale CLAUDE.md übernommen). Pilze blocken dabei weiter
  pro Achse einzeln. D-Pad/Joypad-Achsen ebenfalls über die SPEED-gedeckelte
  Variante (alles `device=-1`).
- **Schießen**: eigene Action `shoot` (Leertaste, linke Maustaste, Gamepad A
  = `button_index=0`) — per Headless-Skript zur InputMap hinzugefügt (siehe
  globale CLAUDE.md, „`[input]`-Block nie als Text-Literal von Hand"), NICHT
  von Hand ins `project.godot`-Textformat eingetragen. Touch bekommt
  zusätzlich einen eigenen halbtransparenten „FIRE"-Button unten rechts
  (`touch_controls.gd`) — Bewegung per Drag und Feuern brauchen sonst
  denselben Finger.
- **Pause**: P/Esc, **Mute**: M / Gamepad Select (`JOY_BUTTON_BACK=4`).

## Centipede-Bewegungslogik (`centipede_chain.gd`)

Ein Zug ist eine reine `RefCounted`-Kette von `CentipedeSegment`-Nodes. Nur
der Kopf entscheidet pro Grid-Tick (`tick_interval`, abhängig von
Schwierigkeit × Welle) die Richtung; jeder Tick wird die neue Kopfzelle vorn
in `_path` geschoben und auf `segments.size()` gekappt — Segment `i` folgt
einfach `_path[i]` ("Schlange folgt der Route des Kopfes", klassischer
Trick). Beim Treffer eines Rumpfsegments (`hit(index)`) wird `_path` für
BEIDE entstehenden Teilketten aus den AKTUELLEN Zellen ihrer Segmente neu
gesät (`_reseed_path()`) — dadurch gibt es keinen sichtbaren Sprung beim
Split, und beide Teilzüge bewegen sich ab sofort unabhängig weiter.

**Was passiert, wenn eine Kette die unterste Reihe erreicht?** (Nutzerfrage
2026-09-17, per Headless-Test in `_advance()` verifiziert, siehe unten) —
`_advance()`s `else`-Zweig setzt bei einer Blockade `new_row := mini(head.y
+ 1, FieldGrid.field_bottom_row())`: die Kette rutscht **niemals** über die
unterste Reihe hinaus, sie zickzackt dort stattdessen unbegrenzt weiter (dreht
bei jeder Blockade — Feldrand oder Pilz — auf der Stelle um, OHNE dabei seitlich
zu ziehen; genau ein Tick "Wendezeit" pro Richtungswechsel). Das gilt PRO
KETTE unabhängig — landen mehrere Ketten dort (z. B. weil mehrere
Skorpion-Gift-Tauchgänge stattgefunden haben), zickzacken sie alle
unabhängig nebeneinander in derselben Reihe, ohne sich gegenseitig zu
beeinflussen (keine Ketten-vs-Ketten-Kollision, nur Kette-vs-Spieler/Kugel).
Das ist **kein Soft-Lock im rechnerischen Sinn**: die Segmentanzahl der Welle
ist fix (`INITIAL_SEGMENTS` = 12, Splits verteilen nur um, erzeugen nichts
Neues) — jeder Treffer reduziert die Gesamtzahl unwiderruflich, die Welle
wird also rechnerisch IMMER clearbar, sobald genug Treffer landen.

**In der Praxis war das trotzdem ein echtes Problem** (Nutzer-Nachtrag
2026-09-17, „fühlt sich wie eine Endlosschleife an, absichtliches Sterben
hilft auch nicht" — zu Recht, denn Sterben ändert nichts an Position/Zustand
der Kette): Kugeln fliegen nur nach oben. Ein Kopf, der schon in der
untersten Reihe zickzackt, sitzt exakt auf der tiefstmöglichen Position im
gesamten Feld — es gibt dort **keinen sicheren Schussabstand** wie bei einer
noch von oben heranziehenden Kette. Damit der Bullet-Spawnpunkt (knapp über
dem Spieler) überhaupt nah genug an den Kopf herankommt, muss der Spieler
selbst fast auf gleicher Höhe stehen; dieser Abstand liegt fast exakt im
Todesradius (Berührung tötet ab `FieldGrid.CELL * 0.4` = 12px, ein
Bullet-Treffer zählt ab `FieldGrid.CELL * 0.45` = 13,5px) — reiner
Nahkampf auf Messers Schneide, kein Sniping möglich. Das deckt sich mit dem
Original (Strategie-Guides warnen explizit: „if the centipede reaches the
bottom, not only are you at risk of dying"), kann sich aber besonders bei
mehreren gleichzeitig herumgeisternden nackten Köpfen wie eine echte
Sackgasse anfühlen.

**Fix: `CentipedeChain.LONE_HEAD_TIMEOUT`** (15.0s, `centipede_chain.gd`) —
sobald eine Kette auf einen einzelnen Kopf reduziert ist UND dieser Kopf in
der untersten Reihe sitzt, läuft ein Timer (`_lone_head_stuck_t`, pro
`step()`-Aufruf hochgezählt, sofort zurückgesetzt sobald die Bedingung nicht
mehr zutrifft — passiert in der Praxis nie von selbst, s. o., aber
Verteidigung schadet nicht). Überschreitet der Timer `LONE_HEAD_TIMEOUT`,
meldet `is_stuck()` das an `game.gd`, das den Kopf dann per
`_auto_clear_stuck_head()` über GENAU denselben `hit()`-Reward-Pfad wie ein
echter Bullet-Treffer entfernt (Punkte, Ersatz-Pilz, `segment-kill`-Sound,
Punkte-Popup) — für den Spieler kaum vom normalen Treffer zu unterscheiden,
garantiert aber, dass jede Welle in endlicher Zeit fertig wird, ohne den
Nahkampf-Nervenkitzel zu verändern, solange noch ein Rumpf dranhängt. Geprüft
per `_selftest.gd` (Timeout-Grenzfall + „Kette mit Rumpf zählt nie als
stuck") und live im Editor (kompletter Kreislauf: Auto-Clear → Punkte →
Wave-Clear-Trigger → nächste Welle).

## Bekannte offene Punkte

- **Sound-Dateien sind vorerst nur Platzhalter** — `assets/sounds/*.wav`
  (alle 13 Keys aus `sound_manager.gd`s `SOUNDS`-Map) sind synthetische
  Bleeps/Noise-Bursts aus `assets/sounds/gen_placeholder_sfx.py` (reines
  Python-stdlib, `wave`/`struct`/`math`), keine echten Audio-Aufnahmen —
  ersetzen sobald der Nutzer echte Clips liefert (einfach dieselben
  Dateinamen unter `res://assets/sounds/<key>.wav`/`.ogg` überschreiben, dann
  `base_db`-Kalibrierung in `sound_manager.gd` nachjustieren und
  `CALIB_VERSION` hochzählen, wie bei galaga). Skript erneut ausführen nach
  Anpassung einer Definition darin: `python3 assets/sounds/gen_placeholder_sfx.py`.
- **Gameplay-Artwork fehlt noch** — Mushroom/Centipede/Spider/Flea/Scorpion/
  Player sind weiterhin reine `_draw()`-Vektorformen (giftgrün/weiß),
  `icon.svg` und `splash-screen.png` sind Platzhalter. `assets/graphics/`
  (das Wurzelverzeichnis, nicht `assets/graphics/help/`) ist leer angelegt
  für spätere Sprites. Die Hilfe-Illustrationen selbst sind davon **nicht**
  mehr betroffen — siehe unten.
- **Mushroom-Feld wird pro Welle komplett neu gestreut**, statt (wie im
  Original) überlebende Pilze aus der Vorwelle zu behalten. Bewusste
  Vereinfachung fürs MVP.

## Menüs, Navigation & Hall of Fame (Stand 2026-09-17)

Setzt die globale CLAUDE.md-Punkte 18 (Menü-Navigations-Konventionen) und 19
(Hall of Fame) 1:1 um, portiert aus galagas `menus.gd`/`hall_of_fame.gd`.

- **Screens**: Start (Play/Settings/High Scores/How to Play/[Exit]), Pause
  (Resume/Settings/High Scores/How to Play/Restart/Main Menu/[Exit]),
  Settings (+ Sound-Unterseite, jetzt in einem 420px hohen `ScrollContainer`
  — 10 Sound-Regler + Mute-Zeile passten nicht mehr auf einmal), Hilfe
  (bildbasiert, siehe unten), Game Over (+ Hall-of-Fame-Namenseingabe, wenn
  der Score qualifiziert), High Scores (rein lesend).
- **`ui_cancel` (B)** löst screenweit den als `is_cancel` markierten Button
  aus (`_button(text, cb, is_cancel)`), unabhängig vom Fokus — EIN zentraler
  Scan in `_unhandled_input()`, nicht pro Screen verdrahtet. Auf dem rohen
  Pause-/Start-/Game-Over-Screen selbst gibt es bewusst KEIN
  `is_cancel`-Ziel (wie bei galaga) — B wirkt nur auf den Unter-Screens
  (Settings/Sound/Hilfe/High Scores), wo „Zurück" eindeutig ist.
- **Default-Fokus** beim Screen-Wechsel: erster fokussierbarer Control,
  `call_deferred()`. **Ausnahme Hilfe**: Fokus landet bewusst auf „Back"
  (rechtester Button, kein Fokus-Nachbar weiter rechts) statt auf „< Prev" —
  sonst verbraucht der erste D-Pad-rechts-Druck nur den eingebauten
  Fokus-Wechsel zu „Next", bevor das Paging selbst drankommt.
- **Vertikaler D-Pad-Wrap** (`_wrap_focus_vertically()`) für jeden Screen mit
  > 2 auswählbaren Controls — außer Sound (lange scrollbare Liste, „erstes/
  letztes Element" kein stabiles Paar).
- **Hilfe-Paging**: `ui_left`/`ui_right` + Mausrad (Rad runter = nächste
  Seite, wie die „Next >"-Richtung), Punkte-Indikator zwischen Prev/Next,
  wrapt an beiden Enden (`wrapi()`) statt an den Rändern zu deaktivieren.
- **Hall of Fame** (`hall_of_fame.gd`, `user://hall_of_fame.cfg`, Top 10):
  Game-Over-Screen zeigt bei qualifizierendem Score ein Namensfeld (max. 8
  Zeichen, GROSSBUCHSTABEN) + „Enter"-Button neben der Bestenliste;
  ungenutzt gelassen (Play Again/Main Menu/Exit ohne Eingabe), wird
  automatisch als „YOU" nachgetragen (`_maybe_auto_commit()`). Eigener
  „High Scores"-Screen, erreichbar von Start UND Pause
  (`show_highscores(from)`, `_return_screen`-Mechanismus wie bei
  Settings/Hilfe). `LineEdit` fängt `ui_accept` explizit ab (Gamepad-A würde
  sonst nichts auslösen, da `text_submitted` nur bei echtem Enter feuert).
  Ersetzt den früheren einzelnen `user://settings.cfg`-„hi"-Wert komplett.
  **Rang-Kriterium bleibt reiner Score, nicht Score+Welle** (Nutzerfrage
  2026-09-17: fühlte sich falsch an, dass ein Score aus einem langen Kampf
  in einer frühen Welle einen Eintrag aus einer weiter fortgeschrittenen
  Welle in der Liste überholt) — das ist die klassische Arcade-Konvention
  (auch das Original von 1981 rankt rein nach Score, nicht nach erreichter
  Welle) und wird bewusst NICHT geändert. Um das Ergebnis aber nachvollziehbar
  statt mysteriös wirken zu lassen, zeigt `_render_hof()` (in `menus.gd`,
  Game-Over- UND High-Scores-Screen) jetzt eine vierte Spalte „W<n>" mit der
  in `HallOfFame.insert()` ohnehin schon gespeicherten, bisher aber nirgends
  angezeigten Welle — der Vergleich "mehr Punkte bei Welle 2 vs. weniger
  Punkte bei Welle 5" ist damit auf einen Blick sichtbar statt versteckt.

## Hilfe-Illustrationen (Stand 2026-09-17, ersetzt eine erste zu grobe Fassung)

Erste Fassung zeichnete die Steuerungs-Diagramme klein und live per
`Control._draw()` (eigenes `help_diagram.gd`) — Nutzer-Feedback: „nicht
einmal die Tasten richtig dargestellt, geschweige denn die Maus". Jetzt wie
bei **tetris/galaga** bildbasiert: handgemalte SVGs unter `assets/help_src/`,
per `assets/help_src/render.sh` (braucht `inkscape`, von `build.sh` bereits
vor jedem Import aufgerufen) zu 900×980-PNGs unter `assets/graphics/help/`
gerastert, in `menus.gd::_build_help()` per `TextureRect`
(`EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED`) angezeigt.
`help_diagram.gd` wurde komplett entfernt.

- **Zwei Seitensätze** wie bei galagas `_help_pages()`: Desktop
  `[keyboard, mouse, goal]` (3 Seiten), Touch `[touch, goal]` (2 Seiten) —
  ausgewählt über `_touch` (`set_touch_context()`, dieselbe retroaktive
  Erkennung wie überall sonst im Projekt).
- **`keyboard.svg`**: Pfeiltasten-Cluster + „or WASD", Space zum Schießen,
  volles D-Pad-Kreuz + A/B-Kreise (Gamepad-Abschnitt, wie von der globalen
  CLAUDE.md für Projekte mit Gamepad-Support verlangt), Pause- (Esc/P) und
  Mute-Zeile (M/Select) — der Mute-Button-Mockup nutzt exakt dieselben
  Pfad-Koordinaten wie `mute_icon.gd`, damit das Icon in der Hilfe genau so
  aussieht wie im echten HUD.
- **`mouse.svg`**: gezeichnete Maus (nicht nur ein Kreis), „Move = Drag"
  samt „folgt dem Cursor 1:1"-Hinweis, Linksklick-/Mausrad-Callouts.
- **`touch.svg`**: Telefon-Mockup mit den echten Pause-/Mute-Buttons oben
  rechts, Drag-Pfeil in der Bewegungszone, separater „FIRE"-Kreis unten
  rechts (entspricht `touch_controls.gd`s tatsächlicher Platzierung).
- **`goal.svg`**: alle fünf Feld-Objekte (Mushroom/Centipede/Spider/Flea/
  Scorpion) mit denselben Formen/Farben wie ihre echten `_draw()`-Sprites,
  plus den tatsächlichen Punktwerten aus `game.gd` (Kopf 100/Rumpf 10,
  Spider 300–900 gestaffelt) und dem Gift-Tauch-Hinweis.
- **Neu erstellen nach Änderungen an Farbschema oder Steuerung**:
  `bash assets/help_src/render.sh`, dann `--import` — die PNGs sind
  eingecheckt (nicht gitignored, wie bei tetris/galaga), damit der
  Web-Export sie ohne Inkscape-Abhängigkeit zur Laufzeit ausliefert.

## Banner-Übergänge, Respawn-Unverwundbarkeit & Punkte-Popups
## (Stand 2026-09-17, erweitert um „GET READY!" für Spielstart/Respawn)

- **Gemeinsamer Übergangs-Mechanismus** (`game.gd`, `State.TRANSITION`,
  `_begin_transition(text, duration, on_done)`): friert die normale
  PLAYING-Logik (Chain-Ticks, Gegner-Spawns, Kollisionen, Spieler-Input) für
  `duration` Sekunden ein, während `_hud.show_banner(text, duration)` ein
  zentriertes Label (`UiStyle.impact_label`-Look) ein-/hält-/ausblendet
  (Tween, 0.3s/Rest/0.3s). Nach Ablauf ruft `_process()` den in
  `_begin_transition()` übergebenen `on_done`-Callback auf und schaltet
  zurück auf `State.PLAYING`. Pause (P/Esc) funktioniert auch während
  TRANSITION (`_toggle_pause()`/`_unhandled_input()` prüfen beide Zustände) —
  der Countdown pausiert dabei mit (`_paused`-Gate in `_process()`).
  Zwei Verwendungen, beide über denselben Mechanismus, aber mit eigener
  Dauer (`CLEARED_DELAY` bzw. `READY_DELAY` in `game.gd`):
  - **„CLEARED!"** (`_check_wave_clear()`/`_finish_wave_clear()`,
    `CLEARED_DELAY` = 2.0s): sobald `_chains` leer ist, `_snd_play(
    "wave-cleared")` (Fanfare) + `_player.input_enabled = false` fürs
    Einfrieren, danach erhöht sich `_wave` und `_spawn_wave()` läuft.
  - **„GET READY!"** (`_finish_start()` bei `_start_game()`, `_finish_respawn()`
    bei `_kill_player()`, `READY_DELAY` = 3.0s — länger als CLEARED, weil
    hier zusätzlich der eigene `get-ready`-Sound-Stinger reinpassen muss und
    der Spieler tatsächlich Zeit braucht, das Feld anzuschauen, bevor die
    Kontrolle zurückkommt): sowohl beim Start einer neuen Runde als auch nach
    jedem Lebensverlust (sofern noch Leben übrig — beim letzten Leben läuft
    stattdessen direkt `_game_over()`, kein Banner) wird der Spieler SOFORT
    auf `_spawn_point()` gesetzt (`_player.reset()`), aber mit
    `input_enabled = false` bewegungs-/schussunfähig, bis das Banner fertig
    ist — der Spieler sieht das Schiff also die ganze Bannerdauer über
    unten mittig stehen, statt erst zu verschwinden und dann wieder
    aufzutauchen. Dauer ist bewusst an keinen Sound-Längen-Wert gekoppelt
    (Platzhalter-Clips ändern sich noch) — beim Einbau echter Audiodateien
    `READY_DELAY` ggf. an die tatsächliche `get-ready`-Clip-Länge anpassen.
- **Respawn-Unverwundbarkeit** (`player.gd::set_invulnerable()`/
  `invulnerable`, `game.gd::RESPAWN_INVULN` = 2.0s) — Nutzerfrage 2026-09-17:
  „wie kann der Spieler den Gegner in der untersten Zeile aufhalten, in die
  er nach einem Lebensverlust respawnt?". Recherche zum Original (1981)
  ergab: dort gibt es **keine** eingebaute Unverwundbarkeit oder Freiraum-
  Garantie beim Respawn — die Standard-Referenz ist rein proaktives
  Feld-Management (Pilze in der eigenen Zone niedrig halten, die Centipede
  gar nicht erst bis zur untersten Reihe kommen lassen; siehe Quellen unten).
  Das erklärt aber nicht das eigene Problem: unser `State.TRANSITION`-Freeze
  (siehe oben) hält zwar alles an, setzt den Spieler aber exakt auf
  `_spawn_point()` zurück — sitzt zufällig schon ein Centipede-Segment/
  Spider/Scorpion auf oder neben dieser festen Zelle, würde die Kollision
  sofort im ersten Frame nach Ende von TRANSITION wieder feuern, noch bevor
  der Spieler sich überhaupt bewegen kann — das ist ein reales, durch den
  Freeze SELBST eingeführtes Problem (im Original bewegt sich der Spieler ja
  ohne Zwangs-Pause weiter), keins aus dem Original übernehmbares Verhalten.
  Fix: zusätzlich zum Freeze bekommt der Spieler nach `_finish_start()`/
  `_finish_respawn()` (also erst wenn die Kontrolle zurückkommt, nicht
  während des Banners selbst) `RESPAWN_INVULN` Sekunden lang echte
  Berührungs-Unverwundbarkeit (`_check_player_collisions()` überspringt bei
  `_player.invulnerable`) bei voller Beweglichkeit/Schussfähigkeit — genug
  Zeit (2s × 300 px/s Speed), um aus jeder Ecke des Feldes rauszukommen.
  Sichtbares Blinken (`player.gd::_draw()`, 8 Hz) signalisiert den Zustand.
  Bewusst NUR für Start/Respawn, nicht für den Wave-Wechsel (dort verliert
  der Spieler kein Leben und wird nicht neu positioniert, das Problem
  besteht dort nicht).
- **Punkte-Popups** (`score_popup.gd`/`.tscn`, `class_name ScorePopup`):
  kleines „+N"-Textlabel (`_draw()`-basiert wie die übrigen Spielobjekte),
  blendet über 0.5s ein/aus und driftet dabei leicht nach oben, friert sich
  danach selbst (`queue_free()`). Bewusst nur für die Kills ausgelöst
  (`game.gd::_spawn_score_popup()`), die tatsächlich einen eigenen Punktwert
  haben und selten genug vorkommen, um nicht zur visuellen Unruhe zu werden:
  Centipede-**Kopf**-Treffer, Spider, Scorpion, **Flea** — NICHT für
  Rumpfsegmente oder Pilztreffer (1 Punkt, treten viel zu häufig auf). Sounds
  für Hits dieser Items existierten bereits vorher (`segment-kill`/
  `spider-kill`/`scorpion-kill`/`flea-kill` in `sound_manager.gd`, aufgerufen
  aus denselben `_bullet_vs_*()`-Stellen in `game.gd`) — keine Änderung nötig.

## Ports

Web-Testserver: **8097** (`.claude/launch.json`, `centipede-web`) — nächster
freier Port unterhalb pacman=8098 (siehe globale CLAUDE.md, Port-Tabelle).
