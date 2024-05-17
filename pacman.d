module pacman;

/*------------------------------------------------------------------------------
    pacman.c

    A Pacman clone written in C99 using the sokol headers for platform
    abstraction.

    The git repository is here:

    https://github.com/floooh/pacman.c

    A WASM version running in browsers can be found here:

    https://floooh.github.io/pacman.c/pacman.html

    Some basic concepts and ideas are worth explaining upfront:

    The game code structure is a bit "radical" and sometimes goes against
    what is considered good practice for medium and large code bases. This is
    fine because this is a small game written by a single person. Small
    code bases written by small teams allow a different organizational
    approach than large code bases written by large teams.

    Here are some of those "extremist" methods used in this tiny project:

    Instead of artificially splitting the code into many small source files,
    everything is in a single source file readable from top to bottom.

    Instead of data-encapsulation and -hiding, all data lives in a single,
    global, nested data structure (this isn't actually as radical and
    experimental as it sounds, I've been using this approach for quite a
    while now for all my hobby code). An interesting side effect of this
    upfront-defined static memory layout is that there are no dynamic
    allocations in the entire game code (only a handful allocations during
    initialization of the Sokol headers).

    Instead of "wasting" time thinking too much about high-level abstractions
    and reusability, the code has been written in a fairly adhoc-manner "from
    start to finish", solving problems as they showed up in the most direct
    way possible. When parts of the code became too entangled I tried to step
    back a bit, take a pause and come back later with a better idea how to
    rewrite those parts in a more straightforward manner. Of course
    "straightforward" and "readability" are in the eye of the beholder.

    The actual gameplay code (Pacman and ghost behaviours) has been
    implemented after the "Pacman Dossier" by Jamey Pittman (a PDF copy has
    been included in the project), but there are some minor differences to a
    Pacman arcade machine emulator, some intended, some not
    (https://floooh.github.io/tiny8bit/pacman.html):

        - The attract mode animation in the intro screen is missing (where
          Pacman is chased by ghosts, eats a pill and then hunts the ghost).
        - Likewise, the 'interlude' animation between levels is missing.
        - Various difficulty-related differences in later maps are ignored
          (such a faster movement speed, smaller dot-counter-limits for ghosts etc)

    The rendering and audio code resembles the original Pacman arcade machine
    hardware:

        - the tile and sprite pixel data, hardware color palette data and
          sound wavetable data is taken directly from embedded arcade machine
          ROM dumps
        - background tiles are rendered from two 28x36 byte buffers (one for
          tile-codes, the other for color-codes), this is similar to an actual
          arcade machine, with the only difference that the tile- and color-buffer
          has a straightforward linear memory layout
        - background tile rendering is done with dynamically uploaded vertex
          data (two triangles per tile), with color-palette decoding done in
          the pixel shader
        - up to 8 16x16 sprites are rendered as vertex quads, with the same
          color palette decoding happening in the pixel shader as for background
          tiles.
        - audio output works through an actual Namco WSG emulator which generates
          sound samples for 3 hardware voices from a 20-bit frequency counter,
          4-bit volume and 3-bit wave type (for 8 wavetables made of 32 sample
          values each stored in a ROM dump)
        - sound effects are implemented by writing new values to the hardware
          voice 'registers' once per 60Hz tick, this can happen in two ways:
            - as 'procedural' sound effects, where a callback function computes
              the new voice register values
            - or via 'register dump' playback, where the voice register values
              have been captured at 60Hz frequency from an actual Pacman arcade
              emulator
          Only two sound effects are register dumps: the little music track at
          the start of a game, and the sound effect when Pacman dies. All other
          effects are simple procedural effects.

    The only concept worth explaining in the gameplay code is how timing
    and 'asynchronous actions' work:

    The entire gameplay logic is driven by a global 60 Hz game tick which is
    counting upward.

    Gameplay actions are initiated by a combination of 'time triggers' and a simple
    vocabulary to initialize and test trigger conditions. This time trigger system
    is an extremely simple replacement for more powerful event systems in
    'proper' game engines.

    Here are some pseudo-code examples how time triggers can be used (unrelated
    to Pacman):

    To immediately trigger an action in one place of the code, and 'realize'
    this action in one or several other places:

        // if a monster has been eaten, trigger the 'monster eaten' action:
        if (monster_eaten()) {
            start(&state.game.monster_eaten);
        }

        // ...somewhere else, we might increase the score if a monster has been eaten:
        if (now(state.game.monster_eaten)) {
            state.game.score += 10;
        }

        // ...and yet somewhere else in the code, we might want to play a sound effect
        if (now(state.game.monster_eaten)) {
            // play sound effect...
        }

    We can also start actions in the future, which allows to batch multiple
    followup-actions in one place:

        // start fading out now, after one second (60 ticks) start a new
        // game round, and fade in, after another second when fadein has
        // finished, start the actual game loop
        start(&state.gfx.fadeout);
        start_after(&state.game.started, 60);
        start_after(&state.gfx.fadein, 60);
        start_after(&state.game.gameloop_started, 2*60);

    As mentioned above, there's a whole little function vocabulary built around
    time triggers, but those are hopefully all self-explanatory.
*/

