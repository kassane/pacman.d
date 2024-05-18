module data;

import sg = sokol.gfx;
import sound;

extern (C):
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
enum GameState
{
	GAMESTATE_INTRO = 0,
	GAMESTATE_GAME = 1
}

// directions NOTE: bit0==0: horizontal movement, bit0==1: vertical movement
enum Dir
{
	DIR_RIGHT = 0, // 000
	DIR_DOWN = 1, // 001
	DIR_LEFT = 2, // 010
	DIR_UP = 3, // 011
	NUM_DIRS = 4
}

// bonus fruit types
enum Fruit
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
enum SpriteIndex
{
	SPRITE_PACMAN = 0,
	SPRITE_BLINKY = 1,
	SPRITE_PINKY = 2,
	SPRITE_INKY = 3,
	SPRITE_CLYDE = 4,
	SPRITE_FRUIT = 5
}

// ghost types
enum GhostType
{
	GHOSTTYPE_BLINKY = 0,
	GHOSTTYPE_PINKY = 1,
	GHOSTTYPE_INKY = 2,
	GHOSTTYPE_CLYDE = 3,
	NUM_GHOSTS = 4
}

// ghost AI states
enum GhostState
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
enum FreezeType
{
	FREEZETYPE_PRELUDE = 1 << 0, // game prelude is active (with the game start tune playing)
	FREEZETYPE_READY = 1 << 1, // READY! phase is active (at start of a new game round)
	FREEZETYPE_EAT_GHOST = 1 << 2, // Pacman has eaten a ghost
	FREEZETYPE_DEAD = 1 << 3, // Pacman was eaten by a ghost
	FREEZETYPE_WON = 1 << 4 // game round was won by eating all dots
}

// a trigger holds a specific game-tick when an action should be started
struct Trigger
{
	uint tick;
}

// a 2D integer vector (used both for pixel- and tile-coordinates)
struct Int2
{
	short x;
	short y;
}

// common state for pacman and ghosts
struct Actor
{
	Dir dir; // current movement direction
	Int2 pos; // position of sprite center in pixel coords
	uint anim_tick; // incremented when actor moved in current tick
}

// ghost AI state
struct Ghost
{
	Actor actor;
	GhostType type;
	Dir next_dir; // ghost AI looks ahead one tile when deciding movement direction
	Int2 target_pos; // current target position in tile coordinates
	GhostState state;
	Trigger frightened; // game tick when frightened mode was entered
	Trigger eaten; // game tick when eaten by Pacman
	ushort dot_counter; // used to decide when to leave the ghost house
	ushort dot_limit;
}

// pacman state
struct Pacman
{
	Actor actor;
}

// the tile- and sprite-renderer's vertex structure
struct Vertex
{
	float x = 0.0f;
	float y = 0.0f; // screen coords [0..1]
	float u = 0.0f;
	float v = 0.0f; // tile texture coords
	uint attr; // x: color code, y: opacity (opacity only used for fade effect)
}

// sprite state
struct Sprite
{
	bool enabled; // if false sprite is deactivated
	ubyte tile;
	ubyte color; // sprite-tile number (0..63), color code
	bool flipx;
	bool flipy; // horizontal/vertical flip
	Int2 pos; // pixel position of the sprite's top-left corner
}

// debug visualization markers (see DBG_MARKERS)
struct DebugMarker
{
	bool enabled;
	ubyte tile;
	ubyte color; // tile and color code
	Int2 tile_pos;
}

// callback function prototype for procedural sounds
alias sound_func_t = void function(int sound_slot);

// a sound effect description used as param for snd_start()
struct SoundDesc
{
	sound_func_t func; // callback function (if procedural sound)
	const(uint)* ptr; // pointer to register dump data (if a register-dump sound)
	uint size; // byte size of register dump data
	bool[3] voice; // true to activate voice
}

// a sound 'hardware' voice
struct Voice
{
	uint counter; // 20-bit counter, top 5 bits are index into wavetable ROM
	uint frequency; // 20-bit frequency (added to counter at 96kHz)
	ubyte waveform; // 3-bit waveform index
	ubyte volume; // 4-bit volume
	float sample_acc = 0.0f; // current float sample accumulator
	float sample_div = 0.0f; // current float sample divisor
}

