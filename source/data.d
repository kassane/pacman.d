module data;

extern(C):
@nogc nothrow:

// config defines and global constants
enum AUDIO_VOLUME = 0.5f;
enum DBG_SKIP_INTRO = 0; // set to (1) to skip intro
enum DBG_SKIP_PRELUDE = 0; // set to (1) to skip game prelude
enum DBG_START_ROUND = 0; // set to any starting round <=255
enum DBG_MARKERS = 0; // set to (1) to show debug markers
enum DBG_ESCAPE = 0; // set to (1) to leave game loop with Esc
enum DBG_DOUBLE_SPEED = 0; // set to (1) to speed up game (useful with godmode)
enum DBG_GODMODE = 0; // set to (1) to disable dying

// tick duration in nanoseconds

enum TICK_DURATION_NS = 16_666_666;

enum TICK_TOLERANCE_NS = 1000_000; // per-frame tolerance in nanoseconds
enum NUM_VOICES = 3; // number of sound voices
enum NUM_SOUNDS = 3; // max number of sounds effects that can be active at a time
enum NUM_SAMPLES = 128; // max number of audio samples in local sample buffer
enum DISABLED_TICKS = 0xFFFFFFFF; // magic tick value for a disabled timer
enum TILE_WIDTH = 8; // width and height of a background tile in pixels
enum TILE_HEIGHT = 8;
enum SPRITE_WIDTH = 16; // width and height of a sprite in pixels
enum SPRITE_HEIGHT = 16;
enum DISPLAY_TILES_X = 28; // tile buffer width and height
enum DISPLAY_TILES_Y = 36;
enum DISPLAY_PIXELS_X = DISPLAY_TILES_X * TILE_WIDTH;
enum DISPLAY_PIXELS_Y = DISPLAY_TILES_Y * TILE_HEIGHT;
enum NUM_SPRITES = 8;
enum NUM_DEBUG_MARKERS = 16;
enum TILE_TEXTURE_WIDTH = 256 * TILE_WIDTH;
enum TILE_TEXTURE_HEIGHT = TILE_HEIGHT + SPRITE_HEIGHT;
enum MAX_VERTICES = ((DISPLAY_TILES_X * DISPLAY_TILES_Y) + NUM_SPRITES + NUM_DEBUG_MARKERS) * 6;
enum FADE_TICKS = 30; // duration of fade-in/out
enum NUM_LIVES = 3;
enum NUM_STATUS_FRUITS = 7; // max number of displayed fruits at bottom right
enum NUM_DOTS = 244; // 240 small dots + 4 pills
enum NUM_PILLS = 4; // number of energizer pills on playfield
enum ANTEPORTAS_X = 14 * TILE_WIDTH; // pixel position of the ghost house enter/leave point
enum ANTEPORTAS_Y = 14 * TILE_HEIGHT + TILE_HEIGHT / 2;
enum GHOST_EATEN_FREEZE_TICKS = 60; // number of ticks the game freezes after Pacman eats a ghost
enum PACMAN_EATEN_TICKS = 60; // number of ticks to freeze game when Pacman is eaten
enum PACMAN_DEATH_TICKS = 150; // number of ticks to show the Pacman death sequence before starting new round
enum GAMEOVER_TICKS = 3 * 60; // number of ticks the game over message is shown
enum ROUNDWON_TICKS = 4 * 60; // number of ticks to wait after a round was won
enum FRUITACTIVE_TICKS = 10 * 60; // number of ticks a bonus fruit is shown

/* common tile, sprite and color codes, these are the same as on the Pacman
   arcade machine and extracted by looking at memory locations of a Pacman emulator
*/
enum
{
	TILE_SPACE = 0x40,
	TILE_DOT = 0x10,
	TILE_PILL = 0x14,
	TILE_GHOST = 0xB0,
	TILE_LIFE = 0x20, // 0x20..0x23
	TILE_CHERRIES = 0x90, // 0x90..0x93
	TILE_STRAWBERRY = 0x94, // 0x94..0x97
	TILE_PEACH = 0x98, // 0x98..0x9B
	TILE_BELL = 0x9C, // 0x9C..0x9F
	TILE_APPLE = 0xA0, // 0xA0..0xA3
	TILE_GRAPES = 0xA4, // 0xA4..0xA7
	TILE_GALAXIAN = 0xA8, // 0xA8..0xAB
	TILE_KEY = 0xAC, // 0xAC..0xAF
	TILE_DOOR = 0xCF, // the ghost-house door