extern (C):

// memset()
// abs()

// config defines and global constants
enum AUDIO_VOLUME = 0.5f;
enum DBG_SKIP_INTRO = 0; // set to (1) to skip intro
enum DBG_SKIP_PRELUDE = 0; // set to (1) to skip game prelude
enum DBG_START_ROUND = 0; // set to any starting round <=255
enum DBG_MARKERS = 0; // set to (1) to show debug markers
enum DBG_ESCAPE = 0; // set to (1) to leave game loop with Esc
enum DBG_DOUBLE_SPEED = 0; // set to (1) to speed up game (useful with godmode)
enum DBG_GODMODE = 0; // set to (1) to disable dying

// NOTE: DO NOT CHANGE THESE DEFINES TO AN ENUM
// gcc-13 will turn the backing type into an unsigned integer which then
// causes all sorts of trouble further down

// tick duration in nanoseconds

enum TICK_DURATION_NS = 16666666;

enum TICK_TOLERANCE_NS = 1000000; // per-frame tolerance in nanoseconds
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
alias sound_func_t = void function (int sound_slot);

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
struct
{
    gamestate_t gamestate; // the current gamestate (intro => game => intro)

    // the central game tick, this drives the whole game
    // helper variable to measure frame duration
    // helper variable to decouple ticks from frame rate
    struct struct (unnamed at pacman.c:423:5)
    {
        uint tick;
        ulong laptime_store;
        int tick_accum;
    }

    struct timing;

    // intro state

    // tick when intro-state was started
    struct struct (unnamed at pacman.c:430:5)
    {
        trigger_t started;
    }

    struct (unnamed at pacman.c:430:5) intro;

    // game state

    // current xorshift random-number-generator state
    // hiscore / 10

    // last time Pacman ate a dot
    // last time Pacman ate a pill
    // last time Pacman ate a ghost
    // last time Pacman was eaten by a ghost
    // last time Pacman has eaten the bonus fruit
    // starts when a dot is eaten
    // starts when bonus fruit is shown
    // combination of FREEZETYPE_* flags
    // current game round, 0, 1, 2...
    // score / 10

    // number of ghosts easten with current pill
    // if == NUM_DOTS, Pacman wins the round
    // set to true when Pacman loses a life
    // the global dot counter for the ghost-house-logic
    struct struct (unnamed at pacman.c:435:5)
    {
        uint xorshift;
        uint hiscore;
        trigger_t started;
        trigger_t ready_started;
        trigger_t round_started;
        trigger_t round_won;
        trigger_t game_over;
        trigger_t dot_eaten;
        trigger_t pill_eaten;
        trigger_t ghost_eaten;
        trigger_t pacman_eaten;
        trigger_t fruit_eaten;
        trigger_t force_leave_house;
        trigger_t fruit_active;
        ubyte freeze;
        ubyte round;
        uint score;
        byte num_lives;
        ubyte num_ghosts_eaten;
        ubyte num_dots_eaten;
        bool global_dot_counter_active;
        ubyte global_dot_counter;
        ghost_t[NUM_GHOSTS] ghost;
        pacman_t pacman;
        fruit_t active_fruit;
    }

    struct (unnamed at pacman.c:435:5) game;

    // the current input state

    // only for debugging (see DBG_ESCACPE)
    struct struct (unnamed at pacman.c:464:5)
    {
        bool enabled;
        bool up;
        bool down;
        bool left;
        bool right;
        bool esc;
        bool anykey;
    }

    struct (unnamed at pacman.c:464:5) input;

    // the audio subsystem is essentially a Namco arcade board sound emulator
    struct struct (unnamed at pacman.c:475:5)
    {
        voice_t[3] voice;
        sound_t[3] sound;
        int voice_tick_accum;
        int voice_tick_period;
        int sample_duration_ns;
        int sample_accum;
        uint num_samples;
        float[128] sample_buffer;
    }

    struct (unnamed at pacman.c:475:5) audio;

    // the gfx subsystem implements a simple tile+sprite renderer

    // fade-in/out timers and current value