// flags for sound_t.flags
enum SoundFlag
{
	SOUNDFLAG_VOICE0 = 1 << 0,
	SOUNDFLAG_VOICE1 = 1 << 1,
	SOUNDFLAG_VOICE2 = 1 << 2,
	SOUNDFLAG_ALL_VOICES = (1 << 0) | (1 << 1) | (1 << 2)
}

// a currently playing sound effect
struct Sound
{
	uint cur_tick; // current tick counter
	sound_func_t func; // optional function pointer for prodecural sounds
	uint num_ticks; // length of register dump sound effect in 60Hz ticks
	uint stride; // number of uint values per tick (only for register dump effects)
	const(uint)* data; // 3 * num_ticks register dump values
	ubyte flags; // combination of soundflag_t (active voices)
}

// all state is in a single nested struct
struct State
{

	GameState gamestate; // the current gamestate (intro => game => intro)

	struct Timing
	{
		uint tick; // the central game tick, this drives the whole game
		size_t laptime_store; // helper variable to measure frame duration
		int tick_accum; // helper variable to decouple ticks from frame rate
	}

	Timing timing;

	// intro state
	struct Intro
	{
		Trigger started; // tick when intro-state was started
	}

	Intro intro;

	// game state
	struct Game
	{
		uint xorshift; // current xorshift random-number-generator state
		uint hiscore; // hiscore / 10
		Trigger started;
		Trigger ready_started;
		Trigger round_started;
		Trigger round_won;
		Trigger game_over;
		Trigger dot_eaten; // last time Pacman ate a dot
		Trigger pill_eaten; // last time Pacman ate a pill
		Trigger ghost_eaten; // last time Pacman ate a ghost
		Trigger pacman_eaten; // last time Pacman was eaten by a ghost
		Trigger fruit_eaten; // last time Pacman has eaten the bonus fruit
		Trigger force_leave_house; // starts when a dot is eaten
		Trigger fruit_active; // starts when bonus fruit is shown
		ubyte freeze; // combination of FREEZETYPE_* flags
		ubyte round; // current game round, 0, 1, 2...
		uint score; // score / 10
		byte num_lives;
		ubyte num_ghosts_eaten; // number of ghosts easten with current pill
		ubyte num_dots_eaten; // if == NUM_DOTS, Pacman wins the round
		bool global_dot_counter_active; // set to true when Pacman loses a life
		ubyte global_dot_counter; // the global dot counter for the ghost-house-logic
		Ghost[GhostType.NUM_GHOSTS] ghost;
		Pacman pacman;
		Fruit active_fruit;
	}

	Game game;

	// the current input state
	struct Input
	{
		bool enabled;
		bool up;
		bool down;
		bool left;
		bool right;
		bool esc; // only for debugging (see DBG_ESCACPE)
		bool anykey;
	}

	Input input;

	// the audio subsystem is essentially a Namco arcade board sound emulator
	struct Audio
	{
		Voice[NUM_VOICES] voice;
		Sound[NUM_SOUNDS] sound;
		int voice_tick_accum;
		int voice_tick_period;
		int sample_duration_ns;
		int sample_accum;
		uint num_samples;
		float[NUM_SAMPLES] sample_buffer = 0.0f;
	}

	Audio audio;

	// the gfx subsystem implements a simple tile+sprite renderer
	struct Gfx
	{
		// fade-in/out timers and current value
		Trigger fadein;
		Trigger fadeout;
		ubyte fade;

		// the 36x28 tile framebuffer
		ubyte[DISPLAY_TILES_Y][DISPLAY_TILES_X] video_ram; // tile codes
		ubyte[DISPLAY_TILES_Y][DISPLAY_TILES_X] color_ram; // color codes

		// up to 8 sprites
		Sprite[NUM_SPRITES] sprite;

		// up to 16 debug markers
		DebugMarker[NUM_DEBUG_MARKERS] debug_marker;

		// sokol-gfx resources
		sg.PassAction pass_action;
		struct Offscreen
		{
			sg.Buffer vbuf;
			sg.Image tile_img;
			sg.Image palette_img;
			sg.Image render_target;
			sg.Sampler sampler;
			sg.Pipeline pip;
			sg.Attachments attachments;
		}
		Offscreen offscreen;

		struct Display
		{
			sg.Buffer quad_vbuf;
			sg.Pipeline pip;
			sg.Sampler sampler;
		}
		Display display;

		// intermediate vertex buffer for tile- and sprite-rendering
		int num_vertices;
		Vertex[MAX_VERTICES] vertices;

