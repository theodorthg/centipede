class_name Waves

## Wave rules in one place (pure functions, covered by _selftest.gd), after the
## original arcade game:
##  - the mushroom field is KEPT from wave to wave (game.gd only tops it up);
##    between waves every damaged/poisoned mushroom regrows for REGROW_SCORE;
##  - wave n starts with a shorter train plus n-1 single heads (at most
##    MAX_EXTRA_HEADS) that follow one after the other — the total number of
##    segments stays the same, there are just more heads to deal with;
##  - DDT bombs (Millipede): a bomb in the field blows up everything within
##    BLAST_RADIUS cells when it is shot.

const MUSHROOM_BASE_COUNT := 32      ## wave 1
const WAVE_ADD_MUSHROOMS := 6        ## every later wave tops the field up by this many
const MUSHROOM_CAP := 72             ## ... but never past this (a 18 x 28 field)
const MAX_EXTRA_HEADS := 8
const HEAD_FIRST_DELAY := 3.0        ## seconds until the first single head enters
const HEAD_INTERVAL := 2.0           ## ... and between the following ones
const REGROW_SCORE := 5
const MAX_DDT := 3
const BLAST_RADIUS := 2.6            ## in cells

static func extra_heads(wave: int) -> int:
	return clampi(wave - 1, 0, MAX_EXTRA_HEADS)

## Segments of the main train (the rest of `total` arrives as single heads).
static func main_length(total: int, wave: int) -> int:
	return total - extra_heads(wave)

## How many mushrooms this wave adds (wave 1 builds the field, later waves top it up).
static func mushrooms_to_add(wave: int, have: int) -> int:
	var want := MUSHROOM_BASE_COUNT if wave <= 1 else WAVE_ADD_MUSHROOMS
	return clampi(want, 0, maxi(MUSHROOM_CAP - have, 0))

## DDT bombs that should be in the field at the start of this wave.
static func ddt_target(wave: int) -> int:
	return mini(1 + maxi(wave - 1, 0) / 3, MAX_DDT)

static func in_blast(center: Vector2i, cell: Vector2i) -> bool:
	return Vector2(cell - center).length() <= BLAST_RADIUS