    // the 36x28 tile framebuffer
    // tile codes
    // color codes

    // up to 8 sprites

    // up to 16 debug markers

    // sokol-gfx resources

    // intermediate vertex buffer for tile- and sprite-rendering

    // scratch-buffer for tile-decoding (only happens once)

    // scratch buffer for the color palette
    struct struct (unnamed at pacman.c:487:5)
    {
        trigger_t fadein;
        trigger_t fadeout;
        ubyte fade;
        ubyte[28][36] video_ram;
        ubyte[28][36] color_ram;
        sprite_t[8] sprite;
        debugmarker_t[16] debug_marker;
        sg_pass_action pass_action;

        struct struct (unnamed at pacman.c:505:9)
        {
            sg_buffer vbuf;
            sg_image tile_img;
            sg_image palette_img;
            sg_image render_target;
            sg_sampler sampler;
            sg_pipeline pip;
            sg_attachments attachments;
        }

        struct (unnamed at pacman.c:505:9) offscreen;

        struct struct (unnamed at pacman.c:514:9)
        {
            sg_buffer quad_vbuf;
            sg_pipeline pip;
            sg_sampler sampler;
        }

        struct (unnamed at pacman.c:514:9) display;
        int num_vertices;
        vertex_t[6192] vertices;
        ubyte[2048][24] tile_pixels;
        uint[256] color_palette;
    }

    struct (unnamed at pacman.c:487:5) gfx;
}

extern __gshared struct (unnamed at pacman.c:419:8) state;

// scatter target positions (in tile coords)
extern __gshared const(int2_t)[NUM_GHOSTS] ghost_scatter_targets;

// starting positions for ghosts (pixel coords)
extern __gshared const(int2_t)[NUM_GHOSTS] ghost_starting_pos;

// target positions for ghost entering the ghost house (pixel coords)
extern __gshared const(int2_t)[NUM_GHOSTS] ghost_house_target_pos;

// fruit tiles, sprite tiles and colors

// FRUIT_NONE
extern __gshared const(ubyte)[3][NUM_FRUITS] fruit_tiles_colors;

// the tiles for displaying the bonus-fruit-score, this is a number built from 4 tiles

// FRUIT_NONE
// FRUIT_CHERRIES: 100
// FRUIT_STRAWBERRY: 300
// FRUIT_PEACH: 500
// FRUIT_APPLE: 700
// FRUIT_GRAPES: 1000
// FRUIT_GALAXIAN: 2000
// FRUIT_BELL: 3000
// FRUIT_KEY: 5000
extern __gshared const(ubyte)[4][NUM_FRUITS] fruit_score_tiles;

// level specifications (see pacman_dossier.pdf)
struct levelspec_t
{
    fruit_t bonus_fruit;
    ushort bonus_score;
    ushort fright_ticks;
    // FIXME: the various Pacman and ghost speeds
}

enum enum (unnamed at pacman.c:587:1)
{
    MAX_LEVELSPEC = 21
}

// from here on repeating
extern __gshared const(levelspec_t)[MAX_LEVELSPEC] levelspec_table;

// forward-declared sound-effect register dumps (recorded from Pacman arcade emulator)
extern __gshared const(uint)[490] snd_dump_prelude;
extern __gshared const(uint)[90] snd_dump_dead;

// procedural sound effect callbacks
void snd_func_eatdot1 (int slot);
void snd_func_eatdot2 (int slot);
void snd_func_eatghost (int slot);
void snd_func_eatfruit (int slot);
void snd_func_weeooh (int slot);
void snd_func_frightened (int slot);

// sound effect description structs
extern __gshared const sound_desc_t snd_prelude;

extern __gshared const sound_desc_t snd_dead;

extern __gshared const sound_desc_t snd_eatdot1;

extern __gshared const sound_desc_t snd_eatdot2;

extern __gshared const sound_desc_t snd_eatghost;

extern __gshared const sound_desc_t snd_eatfruit;

extern __gshared const sound_desc_t snd_weeooh;

extern __gshared const sound_desc_t snd_frightened;

// forward declarations
void init ();
void frame ();
void cleanup ();
void input (const(sapp_event)*);

void start (trigger_t* t);
bool now (trigger_t t);

void intro_tick ();
void game_tick ();

void input_enable ();
void input_disable ();

void gfx_init ();
void gfx_shutdown ();
void gfx_fade ();
void gfx_draw ();

void snd_init ();
void snd_shutdown ();
void snd_tick (); // called per game tick
void snd_frame (int frame_time_ns); // called per frame
void snd_clear ();
void snd_start (int sound_slot, const(sound_desc_t)* snd);
void snd_stop (int sound_slot);