		// scratch-buffer for tile-decoding (only happens once)
		ubyte[TILE_TEXTURE_HEIGHT][TILE_TEXTURE_WIDTH] tile_pixels;

		// scratch buffer for the color palette
		uint[256] color_palette;
	}

	Gfx gfx;
}

// scatter target positions (in tile coords)
static const Int2[GhostType.NUM_GHOSTS] ghost_scatter_targets = [
	{25, 0}, {2, 0}, {27, 34}, {0, 34}
];

// starting positions for ghosts (pixel coords)
static const Int2[GhostType.NUM_GHOSTS] ghost_starting_pos = [
	{14 * 8, 14 * 8 + 4},
	{14 * 8, 17 * 8 + 4},
	{12 * 8, 17 * 8 + 4},
	{16 * 8, 17 * 8 + 4},
];

// target positions for ghost entering the ghost house (pixel coords)
static const Int2[GhostType.NUM_GHOSTS] ghost_house_target_pos = [
	{14 * 8, 17 * 8 + 4},
	{14 * 8, 17 * 8 + 4},
	{12 * 8, 17 * 8 + 4},
	{16 * 8, 17 * 8 + 4},
];

// fruit tiles, sprite tiles and colors
static const ubyte[3][Fruit.NUM_FRUITS] fruit_tiles_colors = [
	[0, 0, 0], // FRUIT_NONE
	[TILE_CHERRIES, SPRITETILE_CHERRIES, COLOR_CHERRIES],
	[TILE_STRAWBERRY, SPRITETILE_STRAWBERRY, COLOR_STRAWBERRY],
	[TILE_PEACH, SPRITETILE_PEACH, COLOR_PEACH],
	[TILE_APPLE, SPRITETILE_APPLE, COLOR_APPLE],
	[TILE_GRAPES, SPRITETILE_GRAPES, COLOR_GRAPES],
	[TILE_GALAXIAN, SPRITETILE_GALAXIAN, COLOR_GALAXIAN],
	[TILE_BELL, SPRITETILE_BELL, COLOR_BELL],
	[TILE_KEY, SPRITETILE_KEY, COLOR_KEY]
];

// the tiles for displaying the bonus-fruit-score, this is a number built from 4 tiles
static const ubyte[4][Fruit.NUM_FRUITS] fruit_score_tiles = [
	[0x40, 0x40, 0x40, 0x40], // FRUIT_NONE
	[0x40, 0x81, 0x85, 0x40], // FRUIT_CHERRIES: 100
	[0x40, 0x82, 0x85, 0x40], // FRUIT_STRAWBERRY: 300
	[0x40, 0x83, 0x85, 0x40], // FRUIT_PEACH: 500
	[0x40, 0x84, 0x85, 0x40], // FRUIT_APPLE: 700
	[0x40, 0x86, 0x8D, 0x8E], // FRUIT_GRAPES: 1000
	[0x87, 0x88, 0x8D, 0x8E], // FRUIT_GALAXIAN: 2000
	[0x89, 0x8A, 0x8D, 0x8E], // FRUIT_BELL: 3000
	[0x8B, 0x8C, 0x8D, 0x8E] // FRUIT_KEY: 5000
];

// level specifications (see pacman_dossier.pdf)
struct LevelSpec
{
	Fruit bonus_fruit;
	uint bonus_score;
	uint fright_ticks;
}

enum
{
	MAX_LEVELSPEC = 21,
}

static const LevelSpec[MAX_LEVELSPEC] levelspec_table = [
	{Fruit.FRUIT_CHERRIES, 10, 6 * 60,},
	{Fruit.FRUIT_STRAWBERRY, 30, 5 * 60,},
	{Fruit.FRUIT_PEACH, 50, 4 * 60,},
	{Fruit.FRUIT_PEACH, 50, 3 * 60,},
	{Fruit.FRUIT_APPLE, 70, 2 * 60,},
	{Fruit.FRUIT_APPLE, 70, 5 * 60,},
	{Fruit.FRUIT_GRAPES, 100, 2 * 60,},
	{Fruit.FRUIT_GRAPES, 100, 2 * 60,},
	{Fruit.FRUIT_GALAXIAN, 200, 1 * 60,},
	{Fruit.FRUIT_GALAXIAN, 200, 5 * 60,},
	{Fruit.FRUIT_BELL, 300, 2 * 60,},
	{Fruit.FRUIT_BELL, 300, 1 * 60,},
	{Fruit.FRUIT_KEY, 500, 1 * 60,},
	{Fruit.FRUIT_KEY, 500, 3 * 60,},
	{Fruit.FRUIT_KEY, 500, 1 * 60,},
	{Fruit.FRUIT_KEY, 500, 1 * 60,},
	{Fruit.FRUIT_KEY, 500, 1,},
	{Fruit.FRUIT_KEY, 500, 1 * 60,},
	{Fruit.FRUIT_KEY, 500, 1,},
	{Fruit.FRUIT_KEY, 500, 1,},
	{Fruit.FRUIT_KEY, 500, 1,},
];

