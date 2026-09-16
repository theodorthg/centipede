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

## Bekannte offene Punkte

- **Sound-Dateien fehlen** — `sound_manager.gd` ist vollständig vorbereitet
  (`SOUNDS`-Map mit allen benötigten Keys, Lautstärke-Unterseite in den
  Settings funktioniert bereits), erwartet Clips unter
  `res://assets/sounds/<key>.ogg`/`.wav`. `base_db`-Kalibrierung ist aktuell
  überall `0.0` (neutral) — muss nachjustiert werden, sobald echte Clips da
  sind (`CALIB_VERSION` hochzählen, wie bei galaga).
- **Artwork fehlt** — Mushroom/Centipede/Spider/Player sind aktuell reine
  `_draw()`-Vektorformen (giftgrün/weiß), `icon.svg` und `splash-screen.png`
  sind Platzhalter. `assets/graphics/` ist leer angelegt für spätere Sprites.
- **Hilfe-Seite 2 (Regeltext) kann im Kabinett-Modus (540px Fensterhöhe)
  knapp über den unteren Fensterrand hinauslaufen**, wenn der Fließtext viele
  Zeilen umbricht — funktional kein Problem (Panel bleibt lesbar, nichts wird
  abgeschnitten was zur Bedienung nötig ist: Buttons liegen weiter oben),
  aber optisch nicht perfekt zentriert. Eher kürzen oder Schriftgröße
  reduzieren als Scroll-Container einbauen, wenn das stört.
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
  (2 Seiten, siehe unten), Game Over (+ Hall-of-Fame-Namenseingabe, wenn der
  Score qualifiziert), High Scores (rein lesend).
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

## Ports

Web-Testserver: **8097** (`.claude/launch.json`, `centipede-web`) — nächster
freier Port unterhalb pacman=8098 (siehe globale CLAUDE.md, Port-Tabelle).