// forward-declared ROM dumps
extern __gshared const(ubyte)[4096] rom_tiles;
extern __gshared const(ubyte)[4096] rom_sprites;
extern __gshared const(ubyte)[32] rom_hwcolors;
extern __gshared const(ubyte)[256] rom_palette;
extern __gshared const(ubyte)[256] rom_wavetable;

/*== APPLICATION ENTRY AND CALLBACKS =========================================*/
sapp_desc sokol_main (int argc, char** argv);

// start into intro screen
void init ();

// run the game at a fixed tick rate regardless of frame rate

// clamp max frame time (so the timing isn't messed up when stopping in the debugger)

// call per-tick sound function (updates sound 'registers' with current sound effect values)

// check for game state change

// call the top-level game state update function
void frame ();

void input (const(sapp_event)* ev);

void cleanup ();

/*== GRAB BAG OF HELPER FUNCTIONS ============================================*/

// xorshift random number generator
uint xorshift32 ();
// get level spec for a game round
levelspec_t levelspec (int round);

// set time trigger to the next game tick
void start (trigger_t* t);

// set time trigger to a future tick
void start_after (trigger_t* t, uint ticks);

// deactivate a time trigger
void disable (trigger_t* t);

// return a disabled time trigger
trigger_t disabled_timer ();

// check if a time trigger is triggered
bool now (trigger_t t);

// return the number of ticks since a time trigger was triggered
uint since (trigger_t t);

// check if a time trigger is between begin and end tick
bool between (trigger_t t, uint begin, uint end);

// check if a time trigger was triggered exactly N ticks ago
bool after_once (trigger_t t, uint ticks);

// check if a time trigger was triggered more than N ticks ago
bool after (trigger_t t, uint ticks);

// same as between(t, 0, ticks)
bool before (trigger_t t, uint ticks);

// clear input state and disable input
void input_disable ();

// enable input again
void input_enable ();

// get the current input as dir_t
dir_t input_dir (dir_t default_dir);

// shortcut to create an int2_t
int2_t i2 (short x, short y);

// add two int2_t
int2_t add_i2 (int2_t v0, int2_t v1);

// subtract two int2_t
int2_t sub_i2 (int2_t v0, int2_t v1);

// multiply int2_t with scalar
int2_t mul_i2 (int2_t v, short s);

// squared-distance between two int2_t
int squared_distance_i2 (int2_t v0, int2_t v1);

// check if two int2_t are equal
bool equal_i2 (int2_t v0, int2_t v1);

// check if two int2_t are nearly equal
bool nearequal_i2 (int2_t v0, int2_t v1, short tolerance);

// convert an actor pos (origin at center) to sprite pos (origin top left)
int2_t actor_to_sprite_pos (int2_t pos);

// compute the distance of a pixel coordinate to the next tile midpoint
int2_t dist_to_tile_mid (int2_t pos);

// clear tile and color buffer
void vid_clear (ubyte tile_code, ubyte color_code);

// clear the playfield's rectangle in the color buffer
void vid_color_playfield (ubyte color_code);

// check if a tile position is valid
bool valid_tile_pos (int2_t tile_pos);

// put a color into the color buffer
void vid_color (int2_t tile_pos, ubyte color_code);

// put a tile into the tile buffer
void vid_tile (int2_t tile_pos, ubyte tile_code);

// put a colored tile into the tile and color buffers
void vid_color_tile (int2_t tile_pos, ubyte color_code, ubyte tile_code);

// translate ASCII char into "NAMCO char"
char conv_char (char c);

// put colored char into tile+color buffers
void vid_color_char (int2_t tile_pos, ubyte color_code, char chr);

// put char into tile buffer
void vid_char (int2_t tile_pos, char chr);

// put colored text into the tile+color buffers
void vid_color_text (int2_t tile_pos, ubyte color_code, const(char)* text);

// put text into the tile buffer
void vid_text (int2_t tile_pos, const(char)* text);

/* print colored score number into tile+color buffers from right to left(!),
    scores are /10, the last printed number is always 0,
    a zero-score will print as '00' (this is the same as on
    the Pacman arcade machine)
*/
void vid_color_score (int2_t tile_pos, ubyte color_code, uint score);

/* draw a colored tile-quad arranged as:
    |t+1|t+0|
    |t+3|t+2|

   This is (for instance) used to render the current "lives" and fruit
   symbols at the lower border.
*/
void vid_draw_tile_quad (int2_t tile_pos, ubyte color_code, ubyte tile_code);

// draw the fruit bonus score tiles (when Pacman has eaten the bonus fruit)
void vid_fruit_score (fruit_t fruit_type);

