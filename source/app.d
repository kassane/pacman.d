module pacman;

/*------------------------------------------------------------------------------
    pacman.d

    A Pacman clone written in D using the sokol headers for platform
    abstraction. Based on original pacman.c by floooh

    The git repository is here:

    https://github.com/kassane/pacman.d

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

import sg = sokol.gfx;
import sglue = sokol.glue;
import sapp = sokol.app;
import log = sokol.log;
import data;
import rom;

extern (C):


static void init() {
    sg.Desc gfx = {
        environment: sglue.environment(),
        logger: { func: &log.slog_func },
    };
    sg.setup(gfx);
    debug {
        import std.stdio : writeln;
        try {
            writeln("Backend: ", sg.queryBackend());
        } catch (Exception) {}
    }
}

static void frame() {
    // const g = pass_action.colors[0].clear_value.g + 0.01;
    // pass_action.colors[0].clear_value.g = g > 1.0 ? 0.0 : g;
    // sg.Pass pass = {action: pass_action, swapchain: sglue.swapchain};
    // sg.beginPass(pass);
    sg.endPass();
    sg.commit();
}

static void cleanup() {
    sg.shutdown();
}

void main() @nogc nothrow
{
	sapp.Desc runner = {
		window_title: "pacman.d",
		init_cb: &init,
		frame_cb: &frame,
		cleanup_cb: &cleanup,
		width: 640,
		height: 480,
		win32_console_attach: true,
		icon: {sokol_default: true},
		logger: {func: &log.func}
	};
	sapp.run(runner);
}
