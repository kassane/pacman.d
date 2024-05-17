module pacman;

/*------------------------------------------------------------------------------
    pacman.d

    A Pacman clone written in D using the sokol headers for platform
    abstraction. Based on original pacman.c by floooh

    The git repository is here:

    https://github.com/kassane/pacman.d

    See comment header here for some implementation details:
    https://github.com/floooh/pacman.c/blob/main/pacman.c
---------------------------------------------------------------------------------*/

import sg = sokol.gfx;
import sglue = sokol.glue;
import sapp = sokol.app;
import log = sokol.log;
import saudio = sokol.audio;
import data;
import rom;

extern (C):

static void init()
{
  sg.Desc gfx = {
    buffer_pool_size: 2,
    image_pool_size: 3,
    shader_pool_size: 2,
    pipeline_pool_size: 2,
    attachments_pool_size: 1,
    environment: sglue.environment(),
    logger: {func: &log.slog_func},
  };
  sg.setup(gfx);

  // add flag: --d-version=DbgSkipIntro
  version (DbgSkipIntro)
  {
    start(state.game.started);
  }
  else
  {
    start(state.intro.started);
  }
}

static void cleanup()
{
  sg.shutdown;
  saudio.shutdown;
}

static void start(ref Trigger t) {
    t.tick = state.timing.tick + 1;
}

static void frame()
{

  // run the game at a fixed tick rate regardless of frame rate
  uint frame_time_ns = cast(uint)(sapp.frameDuration * 1000_000_000.0);
  // clamp max frame time (so the timing isn't messed up when stopping in the debugger)
  if (frame_time_ns > 33_333_333)
  {
    frame_time_ns = 33_333_333;
  }
  state.timing.tick_accum += frame_time_ns;
  while (state.timing.tick_accum > -TICK_TOLERANCE_NS)
  {
    state.timing.tick_accum -= TICK_DURATION_NS;
    state.timing.tick++;

    // call per-tick sound function (updates sound 'registers' with current sound effect values)
    // snd_tick();

    // check for game state change
    // if (now(state.Intro.started)) {
    //     state.gamestate = GameState.GAMESTATE_INTRO;
    // }
    // if (now(state.Game.started)) {
    //     state.gamestate = GameState.GAMESTATE_GAME;
    // }

    // call the top-level game state update function
    switch (state.gamestate)
    {
    case state.gamestate.GAMESTATE_INTRO:
      // intro_tick();
      break;
    case state.gamestate.GAMESTATE_GAME:
      // game_tick();
      break;
    default:
      break;
    }
  }
  // gfx_draw();
  // snd_frame(frame_time_ns);
}

static void input(const(sapp.Event)* ev)
{
  if (state.input.enabled)
  {
    if ((ev.type == sapp.EventType.Key_down) || (ev.type == sapp.EventType.Key_up))
    {
      bool btn_down = ev.type == sapp.EventType.Key_down;
      switch (ev.key_code)
      {
      case sapp.Keycode.Up:
      case sapp.Keycode.W:
        state.input.up = state.input.anykey = btn_down;
        break;
      case sapp.Keycode.Down:
      case sapp.Keycode.S:
        state.input.down = state.input.anykey = btn_down;
        break;
      case sapp.Keycode.Left:
      case sapp.Keycode.A:
        state.input.left = state.input.anykey = btn_down;
        break;
      case sapp.Keycode.Right:
      case sapp.Keycode.D:
        state.input.right = state.input.anykey = btn_down;
        break;
      case sapp.Keycode.Escape:
        state.input.esc = state.input.anykey = btn_down;
        break;
      default:
        state.input.anykey = btn_down;
        break;
      }
    }
  }
}

static State state;

void main() @nogc nothrow
{
  sapp.Desc runner = {
    window_title: "pacman.d",
    init_cb: &init,
    frame_cb: &frame,
    cleanup_cb: &cleanup,
    event_cb: &input,
    width: DISPLAY_TILES_X * TILE_WIDTH * 2,
    height: DISPLAY_TILES_Y * TILE_HEIGHT * 2,
    win32_console_attach: true,
    icon: {sokol_default: true},
    logger: {func: &log.func}
  };
  sapp.run(runner);
}