// disable and clear all sprites
void spr_clear ();

// get pointer to pacman sprite
sprite_t* spr_pacman ();

// get pointer to ghost sprite
sprite_t* spr_ghost (ghosttype_t type);

// get pointer to fruit sprite
sprite_t* spr_fruit ();

// set sprite to animated Pacman

// animation frames for horizontal and vertical movement

// horizontal (needs flipx)
// vertical (needs flipy)
void spr_anim_pacman (dir_t dir, uint tick);

// set sprite to Pacman's death sequence

// the death animation tile sequence starts at sprite tile number 52 and ends at 63
void spr_anim_pacman_death (uint tick);

// set sprite to animated ghost

// right
// down
// left
// up
void spr_anim_ghost (ghosttype_t ghost_type, dir_t dir, uint tick);

// set sprite to frightened ghost

// towards end of frightening period, start blinking
void spr_anim_ghost_frightened (ghosttype_t ghost_type, uint tick);

/* set sprite to ghost eyes, these are the normal ghost sprite
    images but with a different color code which makes
    only the eyes visible
*/
void spr_anim_ghost_eyes (ghosttype_t ghost_type, dir_t dir);

// convert pixel position to tile position
int2_t pixel_to_tile_pos (int2_t pix_pos);

// clamp tile pos to valid playfield coords
int2_t clamped_tile_pos (int2_t tile_pos);

// convert a direction to a movement vector
int2_t dir_to_vec (dir_t dir);

// return the reverse direction
dir_t reverse_dir (dir_t dir);

// return tile code at tile position
ubyte tile_code_at (int2_t tile_pos);

// check if a tile position contains a blocking tile (walls and ghost house door)
bool is_blocking_tile (int2_t tile_pos);

// check if a tile position contains a dot tile
bool is_dot (int2_t tile_pos);

// check if a tile position contains a pill tile
bool is_pill (int2_t tile_pos);

// check if a tile position is in the teleport tunnel
bool is_tunnel (int2_t tile_pos);

// check if a position is in the ghost's red zone, where upward movement is forbidden
// (see Pacman Dossier "Areas To Exploit")
bool is_redzone (int2_t tile_pos);

// test if movement from a pixel position in a wanted direction is possible,
// allow_cornering is Pacman's feature to take a diagonal shortcut around corners

// distance to midpoint in move direction and perpendicular direction

// look one tile ahead in movement direction

// way is blocked

// way is free
bool can_move (int2_t pos, dir_t wanted_dir, bool allow_cornering);

// compute a new pixel position along a direction (without blocking check!)

// if cornering is allowed, drag the position towards the center-line

// wrap x-position around (only possible in the teleport-tunnel)
int2_t move (int2_t pos, dir_t dir, bool allow_cornering);

// set a debug marker

/*== GAMEPLAY CODE ===========================================================*/

// initialize the playfield tiles

// decode the playfield from an ASCII map into tiles codes

//0123456789012345678901234567
// 3
// 4
// 5
// 6
// 7
// 8
// 9
// 10
// 11
// 12
// 13
// 14
// 15
// 16
// 17
// 18
// 19
// 20
// 21
// 22
// 23
// 24
// 25
// 26
// 27
// 28
// 29
// 30
// 31
// 32
// 33
//0123456789012345678901234567

// ghost house gate colors
void game_init_playfield ();

// disable all game loop timers
void game_disable_timers ();

// one-time init at start of game state

// draw the playfield and PLAYER ONE READY! message
void game_init ();

// setup state at start of a game round

// clear the "PLAYER ONE" text

/* if a new round was started because Pacman has "won" (eaten all dots),
    redraw the playfield and reset the global dot counter
*/

/* if the previous round was lost, use the global dot counter
   to detect when ghosts should leave the ghost house instead
   of the per-ghost dot counter
*/

// random-number-generator seed

// the force-house timer forces ghosts out of the house if Pacman isn't
// eating dots for a while

// Pacman starts running to the left

// Blinky starts outside the ghost house, looking to the left, and in scatter mode

// Pinky starts in the middle slot of the ghost house, moving down

// Inky starts in the left slot of the ghost house moving up

// FIXME: needs to be adjusted by current round!

// Clyde starts in the right slot of the ghost house, moving up

// FIXME: needs to be adjusted by current round!
void game_round_init ();

// update dynamic background tiles

// print score and hiscore

// update the energizer pill colors (blinking/non-blinking)

// clear the fruit-eaten score after Pacman has eaten a bonus fruit

// remaining lives at bottom left screen

// bonus fruit list in bottom-right corner