// forward-declared sound-effect register dumps (recorded from Pacman arcade emulator)
static const uint[490] snd_dump_prelude = 0;
static const uint[90] snd_dump_dead = 0;

// sound effect description structs
static const SoundDesc snd_prelude = {
	ptr: snd_dump_prelude.ptr,
	size: snd_dump_prelude.sizeof,
	voice: [true, true, false]
};

static const SoundDesc snd_dead = {
	ptr: snd_dump_dead.ptr,
	size: snd_dump_dead.sizeof,
	voice: [false, false, true]
};

static const SoundDesc snd_eatdot1 = {
    func : &snd_func_eatdot1,
    voice : [ false, false, true ]
};

static const SoundDesc snd_eatdot2 = {
    func : &snd_func_eatdot2,
    voice : [ false, false, true ]
};

static const SoundDesc snd_eatghost = {
    func : &snd_func_eatghost,
    voice : [ false, false, true ]
};

static const SoundDesc snd_eatfruit = {
    func : &snd_func_eatfruit,
    voice : [ false, false, true ]
};

static const SoundDesc snd_weeooh = {
    func : &snd_func_weeooh,
    voice : [ false, true, false ]
};

static const SoundDesc snd_frightened = {
    func : &snd_func_frightened,
    voice: [ false, true, false ]
};

// deactivate a time trigger
static void disable(ref Trigger t)
{
	t.tick = DISABLED_TICKS;
}

// return a disabled time trigger
static Trigger disabled_timer()
{
	Trigger t = {tick: DISABLED_TICKS};
	return t;
}

// shortcut to create an Int2
static Int2 i2(short x, short y)
{
	Int2 res = {x: x, y: y};
	return res;
}

// add two Int2
static Int2 add_i2(Int2 v0, Int2 v1)
{
	Int2 res = {x: cast(short)(v0.x + v1.x), y: cast(short)(v0.y + v1.y)};
	return res;
}

// subtract two Int2
static Int2 sub_i2(Int2 v0, Int2 v1)
{
	Int2 res = {x: cast(short)(v0.x - v1.x), y: cast(short)(v0.y - v1.y)};
	return res;
}

// multiply Int2 with scalar
static Int2 mul_i2(Int2 v, short s)
{
	Int2 z = {x: cast(short)(v.x * s), y: cast(short)(v.y * s)};
	return z;
}

// squared-distance between two Int2
static int squared_distance_i2(Int2 v0, Int2 v1)
{
	Int2 d = {x: cast(short)(v1.x - v0.x), y: cast(short)(v1.y - v0.y)};
	return d.x * d.x + d.y * d.y;
}

// check if two Int2 are equal
static bool equal_i2(Int2 v0, Int2 v1)
{
	return (v0.x == v1.x) && (v0.y == v1.y);
}

// check if two Int2 are nearly equal
static bool nearequal_i2(Int2 v0, Int2 v1, short tolerance)
{
	import core.stdc.stdlib : abs;

	return (abs(v1.x - v0.x) <= tolerance) && (abs(v1.y - v0.y) <= tolerance);
}

// convert an actor pos (origin at center) to sprite pos (origin top left)
static Int2 actor_to_sprite_pos(Int2 pos)
{
	return i2(cast(short)(pos.x - SPRITE_WIDTH / 2), cast(short)(pos.y - SPRITE_HEIGHT / 2));
}

// compute the distance of a pixel coordinate to the next tile midpoint
Int2 dist_to_tile_mid(Int2 pos)
{
	return i2((TILE_WIDTH / 2) - pos.x % TILE_WIDTH, (TILE_HEIGHT / 2) - pos.y % TILE_HEIGHT);
}