	SPRITETILE_INVISIBLE = 30,
	SPRITETILE_SCORE_200 = 40,
	SPRITETILE_SCORE_400 = 41,
	SPRITETILE_SCORE_800 = 42,
	SPRITETILE_SCORE_1600 = 43,
	SPRITETILE_CHERRIES = 0,
	SPRITETILE_STRAWBERRY = 1,
	SPRITETILE_PEACH = 2,
	SPRITETILE_BELL = 3,
	SPRITETILE_APPLE = 4,
	SPRITETILE_GRAPES = 5,
	SPRITETILE_GALAXIAN = 6,
	SPRITETILE_KEY = 7,
	SPRITETILE_PACMAN_CLOSED_MOUTH = 48,

	COLOR_BLANK = 0x00,
	COLOR_DEFAULT = 0x0F,
	COLOR_DOT = 0x10,
	COLOR_PACMAN = 0x09,
	COLOR_BLINKY = 0x01,
	COLOR_PINKY = 0x03,
	COLOR_INKY = 0x05,
	COLOR_CLYDE = 0x07,
	COLOR_FRIGHTENED = 0x11,
	COLOR_FRIGHTENED_BLINKING = 0x12,
	COLOR_GHOST_SCORE = 0x18,
	COLOR_EYES = 0x19,
	COLOR_CHERRIES = 0x14,
	COLOR_STRAWBERRY = 0x0F,
	COLOR_PEACH = 0x15,
	COLOR_BELL = 0x16,
	COLOR_APPLE = 0x14,
	COLOR_GRAPES = 0x17,
	COLOR_GALAXIAN = 0x09,
	COLOR_KEY = 0x16,
	COLOR_WHITE_BORDER = 0x1F,
	COLOR_FRUIT_SCORE = 0x03
}

// the top-level game states (intro => game => intro)
enum gamestate_t
{
	GAMESTATE_INTRO = 0,
	GAMESTATE_GAME = 1
}

// directions NOTE: bit0==0: horizontal movement, bit0==1: vertical movement
enum dir_t
{
	DIR_RIGHT = 0, // 000
	DIR_DOWN = 1, // 001
	DIR_LEFT = 2, // 010
	DIR_UP = 3, // 011
	NUM_DIRS = 4
}

// bonus fruit types
enum fruit_t
{
	FRUIT_NONE = 0,
	FRUIT_CHERRIES = 1,
	FRUIT_STRAWBERRY = 2,
	FRUIT_PEACH = 3,
	FRUIT_APPLE = 4,
	FRUIT_GRAPES = 5,
	FRUIT_GALAXIAN = 6,
	FRUIT_BELL = 7,
	FRUIT_KEY = 8,
	NUM_FRUITS = 9
}

// sprite 'hardware' indices
enum sprite_index_t
{
	SPRITE_PACMAN = 0,
	SPRITE_BLINKY = 1,
	SPRITE_PINKY = 2,
	SPRITE_INKY = 3,
	SPRITE_CLYDE = 4,
	SPRITE_FRUIT = 5
}

// ghost types
enum ghosttype_t
{
	GHOSTTYPE_BLINKY = 0,
	GHOSTTYPE_PINKY = 1,
	GHOSTTYPE_INKY = 2,
	GHOSTTYPE_CLYDE = 3,
	NUM_GHOSTS = 4
}

// ghost AI states
enum ghoststate_t
{
	GHOSTSTATE_NONE = 0,
	GHOSTSTATE_CHASE = 1, // currently chasing Pacman
	GHOSTSTATE_SCATTER = 2, // currently heading to the corner scatter targets
	GHOSTSTATE_FRIGHTENED = 3, // frightened after Pacman has eaten an energizer pill
	GHOSTSTATE_EYES = 4, // eaten by Pacman and heading back to the ghost house
	GHOSTSTATE_HOUSE = 5, // currently inside the ghost house
	GHOSTSTATE_LEAVEHOUSE = 6, // currently leaving the ghost house
	GHOSTSTATE_ENTERHOUSE = 7 // currently entering the ghost house
}