// if game round was won, render the entire playfield as blinking blue/white
void game_update_tiles ();

// this function takes care of updating all sprite images during gameplay

// update Pacman sprite

// hide Pacman shortly after he's eaten a ghost (via an invisible Sprite tile)

// special case game frozen at start of round, show Pacman with 'closed mouth'

// play the Pacman-death-animation after a short pause

// regular Pacman animation

// update ghost sprites

// if Pacman has just died, hide ghosts

// if Pacman has won the round, hide ghosts

// if the ghost was *just* eaten by Pacman, the ghost's sprite
// is replaced with a score number for a short time
// (200 for the first ghost, followed by 400, 800 and 1600)

// afterwards, the ghost's eyes are shown, heading back to the ghost house

// ...still show the ghost eyes while entering the ghost house

// when inside the ghost house, show the normal ghost images
// (FIXME: ghost's inside the ghost house also show the
// frightened appearance when Pacman has eaten an energizer pill)

// show the regular ghost sprite image, the ghost's
// 'next_dir' is used to visualize the direction the ghost
// is heading to, this has the effect that ghosts already look
// into the direction they will move into one tile ahead

// hide or display the currently active bonus fruit
void game_update_sprites ();

// return true if Pacman should move in this tick, when eating dots, Pacman
// is slightly slower than ghosts, otherwise slightly faster

// eating a dot causes Pacman to stop for 1 tick

// eating an energizer pill causes Pacman to stop for 3 ticks
bool game_pacman_should_move ();

// return number of pixels a ghost should move this tick, this can't be a simple
// move/don't move boolean return value, because ghosts in eye state move faster
// than one pixel per tick

// inside house at half speed (estimated)

// move at 50% speed when frightened

// estimated 1.5x when in eye state, Pacman Dossier is silent on this

// move drastically slower when inside tunnel

// otherwise move just a bit slower than Pacman
int game_ghost_speed (const(ghost_t)* ghost);

// return the current global scatter or chase phase
ghoststate_t game_scatter_chase_phase ();

// this function takes care of switching ghosts into a new state, this is one
// of two important functions of the ghost AI (the other being the target selection
// function below)

// When in eye state (heading back to the ghost house), check if the
// target position in front of the ghost house has been reached, then
// switch into ENTERHOUSE state. Since ghosts in eye state move faster
// than one pixel per tick, do a fuzzy comparison with the target pos

// Ghosts that enter the ghost house during the gameplay loop immediately
// leave the house again after reaching their target position inside the house.

// Ghosts only remain in the "house state" after a new game round
// has been started. The conditions when ghosts leave the house
// are a bit complicated, best to check the Pacman Dossier for the details.

// if Pacman hasn't eaten dots for 4 seconds, the next ghost
// is forced out of the house
// FIXME: time is reduced to 3 seconds after round 5

// if Pacman has lost a life this round, the global dot counter is used

// NOTE that global dot counter is deactivated if (and only if) Clyde
// is in the house and the dot counter reaches 32

// in the normal case, check the ghost's personal dot counter

// ghosts immediately switch to scatter mode after leaving the ghost house

// switch between frightened, scatter and chase mode

// handle state transitions

// after leaving the ghost house, head to the left

// a ghost that was eaten is immune to frighten until Pacman eats enother pill

// don't reverse direction when leaving frightened state

// any transition from scatter and chase mode causes a reversal of direction
void game_update_ghost_state (ghost_t* ghost);

// update the ghost's target position, this is the other important function
// of the ghost's AI

// when in scatter mode, each ghost heads to its own scatter
// target position in the playfield corners

// when in chase mode, each ghost has its own particular
// chase behaviour (see the Pacman Dossier for details)

// Blinky directly chases Pacman

// Pinky target is 4 tiles ahead of Pacman
// FIXME: does not reproduce 'diagonal overflow'

// Inky targets an extrapolated pos along a line two tiles
// ahead of Pacman through Blinky

// if Clyde is far away from Pacman, he chases Pacman,
// but if close he moves towards the scatter target

// in frightened state just select a random target position
// this has the effect that ghosts in frightened state
// move in a random direction at each intersection

// move towards the ghost house door
void game_update_ghost_target (ghost_t* ghost);

// compute the next ghost direction, return true if resulting movement
// should always happen regardless of current ghost position or blocking
// tiles (this special case is used for movement inside the ghost house)

// inside ghost-house, just move up and down

// force movement

// navigate the ghost out of the ghost house

// navigate towards the ghost house target pos

// scatter/chase/frightened: just head towards the current target point

// only compute new direction when currently at midpoint of tile

// new direction is the previously computed next-direction

// compute new next-direction

