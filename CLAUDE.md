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
- Keine Hall-of-Fame-Bestenliste (anders als pacman/galaga) — nur ein
  einzelner High-Score-Wert in `user://settings.cfg` (Abschnitt `hi`).

## Ports

Web-Testserver: **8097** (`.claude/launch.json`, `centipede-web`) — nächster
freier Port unterhalb pacman=8098 (siehe globale CLAUDE.md, Port-Tabelle).