// reasons why game loop is frozen
enum freezetype_t
{
	FREEZETYPE_PRELUDE = 1 << 0, // game prelude is active (with the game start tune playing)
	FREEZETYPE_READY = 1 << 1, // READY! phase is active (at start of a new game round)
	FREEZETYPE_EAT_GHOST = 1 << 2, // Pacman has eaten a ghost
	FREEZETYPE_DEAD = 1 << 3, // Pacman was eaten by a ghost
	FREEZETYPE_WON = 1 << 4 // game round was won by eating all dots
}

// a trigger holds a specific game-tick when an action should be started
struct trigger_t
{
	uint tick;
}

// a 2D integer vector (used both for pixel- and tile-coordinates)
struct int2_t
{
	short x;
	short y;
}

// common state for pacman and ghosts
struct actor_t
{
	dir_t dir; // current movement direction
	int2_t pos; // position of sprite center in pixel coords
	uint anim_tick; // incremented when actor moved in current tick
}

// ghost AI state
struct ghost_t
{
	actor_t actor;
	ghosttype_t type;
	dir_t next_dir; // ghost AI looks ahead one tile when deciding movement direction
	int2_t target_pos; // current target position in tile coordinates
	ghoststate_t state;
	trigger_t frightened; // game tick when frightened mode was entered
	trigger_t eaten; // game tick when eaten by Pacman
	ushort dot_counter; // used to decide when to leave the ghost house
	ushort dot_limit;
}

// pacman state
struct pacman_t
{
	actor_t actor;
}

// the tile- and sprite-renderer's vertex structure
struct vertex_t
{
	float x;
	float y; // screen coords [0..1]
	float u;
	float v; // tile texture coords
	uint attr; // x: color code, y: opacity (opacity only used for fade effect)
}

// sprite state
struct sprite_t
{
	bool enabled; // if false sprite is deactivated
	ubyte tile;
	ubyte color; // sprite-tile number (0..63), color code
	bool flipx;
	bool flipy; // horizontal/vertical flip
	int2_t pos; // pixel position of the sprite's top-left corner
}

// debug visualization markers (see DBG_MARKERS)
struct debugmarker_t
{
	bool enabled;
	ubyte tile;
	ubyte color; // tile and color code
	int2_t tile_pos;
}

// callback function prototype for procedural sounds
alias sound_func_t = void function(int sound_slot);

// a sound effect description used as param for snd_start()
struct sound_desc_t
{
	sound_func_t func; // callback function (if procedural sound)
	const(uint)* ptr; // pointer to register dump data (if a register-dump sound)
	uint size; // byte size of register dump data
	bool[3] voice; // true to activate voice
}

// a sound 'hardware' voice
struct voice_t
{
	uint counter; // 20-bit counter, top 5 bits are index into wavetable ROM
	uint frequency; // 20-bit frequency (added to counter at 96kHz)
	ubyte waveform; // 3-bit waveform index
	ubyte volume; // 4-bit volume
	float sample_acc; // current float sample accumulator
	float sample_div; // current float sample divisor
}

// flags for sound_t.flags
enum soundflag_t
{
	SOUNDFLAG_VOICE0 = 1 << 0,
	SOUNDFLAG_VOICE1 = 1 << 1,
	SOUNDFLAG_VOICE2 = 1 << 2,
	SOUNDFLAG_ALL_VOICES = (1 << 0) | (1 << 1) | (1 << 2)
}

// a currently playing sound effect
struct sound_t
{
	uint cur_tick; // current tick counter
	sound_func_t func; // optional function pointer for prodecural sounds
	uint num_ticks; // length of register dump sound effect in 60Hz ticks
	uint stride; // number of uint32_t values per tick (only for register dump effects)
	const(uint)* data; // 3 * num_ticks register dump values
	ubyte flags; // combination of soundflag_t (active voices)
}

// all state is in a single nested struct