// try each direction and take the one that moves closest to the target

// if ghost is in one of the two 'red zones', forbid upward movement
// (see Pacman Dossier "Areas To Exploit")
bool game_update_ghost_dir (ghost_t* ghost);

/* Update the dot counters used to decide whether ghosts must leave the house.

    This is called each time Pacman eats a dot.

    Each ghost has a dot limit which is reset at the start of a round. Each time
    Pacman eats a dot, the highest priority ghost in the ghost house counts
    down its dot counter.

    When the ghost's dot counter reaches zero the ghost leaves the house
    and the next highest-priority dot counter starts counting.

    If a life is lost, the personal dot counters are deactivated and instead
    a global dot counter is used.

    If pacman doesn't eat dots for a while, the next ghost is forced out of the
    house using a timer.
*/

// if the new round was started because Pacman lost a life, use the global
// dot counter (this mode will be deactivated again after all ghosts left the
// house)

// otherwise each ghost has his own personal dot counter to decide
// when to leave the ghost house
void game_update_ghosthouse_dot_counters ();

// called when a dot or pill has been eaten, checks if a round has been won
// (all dots and pills eaten), whether to show the bonus fruit, and finally
// plays the dot-eaten sound effect

// all dots eaten, round won

// at 70 and 170 dots, show the bonus fruit

// play alternating crunch sound effect when a dot has been eaten
void game_update_dots_eaten ();

// the central Pacman and ghost behaviour function, called once per game tick

// Pacman "AI"

// move Pacman with cornering allowed

// look ahead to check if the wanted direction is blocked

// move into the selected direction

// eat dot or energizer pill?

// check if Pacman eats the bonus fruit

// check if Pacman collides with any ghost

// Pacman eats a frightened ghost

// increase score by 20, 40, 80, 160

// otherwise, ghost eats Pacman, Pacman loses a life

// if Pacman has any lives left start a new round, otherwise start the game-over sequence

// Ghost "AIs"

// handle ghost-state transitions

// update the ghost's target position

// finally, move the ghost towards the current target position
void game_update_actors ();

// the central game tick function, called at 60 Hz

// debug: skip prelude

// initialize game state once

// initialize new round (each time Pacman looses a life), make actors visible, remove "PLAYER ONE", start a new life

// after 2 seconds start the interactive game loop

// clear the 'READY!' message

// activate/deactivate bonus fruit

// stop frightened sound and start weeooh sound

// if game is frozen because Pacman ate a ghost, unfreeze after a while

// play pacman-death sound

// the actually important part: update Pacman and ghosts, update dynamic
// background tiles, and update the sprite images

// update hiscore

// check for end-round condition

// display game over string

// visualize current ghost targets
void game_tick ();

/*== INTRO GAMESTATE CODE ====================================================*/

// on intro-state enter, enable input and draw any initial text

// draw the animated 'ghost image.. name.. nickname' lines

// 2*3 ghost image created from tiles (no sprite!)

// after 1 second, the name of the ghost

// after 0.5 seconds, the nickname of the ghost

// . 10 PTS
// O 50 PTS

// blinking "press any key" text

// FIXME: animated chase sequence

// if a key is pressed, advance to game state
void intro_tick ();

/*== GFX SUBSYSTEM ===========================================================*/

/* create all sokol-gfx resources */

// pass action for clearing the background to black

// create a dynamic vertex buffer for the tile and sprite quads

// create a simple quad vertex buffer for rendering the offscreen render target to the display

// shader sources for all platforms (FIXME: should we use precompiled shader blobs instead?)

// (0..31) / 255
// (0..3) / 255

// create pipeline and shader object for rendering into offscreen render target

// create pipeline and shader for rendering into display

// create a render target image with a fixed upscale ratio

// create an sampler to render the offscreen render target with linear upscale filtering

// pass object for rendering into the offscreen render target

// create the 'tile-ROM-texture'

// create the palette texture

// create a sampler with nearest filtering for the offscreen pass
void gfx_create_resources ();

/*
    8x4 tile decoder (taken from: https://github.com/floooh/chips/blob/master/systems/namco.h)

    This decodes 2-bit-per-pixel tile data from Pacman ROM dumps into
    8-bit-per-pixel texture data (without doing the RGB palette lookup,
    this happens during rendering in the pixel shader).

    The Pacman ROM tile layout isn't exactly strightforward, both 8x8 tiles
    and 16x16 sprites are built from 8x4 pixel blocks layed out linearly
    in memory, and to add to the confusion, since Pacman is an arcade machine
    with the display 90 degree rotated, all the ROM tile data is counter-rotated.

    Tile decoding only happens once at startup from ROM dumps into a texture.
*/
void gfx_decode_tile_8x4 (
    uint tex_x,
    uint tex_y,
    const(ubyte)* tile_base,
    uint tile_stride,
    uint tile_offset,
    ubyte tile_code);

// decode an 8x8 tile into the tile texture's upper half
void gfx_decode_tile (ubyte tile_code);

// decode a 16x16 sprite into the tile texture's lower half
void gfx_decode_sprite (ubyte sprite_code);

// decode the Pacman tile- and sprite-ROM-dumps into a 8bpp texture

// write a special opaque 16x16 block which will be used for the fade-effect
void gfx_decode_tiles ();

/* decode the Pacman color palette into a palette texture, on the original
    hardware, color lookup happens in two steps, first through 256-entry
    palette which indirects into a 32-entry hardware-color palette
    (of which only 16 entries are used on the Pacman hardware)
*/

/*
    Each color ROM entry describes an RGB color in 1 byte:

    | 7| 6| 5| 4| 3| 2| 1| 0|
    |B1|B0|G2|G1|G0|R2|R1|R0|

    Intensities are: 0x97 + 0x47 + 0x21
 */

// first color in each color block is transparent
void gfx_decode_color_palette ();

// reduce pool allocation size to what's actually needed
void gfx_init ();

void gfx_shutdown ();

void gfx_add_vertex (
    float x,
    float y,
    float u,
    float v,
    ubyte color_code,
    ubyte opacity);

/*
    x0,y0
    +-----+
    | *   |
    |   * |
    +-----+
            x1,y1
*/
void gfx_add_tile_vertices (
    uint tx,
    uint ty,
    ubyte tile_code,
    ubyte color_code);

void gfx_add_playfield_vertices ();

void gfx_add_debugmarker_vertices ();

void gfx_add_sprite_vertices ();

// sprite tile 64 is a special 16x16 opaque block
void gfx_add_fade_vertices ();

// adjust the viewport so that the aspect ratio is always correct
void gfx_adjust_viewport (int canvas_width, int canvas_height);

// handle fadein/fadeout
void gfx_fade ();

// handle fade in/out

// update the playfield and sprite vertex buffer

// render tiles and sprites into offscreen render target

// upscale-render the offscreen render target into the display framebuffer
void gfx_draw ();

/*== AUDIO SUBSYSTEM =========================================================*/

// compute sample duration in nanoseconds

/* compute number of 96kHz ticks per sample tick (the Namco sound generator
    runs at 96kHz), times 1000 for increased precision
*/
void snd_init ();

void snd_shutdown ();

// the snd_voice_tick() function updates the Namco sound generator and must be called with 96 kHz

/* lookup current 4-bit sample from the waveform number and the
    topmost 5 bits of the 20-bit sample counter
*/

// sample is (-8..+7 wavetable value) * 16 (volume)
void snd_voice_tick ();

// the snd_sample_tick() function must be called with sample frequency (e.g. 44.1kHz)
void snd_sample_tick ();

// the sound subsystem's per-frame function

// for each sample to generate...

// tick the sound generator at 96 KHz

// generate a new sample, and push out to sokol-audio when local sample buffer full
void snd_frame (int frame_time_ns);

/* The sound system's 60 Hz tick function (called from game tick).
    Updates the sound 'hardware registers' for all active sound effects.
*/

// for each active sound effect...

// procedural sound effect

// register-dump sound effect

// decode register dump values into voice 'registers'

// 20 bits frequency

// 3 bits waveform

// 4 bits volume
void snd_tick ();

// clear all active sound effects and start outputting silence
void snd_clear ();

// start a sound effect

// procedural sounds only need a callback function
void snd_start (int slot, const(sound_desc_t)* desc);

// stop a sound effect

// silence the sound's output voices

// clear the sound slot
void snd_stop (int slot);

// procedural sound effects
void snd_func_eatdot1 (int slot);

void snd_func_eatdot2 (int slot);

void snd_func_eatghost (int slot);

void snd_func_eatfruit (int slot);

void snd_func_weeooh (int slot);

void snd_func_frightened (int slot);

/*== EMBEDDED DATA ===========================================================*/

// Pacman sprite ROM dump

/*== SOUND EFFECT REGISTER DUMPS =============================================*/

/*
    Each line is a 'register dump' for one 60Hz tick. Each 32-bit number
    encodes the per-voice values for frequency, waveform and volume:

    31                              0 bit
    |vvvv-www----ffffffffffffffffffff|
      |    |              |
      |    |              +-- 20 bits frequency
      |    +-- 3 bits waveform
      +-- 4 bits volume
*/

