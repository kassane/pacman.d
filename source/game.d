module game;

import data;
import rom;
import sound;
import core.stdc.string : memset;
import sapp = sokol.app;
import sg = sokol.gfx;
import sglue = sokol.glue;
import log = sokol.log;
import shd = shader.pacman;

extern (C):
nothrow @nogc:

// xorshift random number generator
uint xorshift32()
{
  uint x = state.game.xorshift;
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  return state.game.xorshift = x;
}

// get level spec for a game round
LevelSpec levelspec(int round)
{
  assert(round >= 0);
  if (round >= MAX_LEVELSPEC)
  {
    round = MAX_LEVELSPEC - 1;
  }
  return levelspec_table[round];
}

// set time trigger to the next game tick
void start(scope ref Trigger t)
{
  t.tick = state.timing.tick + 1;
}

// set time trigger to a future tick
void start_after(scope ref Trigger t, uint ticks)
{
  t.tick = state.timing.tick + ticks;
}

// check if a time trigger is triggered
bool now(scope ref Trigger t)
{
  return t.tick == state.timing.tick;
}

// set a debug marker
version (DbgMarkers)
{
  void dbg_marker(int index, Int2 tile_pos, ubyte tile_code, ubyte color_code)
  {
    assert((index >= 0) && (index < NUM_DEBUG_MARKERS));
    state.gfx.debug_marker[index].enabled = true;
    state.gfx.debug_marker[index].tile = tile_code;
    state.gfx.debug_marker[index].color = color_code;
    state.gfx.debug_marker[index].tile_pos = clamped_tile_pos(tile_pos);
  }
}

// initialize the playfield tiles
void game_init_playfield()
{
  vid_color_playfield(COLOR_DOT);

  // decode the playfield from an ASCII map into tiles codes
  immutable tiles =
    "0UUUUUUUUUUUU45UUUUUUUUUUUU1" ~
    "L............rl............R" ~
    "L.ebbf.ebbbf.rl.ebbbf.ebbf.R" ~
    "LPr  l.r   l.rl.r   l.r  lPR" ~
    "L.guuh.guuuh.gh.guuuh.guuh.R" ~
    "L..........................R" ~
    "L.ebbf.ef.ebbbbbbf.ef.ebbf.R" ~
    "L.guuh.rl.guuyxuuh.rl.guuh.R" ~
    "L......rl....rl....rl......R" ~
    "2BBBBf.rzbbf rl ebbwl.eBBBB3" ~
    "     L.rxuuh gh guuyl.R     " ~
    "     L.rl          rl.R     " ~
    "     L.rl mjs--tjn rl.R     " ~
    "UUUUUh.gh i      q gh.gUUUUU" ~
    "      .   i      q   .      " ~
    "BBBBBf.ef i      q ef.eBBBBB" ~
    "     L.rl okkkkkkp rl.R     " ~
    "     L.rl          rl.R     " ~
    "     L.rl ebbbbbbf rl.R     " ~
    "0UUUUh.gh guuyxuuh gh.gUUUU1" ~
    "L............rl............R" ~
    "L.ebbf.ebbbf.rl.ebbbf.ebbf.R" ~
    "L.guyl.guuuh.gh.guuuh.rxuh.R" ~
    "LP..rl.......  .......rl..PR" ~
    "6bf.rl.ef.ebbbbbbf.ef.rl.eb8" ~
    "7uh.gh.rl.guuyxuuh.rl.gh.gu9" ~
    "L......rl....rl....rl......R" ~
    "L.ebbbbwzbbf.rl.ebbwzbbbbf.R" ~
    "L.guuuuuuuuh.gh.guuuuuuuuh.R" ~
    "L..........................R" ~
    "2BBBBBBBBBBBBBBBBBBBBBBBBBB3";

  // ASCII to tile mapping
  ubyte[128] t = 0;
  //dfmt off
  for (int i = 0; i < 128; i++) { t[i]=TILE_DOT; }
  t[' ']=0x40; t['0']=0xD1; t['1']=0xD0; t['2']=0xD5; t['3']=0xD4; t['4']=0xFB;
  t['5']=0xFA; t['6']=0xD7; t['7']=0xD9; t['8']=0xD6; t['9']=0xD8; t['U']=0xDB;
  t['L']=0xD3; t['R']=0xD2; t['B']=0xDC; t['b']=0xDF; t['e']=0xE7; t['f']=0xE6;
  t['g']=0xEB; t['h']=0xEA; t['l']=0xE8; t['r']=0xE9; t['u']=0xE5; t['w']=0xF5;
  t['x']=0xF2; t['y']=0xF3; t['z']=0xF4; t['m']=0xED; t['n']=0xEC; t['o']=0xEF;
  t['p']=0xEE; t['j']=0xDD; t['i']=0xD2; t['k']=0xDB; t['q']=0xD3; t['s']=0xF1;
  t['t']=0xF0; t['-']=TILE_DOOR; t['P']=TILE_PILL;
  for (int y = 3, i = 0; y <= DISPLAY_TILES_Y - 2; y++)
  {
    for (int x = 0; x < DISPLAY_TILES_X; x++, i++)
    {
      state.gfx.video_ram[y][x] = t[tiles[i] & 127];
    }
  }
  // dfmt on
  // Ghost house gate colors
  vid_color(i2(13, 15), 0x18);
  vid_color(i2(14, 15), 0x18);
}

// disable all game loop timers
void game_disable_timers()
{
  disable(state.game.round_won);
  disable(state.game.game_over);
  disable(state.game.dot_eaten);
  disable(state.game.pill_eaten);
  disable(state.game.ghost_eaten);
  disable(state.game.pacman_eaten);
  disable(state.game.fruit_eaten);
  disable(state.game.force_leave_house);
  disable(state.game.fruit_active);
}

// one-time init at start of game state
void game_init()
{
  input_enable;
  game_disable_timers;
  state.game.round = DBG_START_ROUND;
  state.game.freeze = FreezeType.FREEZETYPE_PRELUDE;
  state.game.num_lives = NUM_LIVES;
  state.game.global_dot_counter_active = false;
  state.game.global_dot_counter = 0;
  state.game.num_dots_eaten = 0;
  state.game.score = 0;

  // draw the playfield and PLAYER ONE READY! message
  vid_clear(TILE_SPACE, COLOR_DOT);
  vid_color_text(i2(9, 0), COLOR_DEFAULT, "HIGH SCORE");
  game_init_playfield();
  vid_color_text(i2(9, 14), 0x5, "PLAYER ONE");
  vid_color_text(i2(11, 20), 0x9, "READY!");
}

// setup state at start of a game round
void game_round_init()
{
  spr_clear();

  // clear the "PLAYER ONE" text
  vid_color_text(i2(9, 14), 0x10, "          ");

  /* if a new round was started because Pacman has "won" (eaten all dots),
        redraw the playfield and reset the global dot counter
    */
  if (state.game.num_dots_eaten == NUM_DOTS)
  {
    state.game.round++;
    state.game.num_dots_eaten = 0;
    game_init_playfield();
    state.game.global_dot_counter_active = false;
  }
  else
  {
    /* if the previous round was lost, use the global dot counter
           to detect when ghosts should leave the ghost house instead
           of the per-ghost dot counter
        */
    if (state.game.num_lives != NUM_LIVES)
    {
      state.game.global_dot_counter_active = true;
      state.game.global_dot_counter = 0;
    }
    state.game.num_lives--;
  }
  assert(state.game.num_lives >= 0);

  state.game.active_fruit = Fruit.FRUIT_NONE;
  state.game.freeze = FreezeType.FREEZETYPE_READY;
  state.game.xorshift = 0x12345678; // random-number-generator seed
  state.game.num_ghosts_eaten = 0;
  game_disable_timers();

  vid_color_text(i2(11, 20), 0x9, "READY!");

  // the force-house timer forces ghosts out of the house if Pacman isn't
  // eating dots for a while
  start(state.game.force_leave_house);

  // Pacman starts running to the left
  Pacman pcm_start = {
    actor: {
      dir: Dir.DIR_LEFT,
      pos: {x: cast(short)(14 * 8), y: cast(short)(26 * 8 + 4)}
    },
  };
  state.game.pacman = pcm_start;
  Sprite pcm_spr = {enabled: true, color: COLOR_PACMAN};
  state.gfx.sprite[SpriteIndex.SPRITE_PACMAN] = pcm_spr;

  // Blinky starts outside the ghost house, looking to the left, and in scatter mode
  Ghost blinky_starter = {
    actor: {
      dir: Dir.DIR_LEFT,
      pos: ghost_starting_pos[GhostType.GHOSTTYPE_BLINKY],
    },
    type: GhostType.GHOSTTYPE_BLINKY,
    next_dir: Dir.DIR_LEFT,
    state: GhostState.GHOSTSTATE_SCATTER,
    frightened: disabled_timer,
    eaten: disabled_timer,
    dot_counter: 0,
    dot_limit: 0
  };
  state.game.ghost[GhostType.GHOSTTYPE_BLINKY] = blinky_starter;
  state.gfx.sprite[SpriteIndex.SPRITE_BLINKY].enabled = true;
  state.gfx.sprite[SpriteIndex.SPRITE_BLINKY].color = COLOR_BLINKY;

  // Pinky starts in the middle slot of the ghost house, moving down
  Ghost pinky_starter = {
    actor: {
      dir: Dir.DIR_DOWN,
      pos: ghost_starting_pos[GhostType.GHOSTTYPE_PINKY],
    },
    type: GhostType.GHOSTTYPE_PINKY,
    next_dir: Dir.DIR_DOWN,
    state: GhostState.GHOSTSTATE_HOUSE,
    frightened: disabled_timer,
    eaten: disabled_timer,
    dot_counter: 0,
    dot_limit: 0
  };
  state.game.ghost[GhostType.GHOSTTYPE_PINKY] = pinky_starter;
  Sprite pinky_sprite = {enabled: true, color: COLOR_PINKY};
  state.gfx.sprite[SpriteIndex.SPRITE_PINKY] = pinky_sprite;

  // Inky starts in the left slot of the ghost house moving up
  Ghost inky_starter = {
    actor: {dir: Dir.DIR_UP,
    pos: ghost_starting_pos[GhostType.GHOSTTYPE_INKY],},
    type: GhostType.GHOSTTYPE_INKY,
    next_dir: Dir.DIR_UP,
    state: GhostState.GHOSTSTATE_HOUSE,
    frightened: disabled_timer,
    eaten: disabled_timer,
    dot_counter: 0,
    dot_limit: 30
  };
  state.game.ghost[GhostType.GHOSTTYPE_INKY] = inky_starter;
  Sprite inky_sprite = {enabled: true, color: COLOR_INKY};
  state.gfx.sprite[SpriteIndex.SPRITE_INKY] = inky_sprite;

  // Clyde starts in the right slot of the ghost house, moving up
  Ghost clyde_starter = {
    actor: {
      dir: Dir.DIR_UP,
      pos: ghost_starting_pos[GhostType.GHOSTTYPE_CLYDE],
    },
    type: GhostType.GHOSTTYPE_CLYDE,
    next_dir: Dir.DIR_UP,
    state: GhostState.GHOSTSTATE_HOUSE,
    frightened: disabled_timer,
    eaten: disabled_timer,
    dot_counter: 0,
    dot_limit: 60
  };
  state.game.ghost[GhostType.GHOSTTYPE_CLYDE] = clyde_starter;
  Sprite clyde_sprite = {enabled: true, color: COLOR_INKY};
  state.gfx.sprite[SpriteIndex.SPRITE_CLYDE] = clyde_sprite;
}

// update dynamic background tiles
void game_update_tiles()
{
  // print score and hiscore
  vid_color_score(i2(6, 1), COLOR_DEFAULT, state.game.score);
  if (state.game.hiscore > 0)
  {
    vid_color_score(i2(16, 1), COLOR_DEFAULT, state.game.hiscore);
  }

  // update the energizer pill colors (blinking/non-blinking)
  const Int2[NUM_PILLS] pill_pos = [{1, 6}, {26, 6}, {1, 26}, {26, 26}];
  for (int i = 0; i < NUM_PILLS; i++)
  {
    if (state.game.freeze)
    {
      vid_color(pill_pos[i], COLOR_DOT);
    }
    else
    {
      vid_color(pill_pos[i], (state.timing.tick & 0x8) ? 0x10 : 0);
    }
  }

  // clear the fruit-eaten score after Pacman has eaten a bonus fruit
  if (after_once(state.game.fruit_eaten, 2 * 60))
  {
    vid_fruit_score(Fruit.FRUIT_NONE);
  }

  // remaining lives at bottom left screen
  for (int i = 0; i < NUM_LIVES; i++)
  {
    ubyte color = (i < state.game.num_lives) ? COLOR_PACMAN : 0;
    vid_draw_tile_quad(i2(cast(short)(2 + 2 * i), 34), color, TILE_LIFE);
  }

  // bonus fruit list in bottom-right corner
  {
    short x = 24;
    for (int i = (cast(int) state.game.round - NUM_STATUS_FRUITS + 1); i <= cast(int) state
      .game.round; i++)
    {
      if (i >= 0)
      {
        Fruit fruit = levelspec(i).bonus_fruit;
        ubyte tile_code = fruit_tiles_colors[fruit][0];
        ubyte color_code = fruit_tiles_colors[fruit][2];
        vid_draw_tile_quad(i2(x, 34), color_code, tile_code);
        x -= 2;
      }
    }
  }

  // if game round was won, render the entire playfield as blinking blue/white
  if (after(state.game.round_won, 1 * 60))
  {
    if (since(state.game.round_won) & 0x10)
    {
      vid_color_playfield(COLOR_DOT);
    }
    else
    {
      vid_color_playfield(COLOR_WHITE_BORDER);
    }
  }
}

// this function takes care of updating all sprite images during gameplay
void game_update_sprites()
{
  // update Pacman sprite
  {
    Sprite* spr = spr_pacman();
    if (spr.enabled)
    {
      const Actor* actor = &state.game.pacman.actor;
      spr.pos = actor_to_sprite_pos(actor.pos);
      if (state.game.freeze & FreezeType.FREEZETYPE_EAT_GHOST)
      {
        // hide Pacman shortly after he's eaten a ghost (via an invisible Sprite tile)
        spr.tile = SPRITETILE_INVISIBLE;
      }
      else if (state.game.freeze & (FreezeType.FREEZETYPE_PRELUDE | FreezeType.FREEZETYPE_READY))
      {
        // special case game frozen at start of round, show Pacman with 'closed mouth'
        spr.tile = SPRITETILE_PACMAN_CLOSED_MOUTH;
      }
      else if (state.game.freeze & FreezeType.FREEZETYPE_DEAD)
      {
        // play the Pacman-death-animation after a short pause
        if (after(state.game.pacman_eaten, PACMAN_EATEN_TICKS))
        {
          spr_anim_pacman_death(since(state.game.pacman_eaten) - PACMAN_EATEN_TICKS);
        }
      }
      else
      {
        // regular Pacman animation
        spr_anim_pacman(actor.dir, actor.anim_tick);
      }
    }
  }

  // update ghost sprites
  for (int i = 0; i < GhostType.NUM_GHOSTS; i++)
  {
    Sprite* sprite = spr_ghost(cast(GhostType) i);
    if (sprite.enabled)
    {
      Ghost* ghost = &state.game.ghost[i];
      sprite.pos = actor_to_sprite_pos(ghost.actor.pos);
      // if Pacman has just died, hide ghosts
      if (state.game.freeze & FreezeType.FREEZETYPE_DEAD)
      {
        if (after(state.game.pacman_eaten, PACMAN_EATEN_TICKS))
        {
          sprite.tile = SPRITETILE_INVISIBLE;
        }
      }
      // if Pacman has won the round, hide ghosts
    else if (state.game.freeze & FreezeType.FREEZETYPE_WON)
      {
        sprite.tile = SPRITETILE_INVISIBLE;
      }
      else
        switch (ghost.state)
      {
      case GhostState.GHOSTSTATE_EYES:
        if (before(ghost.eaten, GHOST_EATEN_FREEZE_TICKS))
        {
          // if the ghost was *just* eaten by Pacman, the ghost's sprite
          // is replaced with a score number for a short time
          // (200 for the first ghost, followed by 400, 800 and 1600)
          sprite.tile = cast(ubyte)(SPRITETILE_SCORE_200 + state.game.num_ghosts_eaten - 1);
          sprite.color = COLOR_GHOST_SCORE;
        }
        else
        {
          // afterwards, the ghost's eyes are shown, heading back to the ghost house
          spr_anim_ghost_eyes(cast(GhostType) i, ghost.next_dir);
        }
        break;
      case GhostState.GHOSTSTATE_ENTERHOUSE:
        // ...still show the ghost eyes while entering the ghost house
        spr_anim_ghost_eyes(cast(GhostType) i, ghost.actor.dir);
        break;
      case GhostState.GHOSTSTATE_FRIGHTENED:
        // when inside the ghost house, show the normal ghost images
        // (FIXME: ghost's inside the ghost house also show the
        // frightened appearance when Pacman has eaten an energizer pill)
        spr_anim_ghost_frightened(cast(GhostType) i, since(ghost.frightened));
        break;
      default:
        // show the regular ghost sprite image, the ghost's
        // 'next_dir' is used to visualize the direction the ghost
        // is heading to, this has the effect that ghosts already look
        // into the direction they will move into one tile ahead
        spr_anim_ghost(cast(GhostType) i, ghost.next_dir, ghost.actor.anim_tick);
        break;
      }
    }
  }

  // hide or display the currently active bonus fruit
  if (state.game.active_fruit == Fruit.FRUIT_NONE)
  {
    spr_fruit().enabled = false;
  }
  else
  {
    Sprite* spr = spr_fruit();
    spr.enabled = true;
    spr.pos = i2(13 * TILE_WIDTH, 19 * TILE_HEIGHT + TILE_HEIGHT / 2);
    spr.tile = fruit_tiles_colors[state.game.active_fruit][1];
    spr.color = fruit_tiles_colors[state.game.active_fruit][2];
  }
}

// return true if Pacman should move in this tick, when eating dots, Pacman
// is slightly slower than ghosts, otherwise slightly faster
bool game_pacman_should_move()
{
  if (now(state.game.dot_eaten))
  {
    // eating a dot causes Pacman to stop for 1 tick
    return false;
  }
  else if (since(state.game.pill_eaten) < 3)
  {
    // eating an energizer pill causes Pacman to stop for 3 ticks
    return false;
  }
  else
  {
    return 0 != (state.timing.tick % 8);
  }
}

// return number of pixels a ghost should move this tick, this can't be a simple
// move/don't move boolean return value, because ghosts in eye state move faster
// than one pixel per tick
int game_ghost_speed(const Ghost* ghost)
{
  assert(ghost);
  switch (ghost.state)
  {
  case GhostState.GHOSTSTATE_HOUSE:
  case GhostState.GHOSTSTATE_LEAVEHOUSE:
    // inside house at half speed (estimated)
    return state.timing.tick & 1;
  case GhostState.GHOSTSTATE_FRIGHTENED:
    // move at 50% speed when frightened
    return state.timing.tick & 1;
  case GhostState.GHOSTSTATE_EYES:
  case GhostState.GHOSTSTATE_ENTERHOUSE:
    // estimated 1.5x when in eye state, Pacman Dossier is silent on this
    return (state.timing.tick & 1) ? 1 : 2;
  default:
    if (is_tunnel(pixel_to_tile_pos(ghost.actor.pos)))
    {
      // move drastically slower when inside tunnel
      return ((state.timing.tick * 2) % 4) ? 1 : 0;
    }
    else
    {
      // otherwise move just a bit slower than Pacman
      return (state.timing.tick % 7) ? 1 : 0;
    }
  }
}

// return the current global scatter or chase phase
GhostState game_scatter_chase_phase()
{
  uint t = since(state.game.round_started);
  if (t < 7 * 60)
    return GhostState.GHOSTSTATE_SCATTER;
  else if (t < 27 * 60)
    return GhostState.GHOSTSTATE_CHASE;
  else if (t < 34 * 60)
    return GhostState.GHOSTSTATE_SCATTER;
  else if (t < 54 * 60)
    return GhostState.GHOSTSTATE_CHASE;
  else if (t < 59 * 60)
    return GhostState.GHOSTSTATE_SCATTER;
  else if (t < 79 * 60)
    return GhostState.GHOSTSTATE_CHASE;
  else if (t < 84 * 60)
    return GhostState.GHOSTSTATE_SCATTER;
  else
    return GhostState.GHOSTSTATE_CHASE;
}

// this function takes care of switching ghosts into a new state, this is one
// of two important functions of the ghost AI (the other being the target selection
// function below)
void game_update_ghost_state(Ghost* ghost)
{
  assert(ghost);
  GhostState new_state = ghost.state;
  switch (ghost.state)
  {
  case GhostState.GHOSTSTATE_EYES:
    // When in eye state (heading back to the ghost house), check if the
    // target position in front of the ghost house has been reached, then
    // switch into ENTERHOUSE state. Since ghosts in eye state move faster
    // than one pixel per tick, do a fuzzy comparison with the target pos
    if (nearequal_i2(ghost.actor.pos, i2(ANTEPORTAS_X, ANTEPORTAS_Y), 1))
    {
      new_state = GhostState.GHOSTSTATE_ENTERHOUSE;
    }
    break;
  case GhostState.GHOSTSTATE_ENTERHOUSE:
    // Ghosts that enter the ghost house during the gameplay loop immediately
    // leave the house again after reaching their target position inside the house.
    if (nearequal_i2(ghost.actor.pos, ghost_house_target_pos[ghost.type], 1))
    {
      new_state = GhostState.GHOSTSTATE_LEAVEHOUSE;
    }
    break;
  case GhostState.GHOSTSTATE_HOUSE:
    // Ghosts only remain in the "house state" after a new game round
    // has been started. The conditions when ghosts leave the house
    // are a bit complicated, best to check the Pacman Dossier for the details.
    if (after_once(state.game.force_leave_house, 4 * 60))
    {
      // if Pacman hasn't eaten dots for 4 seconds, the next ghost
      // is forced out of the house
      // FIXME: time is reduced to 3 seconds after round 5
      new_state = GhostState.GHOSTSTATE_LEAVEHOUSE;
      start(state.game.force_leave_house);
    }
    else if (state.game.global_dot_counter_active)
    {
      // if Pacman has lost a life this round, the global dot counter is used
      if ((ghost.type == GhostType.GHOSTTYPE_PINKY) && (state.game.global_dot_counter == 7))
      {
        new_state = GhostState.GHOSTSTATE_LEAVEHOUSE;
      }
      else if ((ghost.type == GhostType.GHOSTTYPE_INKY) && (state.game.global_dot_counter == 17))
      {
        new_state = GhostState.GHOSTSTATE_LEAVEHOUSE;
      }
      else if ((ghost.type == GhostType.GHOSTTYPE_CLYDE) && (state.game.global_dot_counter == 32))
      {
        new_state = GhostState.GHOSTSTATE_LEAVEHOUSE;
        // NOTE that global dot counter is deactivated if (and only if) Clyde
        // is in the house and the dot counter reaches 32
        state.game.global_dot_counter_active = false;
      }
    }
    else if (ghost.dot_counter == ghost.dot_limit)
    {
      // in the normal case, check the ghost's personal dot counter
      new_state = GhostState.GHOSTSTATE_LEAVEHOUSE;
    }
    break;
  case GhostState.GHOSTSTATE_LEAVEHOUSE:
    // ghosts immediately switch to scatter mode after leaving the ghost house
    if (ghost.actor.pos.y == ANTEPORTAS_Y)
    {
      new_state = GhostState.GHOSTSTATE_SCATTER;
    }
    break;
  default:
    // switch between frightened, scatter and chase mode
    if (before(ghost.frightened, levelspec(state.game.round).fright_ticks))
    {
      new_state = GhostState.GHOSTSTATE_FRIGHTENED;
    }
    else
    {
      new_state = game_scatter_chase_phase();
    }
  }
  // handle state transitions
  if (new_state != ghost.state)
  {
    switch (ghost.state)
    {
    case GhostState.GHOSTSTATE_LEAVEHOUSE:
      // after leaving the ghost house, head to the left
      ghost.next_dir = ghost.actor.dir = Dir.DIR_LEFT;
      break;
    case GhostState.GHOSTSTATE_ENTERHOUSE:
      // a ghost that was eaten is immune to frighten until Pacman eats enother pill
      disable(ghost.frightened);
      break;
    case GhostState.GHOSTSTATE_FRIGHTENED:
      // don't reverse direction when leaving frightened state
      break;
    case GhostState.GHOSTSTATE_SCATTER:
    case GhostState.GHOSTSTATE_CHASE:
      // any transition from scatter and chase mode causes a reversal of direction
      ghost.next_dir = reverse_dir(ghost.actor.dir);
      break;
    default:
      break;
    }
    ghost.state = new_state;
  }
}

// update the ghost's target position, this is the other important function
// of the ghost's AI
void game_update_ghost_target(Ghost* ghost)
{
  assert(ghost);
  Int2 pos = ghost.target_pos;
  switch (ghost.state)
  {
  case GhostState.GHOSTSTATE_SCATTER:
    // when in scatter mode, each ghost heads to its own scatter
    // target position in the playfield corners
    assert((ghost.type >= 0) && (ghost.type < GhostType.NUM_GHOSTS));
    pos = ghost_scatter_targets[ghost.type];
    break;
  case GhostState.GHOSTSTATE_CHASE:
    // when in chase mode, each ghost has its own particular
    // chase behaviour (see the Pacman Dossier for details)
    {
      const Actor* pm = &state.game.pacman.actor;
      const Int2 pm_pos = pixel_to_tile_pos(pm.pos);
      const Int2 pm_dir = dir2Vec(pm.dir);
      switch (ghost.type)
      {
      case GhostType.GHOSTTYPE_BLINKY:
        // Blinky directly chases Pacman
        pos = pm_pos;
        break;
      case GhostType.GHOSTTYPE_PINKY:
        // Pinky target is 4 tiles ahead of Pacman
        // FIXME: does not reproduce 'diagonal overflow'
        pos = add_i2(pm_pos, mul_i2(pm_dir, 4));
        break;
      case GhostType.GHOSTTYPE_INKY:
        // Inky targets an extrapolated pos along a line two tiles
        // ahead of Pacman through Blinky
        {
          const Int2 blinky_pos = pixel_to_tile_pos(
            state.game.ghost[GhostType.GHOSTTYPE_BLINKY].actor.pos);
          const Int2 p = add_i2(pm_pos, mul_i2(pm_dir, 2));
          const Int2 d = sub_i2(p, blinky_pos);
          pos = add_i2(blinky_pos, mul_i2(d, 2));
        }
        break;
      case GhostType.GHOSTTYPE_CLYDE:
        // if Clyde is far away from Pacman, he chases Pacman,
        // but if close he moves towards the scatter target
        if (squared_distance_i2(pixel_to_tile_pos(ghost.actor.pos), pm_pos) > 64)
        {
          pos = pm_pos;
        }
        else
        {
          pos = ghost_scatter_targets[GhostType.GHOSTTYPE_CLYDE];
        }
        break;
      default:
        break;
      }
    }
    break;
  case GhostState.GHOSTSTATE_FRIGHTENED:
    // in frightened state just select a random target position
    // this has the effect that ghosts in frightened state
    // move in a random direction at each intersection
    pos = i2(xorshift32() % DISPLAY_TILES_X, xorshift32() % DISPLAY_TILES_Y);
    break;
  case GhostState.GHOSTSTATE_EYES:
    // move towards the ghost house door
    pos = i2(13, 14);
    break;
  default:
    break;
  }
  ghost.target_pos = pos;
}

// compute the next ghost direction, return true if resulting movement
// should always happen regardless of current ghost position or blocking
// tiles (this special case is used for movement inside the ghost house)
bool game_update_ghost_dir(Ghost* ghost)
{
  assert(ghost);
  // inside ghost-house, just move up and down
  if (ghost.state == GhostState.GHOSTSTATE_HOUSE)
  {
    if (ghost.actor.pos.y <= 17 * TILE_HEIGHT)
    {
      ghost.next_dir = Dir.DIR_DOWN;
    }
    else if (ghost.actor.pos.y >= 18 * TILE_HEIGHT)
    {
      ghost.next_dir = Dir.DIR_UP;
    }
    ghost.actor.dir = ghost.next_dir;
    // force movement
    return true;
  }
  // navigate the ghost out of the ghost house
  else if (ghost.state == GhostState.GHOSTSTATE_LEAVEHOUSE)
  {
    const Int2 pos = ghost.actor.pos;
    if (pos.x == ANTEPORTAS_X)
    {
      if (pos.y > ANTEPORTAS_Y)
      {
        ghost.next_dir = Dir.DIR_UP;
      }
    }
    else
    {
      const short mid_y = 17 * TILE_HEIGHT + TILE_HEIGHT / 2;
      if (pos.y > mid_y)
      {
        ghost.next_dir = Dir.DIR_UP;
      }
      else if (pos.y < mid_y)
      {
        ghost.next_dir = Dir.DIR_DOWN;
      }
      else
      {
        ghost.next_dir = (pos.x > ANTEPORTAS_X) ? Dir.DIR_LEFT : Dir.DIR_RIGHT;
      }
    }
    ghost.actor.dir = ghost.next_dir;
    return true;
  }
  // navigate towards the ghost house target pos
  else if (ghost.state == GhostState.GHOSTSTATE_ENTERHOUSE)
  {
    const Int2 pos = ghost.actor.pos;
    const Int2 tile_pos = pixel_to_tile_pos(pos);
    const Int2 tgt_pos = ghost_house_target_pos[ghost.type];
    if (tile_pos.y == 14)
    {
      if (pos.x != ANTEPORTAS_X)
      {
        ghost.next_dir = (pos.x < ANTEPORTAS_X) ? Dir.DIR_RIGHT : Dir.DIR_LEFT;
      }
      else
      {
        ghost.next_dir = Dir.DIR_DOWN;
      }
    }
    else if (pos.y == tgt_pos.y)
    {
      ghost.next_dir = (pos.x < tgt_pos.x) ? Dir.DIR_RIGHT : Dir.DIR_LEFT;
    }
    ghost.actor.dir = ghost.next_dir;
    return true;
  }
  // scatter/chase/frightened: just head towards the current target point
  else
  {
    // only compute new direction when currently at midpoint of tile
    const Int2 dist_to_mid = dist_to_tile_mid(ghost.actor.pos);
    if ((dist_to_mid.x == 0) && (dist_to_mid.y == 0))
    {
      // new direction is the previously computed next-direction
      ghost.actor.dir = ghost.next_dir;

      // compute new next-direction
      const Int2 dir_vec = dir2Vec(ghost.actor.dir);
      const Int2 lookahead_pos = add_i2(pixel_to_tile_pos(ghost.actor.pos), dir_vec);

      // try each direction and take the one that moves closest to the target
      const Dir[Dir.NUM_DIRS] dirs = [
        Dir.DIR_UP, Dir.DIR_LEFT, Dir.DIR_DOWN, Dir.DIR_RIGHT
      ];
      int min_dist = 100000;
      int dist = 0;
      for (int i = 0; i < Dir.NUM_DIRS; i++)
      {
        const Dir dir = dirs[i];
        // if ghost is in one of the two 'red zones', forbid upward movement
        // (see Pacman Dossier "Areas To Exploit")
        if (is_redzone(lookahead_pos) && (dir == Dir.DIR_UP) && (
            ghost.state != GhostState.GHOSTSTATE_EYES))
        {
          continue;
        }
        const Dir revdir = reverse_dir(dir);
        const Int2 test_pos = clamped_tile_pos(add_i2(lookahead_pos, dir2Vec(dir)));
        if ((revdir != ghost.actor.dir) && !is_blocking_tile(test_pos))
        {
          if ((dist = squared_distance_i2(test_pos, ghost.target_pos)) < min_dist)
          {
            min_dist = dist;
            ghost.next_dir = dir;
          }
        }
      }
    }
    return false;
  }
}

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
void game_update_ghosthouse_dot_counters()
{
  // if the new round was started because Pacman lost a life, use the global
  // dot counter (this mode will be deactivated again after all ghosts left the
  // house)
  if (state.game.global_dot_counter_active)
  {
    state.game.global_dot_counter++;
  }
  else
  {
    // otherwise each ghost has his own personal dot counter to decide
    // when to leave the ghost house
    for (int i = 0; i < GhostType.NUM_GHOSTS; i++)
    {
      if (state.game.ghost[i].dot_counter < state.game.ghost[i].dot_limit)
      {
        state.game.ghost[i].dot_counter++;
        break;
      }
    }
  }
}

// called when a dot or pill has been eaten, checks if a round has been won
// (all dots and pills eaten), whether to show the bonus fruit, and finally
// plays the dot-eaten sound effect
void game_update_dots_eaten()
{
  state.game.num_dots_eaten++;
  if (state.game.num_dots_eaten == NUM_DOTS)
  {
    // all dots eaten, round won
    start(state.game.round_won);
    snd_clear();
  }
  else if ((state.game.num_dots_eaten == 70) || (state.game.num_dots_eaten == 170))
  {
    // at 70 and 170 dots, show the bonus fruit
    start(state.game.fruit_active);
  }

  // play alternating crunch sound effect when a dot has been eaten
  if (state.game.num_dots_eaten & 1)
  {
    snd_start(2, &snd_eatdot1);
  }
  else
  {
    snd_start(2, &snd_eatdot2);
  }
}

// the central Pacman and ghost behaviour function, called once per game tick
void game_update_actors()
{
  // Pacman "AI"
  if (game_pacman_should_move())
  {
    // move Pacman with cornering allowed
    Actor* actor = &state.game.pacman.actor;
    const Dir wanted_dir = input_dir(actor.dir);
    const bool allow_cornering = true;
    // look ahead to check if the wanted direction is blocked
    if (can_move(actor.pos, wanted_dir, allow_cornering))
    {
      actor.dir = wanted_dir;
    }
    // move into the selected direction
    if (can_move(actor.pos, actor.dir, allow_cornering))
    {
      actor.pos = move(actor.pos, actor.dir, allow_cornering);
      actor.anim_tick++;
    }
    // eat dot or energizer pill?
    const Int2 tile_pos = pixel_to_tile_pos(actor.pos);
    if (is_dot(tile_pos))
    {
      vid_tile(tile_pos, TILE_SPACE);
      state.game.score += 1;
      start(state.game.dot_eaten);
      start(state.game.force_leave_house);
      game_update_dots_eaten();
      game_update_ghosthouse_dot_counters();
    }
    if (is_pill(tile_pos))
    {
      vid_tile(tile_pos, TILE_SPACE);
      state.game.score += 5;
      game_update_dots_eaten();
      start(state.game.pill_eaten);
      state.game.num_ghosts_eaten = 0;
      for (int i = 0; i < GhostType.NUM_GHOSTS; i++)
      {
        start(state.game.ghost[i].frightened);
      }
      snd_start(1, &snd_frightened);
    }
    // check if Pacman eats the bonus fruit
    if (state.game.active_fruit != Fruit.FRUIT_NONE)
    {
      const Int2 test_pos = pixel_to_tile_pos(add_i2(actor.pos, i2(TILE_WIDTH / 2, 0)));
      if (equal_i2(test_pos, i2(14, 20)))
      {
        start(state.game.fruit_eaten);
        uint score = levelspec(state.game.round).bonus_score;
        state.game.score += score;
        vid_fruit_score(state.game.active_fruit);
        state.game.active_fruit = Fruit.FRUIT_NONE;
        snd_start(2, &snd_eatfruit);
      }
    }
    // check if Pacman collides with any ghost
    for (int i = 0; i < GhostType.NUM_GHOSTS; i++)
    {
      Ghost* ghost = &state.game.ghost[i];
      const Int2 ghost_tile_pos = pixel_to_tile_pos(ghost.actor.pos);
      if (equal_i2(tile_pos, ghost_tile_pos))
      {
        if (ghost.state == GhostState.GHOSTSTATE_FRIGHTENED)
        {
          // Pacman eats a frightened ghost
          ghost.state = GhostState.GHOSTSTATE_EYES;
          start(ghost.eaten);
          start(state.game.ghost_eaten);
          state.game.num_ghosts_eaten++;
          // increase score by 20, 40, 80, 160
          state.game.score += 10 * (1 << state.game.num_ghosts_eaten);
          state.game.freeze |= FreezeType.FREEZETYPE_EAT_GHOST;
          snd_start(2, &snd_eatghost);
        }
        else if ((ghost.state == GhostState.GHOSTSTATE_CHASE) || (
            ghost.state == GhostState.GHOSTSTATE_SCATTER))
        {
          // otherwise, ghost eats Pacman, Pacman loses a life
          version (DbgGodMode)
          {
            snd_clear();
            start(state.game.pacman_eaten);
            state.game.freeze |= FreezeType.FREEZETYPE_DEAD;
            // if Pacman has any lives left start a new round, otherwise start the game-over sequence
            if (state.game.num_lives > 0)
            {
              start_after(state.game.ready_started, PACMAN_EATEN_TICKS + PACMAN_DEATH_TICKS);
            }
            else
            {
              start_after(state.game.game_over, PACMAN_EATEN_TICKS + PACMAN_DEATH_TICKS);
            }
          }
        }
      }
    }
  }

  // Ghost "AIs"
  for (int ghost_index = 0; ghost_index < GhostType.NUM_GHOSTS; ghost_index++)
  {
    Ghost* ghost = &state.game.ghost[ghost_index];
    // handle ghost-state transitions
    game_update_ghost_state(ghost);
    // update the ghost's target position
    game_update_ghost_target(ghost);
    // finally, move the ghost towards the current target position
    const int num_move_ticks = game_ghost_speed(ghost);
    for (int i = 0; i < num_move_ticks; i++)
    {
      bool force_move = game_update_ghost_dir(ghost);
      Actor* actor = &ghost.actor;
      const bool allow_cornering = false;
      if (force_move || can_move(actor.pos, actor.dir, allow_cornering))
      {
        actor.pos = move(actor.pos, actor.dir, allow_cornering);
        actor.anim_tick++;
      }
    }
  }
}

// the central game tick function, called at 60 Hz
void game_tick()
{
  // debug: skip prelude
  version (DbgSkipPrelude)
  {
    const int prelude_ticks_per_sec = 1;
  }
  else
  {
    const int prelude_ticks_per_sec = 60;
  }

  // initialize game state once
  if (now(state.game.started))
  {
    start(state.gfx.fadein);
    start_after(state.game.ready_started, 2 * prelude_ticks_per_sec);
    snd_start(0, &snd_prelude);
    game_init();
  }
  // initialize new round (each time Pacman looses a life), make actors visible, remove "PLAYER ONE", start a new life
  if (now(state.game.ready_started))
  {
    game_round_init();
    // after 2 seconds start the interactive game loop
    start_after(state.game.round_started, 2 * 60 + 10);
  }
  if (now(state.game.round_started))
  {
    state.game.freeze &= ~FreezeType.FREEZETYPE_READY;
    // clear the 'READY!' message
    vid_color_text(i2(11, 20), 0x10, "      ");
    snd_start(1, &snd_weeooh);
  }

  // activate/deactivate bonus fruit
  if (now(state.game.fruit_active))
  {
    state.game.active_fruit = levelspec(state.game.round).bonus_fruit;
  }
  else if (after_once(state.game.fruit_active, FRUITACTIVE_TICKS))
  {
    state.game.active_fruit = Fruit.FRUIT_NONE;
  }

  // stop frightened sound and start weeooh sound
  if (after_once(state.game.pill_eaten, levelspec(state.game.round).fright_ticks))
  {
    snd_start(1, &snd_weeooh);
  }

  // if game is frozen because Pacman ate a ghost, unfreeze after a while
  if (state.game.freeze & FreezeType.FREEZETYPE_EAT_GHOST)
  {
    if (after_once(state.game.ghost_eaten, GHOST_EATEN_FREEZE_TICKS))
    {
      state.game.freeze &= ~FreezeType.FREEZETYPE_EAT_GHOST;
    }
  }

  // play pacman-death sound
  if (after_once(state.game.pacman_eaten, PACMAN_EATEN_TICKS))
  {
    snd_start(2, &snd_dead);
  }

  // the actually important part: update Pacman and ghosts, update dynamic
  // background tiles, and update the sprite images
  if (!state.game.freeze)
  {
    game_update_actors();
  }
  game_update_tiles();
  game_update_sprites();

  // update hiscore
  if (state.game.score > state.game.hiscore)
  {
    state.game.hiscore = state.game.score;
  }

  // check for end-round condition
  if (now(state.game.round_won))
  {
    state.game.freeze |= FreezeType.FREEZETYPE_WON;
    start_after(state.game.ready_started, ROUNDWON_TICKS);
  }
  if (now(state.game.game_over))
  {
    // display game over string
    vid_color_text(i2(9, 20), 0x01, "GAME  OVER");
    input_disable();
    start_after(state.gfx.fadeout, GAMEOVER_TICKS);
    start_after(state.intro.started, GAMEOVER_TICKS + FADE_TICKS);
  }

  version (DbgEscape)
  {
    if (state.input.esc)
    {
      input_disable();
      start(state.gfx.fadeout);
      start_after(state.intro.started, FADE_TICKS);
    }
  }

  version (DbgMarkers)
  {
    // visualize current ghost targets
    for (int i = 0; i < GhostType.NUM_GHOSTS; i++)
    {
      const Ghost* ghost = &state.game.ghost[i];
      ubyte tile = 'X';
      switch (ghost.state)
      {
      case GhostState.GHOSTSTATE_NONE:
        tile = 'N';
        break;
      case GhostState.GHOSTSTATE_CHASE:
        tile = 'C';
        break;
      case GhostState.GHOSTSTATE_SCATTER:
        tile = 'S';
        break;
      case GhostState.GHOSTSTATE_FRIGHTENED:
        tile = 'F';
        break;
      case GhostState.GHOSTSTATE_EYES:
        tile = 'E';
        break;
      case GhostState.GHOSTSTATE_HOUSE:
        tile = 'H';
        break;
      case GhostState.GHOSTSTATE_LEAVEHOUSE:
        tile = 'L';
        break;
      case GhostState.GHOSTSTATE_ENTERHOUSE:
        tile = 'E';
        break;
      default:
        break;
      }
      dbg_marker(cast(GhostType) i, state.game.ghost[i].target_pos, tile, cast(ubyte)(
          COLOR_BLINKY + 2 * i));
    }
  }
}

/*== INTRO GAMESTATE CODE ====================================================*/

void intro_tick()
{
  // on intro-state enter, enable input and draw any initial text
  if (now(state.intro.started))
  {
    snd_clear();
    spr_clear();
    start(state.gfx.fadein);
    input_enable();
    vid_clear(TILE_SPACE, COLOR_DEFAULT);
    vid_text(i2(3, 0), "1UP   HIGH SCORE   2UP");
    vid_color_score(i2(6, 1), COLOR_DEFAULT, 0);
    if (state.game.hiscore > 0)
    {
      vid_color_score(i2(16, 1), COLOR_DEFAULT, state.game.hiscore);
    }
    vid_text(i2(7, 5), "CHARACTER / NICKNAME");
    vid_text(i2(3, 35), "CREDIT  0");
  }

  // draw the animated 'ghost image.. name.. nickname' lines
  uint delay = 30;
  const(char)*[4] names = ["-SHADOW", "-SPEEDY", "-BASHFUL", "-POKEY"];
  const(char)*[4] nicknames = ["BLINKY", "PINKY", "INKY", "CLYDE"];
  for (int i = 0; i < 4; i++)
  {
    const ubyte color = cast(ubyte)(2 * i + 1);
    const ubyte y = cast(ubyte)(3 * i + 6);
    // 2*3 ghost image created from tiles (no sprite!)
    delay += 30;
    if (after_once(state.intro.started, delay))
    {
      vid_color_tile(i2(cast(short) 4, cast(short)(y + 0)), color, TILE_GHOST + 0);
      vid_color_tile(i2(cast(short) 5, cast(short)(y + 0)), color, TILE_GHOST + 1);
      vid_color_tile(i2(cast(short) 4, cast(short)(y + 1)), color, TILE_GHOST + 2);
      vid_color_tile(i2(cast(short) 5, cast(short)(y + 1)), color, TILE_GHOST + 3);
      vid_color_tile(i2(cast(short) 4, cast(short)(y + 2)), color, TILE_GHOST + 4);
      vid_color_tile(i2(cast(short) 5, cast(short)(y + 2)), color, TILE_GHOST + 5);
    }
    // after 1 second, the name of the ghost
    delay += 60;
    if (after_once(state.intro.started, delay))
    {
      vid_color_text(i2(cast(short) 7, cast(short)(y + 1)), color, names[i]);
    }
    // after 0.5 seconds, the nickname of the ghost
    delay += 30;
    if (after_once(state.intro.started, delay))
    {
      vid_color_text(i2(cast(short) 17, cast(short)(y + 1)), color, nicknames[i]);
    }
  }

  // . 10 PTS
  // O 50 PTS
  delay += 60;
  if (after_once(state.intro.started, delay))
  {
    vid_color_tile(i2(10, 24), COLOR_DOT, TILE_DOT);
    vid_text(i2(12, 24), "10 \x5D\x5E\x5F");
    vid_color_tile(i2(10, 26), COLOR_DOT, TILE_PILL);
    vid_text(i2(12, 26), "50 \x5D\x5E\x5F");
  }

  // blinking "press any key" text
  delay += 60;
  if (after(state.intro.started, delay))
  {
    if (since(state.intro.started) & 0x20)
    {
      vid_color_text(i2(3, 31), 3, "                       ");
    }
    else
    {
      vid_color_text(i2(3, 31), 3, "PRESS ANY KEY TO START!");
    }
  }

  // FIXME: animated chase sequence

  // if a key is pressed, advance to game state
  if (state.input.anykey)
  {
    input_disable();
    start(state.gfx.fadeout);
    start_after(state.game.started, FADE_TICKS);
  }
}

/*== GFX SUBSYSTEM ===========================================================*/

/* create all sokol-gfx resources */
void gfx_create_resources()
{
  // pass action for clearing the background to black
  sg.PassAction pass_action = {
    colors: [
      {
        load_action: sg.LoadAction.Clear, clear_value: {
          r: 0.0f, g: 0.0f, b: 0.0f, a: 1.0f
        }
      }
    ]
  };
  state.gfx.pass_action = pass_action;

  // create a dynamic vertex buffer for the tile and sprite quads
  sg.BufferDesc vbuf = {
    type: sg.BufferType.Vertexbuffer,
    usage: sg.Usage.Stream,
    size: state.gfx.vertices.sizeof,
  };
  state.gfx.offscreen.vbuf = sg.makeBuffer(vbuf);

  // create a simple quad vertex buffer for rendering the offscreen render target to the display
  float[8] quad_verts = [0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f];
  sg.BufferDesc quad_vbuf = {
    data: {ptr: quad_verts.ptr, size: quad_verts.sizeof}
  };
  state.gfx.display.quad_vbuf = sg.makeBuffer(quad_vbuf);

  // create pipeline and shader object for rendering into offscreen render target
  // dfmt off
  sg.PipelineDesc pip_desc = {
    shader: sg.makeShader(shd.offscreenShaderDesc(sg.queryBackend)),
    layout: {
        attrs: [
          shd.ATTR_OFFSCREEN_IN_POS: {format: sg.VertexFormat.Float2},
          shd.ATTR_OFFSCREEN_IN_UV: {format: sg.VertexFormat.Float2},
          shd.ATTR_OFFSCREEN_IN_DATA: {format: sg.VertexFormat.Ubyte4n}
        ],
      },
    depth: {pixel_format: sg.PixelFormat.None},
    colors:
    [
      {
        pixel_format: sg.PixelFormat.Rgba8,
        blend:
        {
          enabled: true,
          src_factor_rgb: sg.BlendFactor.Src_alpha,
          dst_factor_rgb: sg.BlendFactor.One_minus_blend_alpha,
        }
      }
    ]
  };
  // dfmt on
  state.gfx.offscreen.pip = sg.makePipeline(pip_desc);

  sg.PipelineDesc display_pip = {
    shader: sg.makeShader(shd.displayShaderDesc(sg.queryBackend)),
    layout: {attrs: [shd.ATTR_DISPLAY_POS: {format: sg.VertexFormat.Float2}]},
    primitive_type: sg.PrimitiveType.Triangle_strip
  };
  state.gfx.display.pip = sg.makePipeline(display_pip);

  // create a render target image with a fixed upscale ratio
  sg.ImageDesc offscreen_render_target = {
    render_target: true,
    width: DISPLAY_PIXELS_X * 2,
    height: DISPLAY_PIXELS_Y * 2,
    pixel_format: sg.PixelFormat.Rgba8,
  };
  state.gfx.offscreen.render_target = sg.makeImage(offscreen_render_target);

  // create an sampler to render the offscreen render target with linear upscale filtering
  sg.SamplerDesc display_sampler = {
    min_filter: sg.Filter.Linear,
    mag_filter: sg.Filter.Linear,
    wrap_u: sg.Wrap.Clamp_to_edge,
    wrap_v: sg.Wrap.Clamp_to_edge,
  };

  // pass object for rendering into the offscreen render target
  sg.AttachmentsDesc offscreen_attachments = {
    colors: [{image: state.gfx.offscreen.render_target}]
  };
  state.gfx.offscreen.attachments = sg.makeAttachments(offscreen_attachments);

  // create the 'tile-ROM-texture'
  sg.ImageDesc tile_img_desc = {
    width: TILE_TEXTURE_WIDTH,
    height: TILE_TEXTURE_HEIGHT,
    pixel_format: sg.PixelFormat.R8,
    data: {
      subimage: [
        [{ptr: state.gfx.tile_pixels.ptr, size: state.gfx.tile_pixels.sizeof}]
      ]
    }
  };
  state.gfx.offscreen.tile_img = sg.makeImage(tile_img_desc);

  // create the palette texture
  sg.ImageDesc palette_img = {
    width: 256,
    height: 1,
    pixel_format: sg.PixelFormat.Rgba8,
    data: {
      subimage: [
        [{state.gfx.color_palette.ptr, size: state.gfx.color_palette.sizeof}]
      ]
    }
  };
  state.gfx.offscreen.palette_img = sg.makeImage(palette_img);

  // create a sampler with nearest filtering for the offscreen pass
  sg.SamplerDesc offscreen_sampler = {
    min_filter: sg.Filter.Nearest,
    mag_filter: sg.Filter.Nearest,
    wrap_u: sg.Wrap.Clamp_to_edge,
    wrap_v: sg.Wrap.Clamp_to_edge,
  };
  state.gfx.offscreen.sampler = sg.makeSampler(offscreen_sampler);
  state.gfx.display.sampler = sg.makeSampler(display_sampler);

  state.gfx.offscreen.bind.vertex_buffers[0] = state.gfx.offscreen.vbuf;
  state.gfx.offscreen.bind.images[shd.IMG_TILE_TEX] = state.gfx.offscreen.tile_img;
  state.gfx.offscreen.bind.images[shd.IMG_PAL_TEX] = state.gfx.offscreen.palette_img;
  state.gfx.offscreen.bind.samplers[shd.SMP_SMP] = state.gfx.offscreen.sampler;
  state.gfx.display.bind.vertex_buffers[0] = state.gfx.display.quad_vbuf;
  state.gfx.display.bind.images[shd.IMG_TEX] = state.gfx.offscreen.render_target;
  state.gfx.display.bind.samplers[shd.SMP_SMP] = state.gfx.display.sampler;
}

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
pragma(inline, true)
void gfx_decode_tile_8x4(
  uint tex_x,
  uint tex_y,
  const(char)* tile_base,
  uint tile_stride,
  uint tile_offset,
  ubyte tile_code)
{
  for (uint tx = 0; tx < TILE_WIDTH; tx++)
  {
    uint ti = tile_code * tile_stride + tile_offset + (7 - tx);
    for (uint ty = 0; ty < (TILE_HEIGHT / 2); ty++)
    {
      ubyte p_hi = (tile_base[ti] >> (7 - ty)) & 1;
      ubyte p_lo = (tile_base[ti] >> (3 - ty)) & 1;
      ubyte p = cast(ubyte)(p_hi << 1) | p_lo;
      state.gfx.tile_pixels[tex_y + ty][tex_x + tx] = p;
    }
  }
}

// decode an 8x8 tile into the tile texture's upper half
pragma(inline, true)
void gfx_decode_tile(ubyte tile_code)
{
  uint x = tile_code * TILE_WIDTH;
  uint y0 = 0;
  uint y1 = y0 + (TILE_HEIGHT / 2);
  gfx_decode_tile_8x4(x, y0, rom_tiles.ptr, 16, 8, tile_code);
  gfx_decode_tile_8x4(x, y1, rom_tiles.ptr, 16, 0, tile_code);
}

// decode a 16x16 sprite into the tile texture's lower half
pragma(inline, true)
void gfx_decode_sprite(ubyte sprite_code)
{
  uint x0 = sprite_code * SPRITE_WIDTH;
  uint x1 = x0 + TILE_WIDTH;
  uint y0 = TILE_HEIGHT;
  uint y1 = y0 + (TILE_HEIGHT / 2);
  uint y2 = y1 + (TILE_HEIGHT / 2);
  uint y3 = y2 + (TILE_HEIGHT / 2);
  gfx_decode_tile_8x4(x0, y0, rom_sprites.ptr, 64, 40, sprite_code);
  gfx_decode_tile_8x4(x1, y0, rom_sprites.ptr, 64, 8, sprite_code);
  gfx_decode_tile_8x4(x0, y1, rom_sprites.ptr, 64, 48, sprite_code);
  gfx_decode_tile_8x4(x1, y1, rom_sprites.ptr, 64, 16, sprite_code);
  gfx_decode_tile_8x4(x0, y2, rom_sprites.ptr, 64, 56, sprite_code);
  gfx_decode_tile_8x4(x1, y2, rom_sprites.ptr, 64, 24, sprite_code);
  gfx_decode_tile_8x4(x0, y3, rom_sprites.ptr, 64, 32, sprite_code);
  gfx_decode_tile_8x4(x1, y3, rom_sprites.ptr, 64, 0, sprite_code);
}

// decode the Pacman tile- and sprite-ROM-dumps into a 8bpp texture
void gfx_decode_tiles()
{
  for (uint tile_code = 0; tile_code < 256; tile_code++)
  {
    gfx_decode_tile(cast(ubyte) tile_code);
  }
  for (uint sprite_code = 0; sprite_code < 64; sprite_code++)
  {
    gfx_decode_sprite(cast(ubyte) sprite_code);
  }
  // write a special opaque 16x16 block which will be used for the fade-effect
  for (uint y = TILE_HEIGHT; y < TILE_TEXTURE_HEIGHT; y++)
  {
    for (uint x = 64 * SPRITE_WIDTH; x < 65 * SPRITE_WIDTH; x++)
    {
      state.gfx.tile_pixels[y][x] = 1;
    }
  }
}

/* decode the Pacman color palette into a palette texture, on the original
    hardware, color lookup happens in two steps, first through 256-entry
    palette which indirects into a 32-entry hardware-color palette
    (of which only 16 entries are used on the Pacman hardware)
*/
void gfx_decode_color_palette()
{
  uint[32] hw_colors = void;
  for (int i = 0; i < 32; i++)
  {
    /*
           Each color ROM entry describes an RGB color in 1 byte:

           | 7| 6| 5| 4| 3| 2| 1| 0|
           |B1|B0|G2|G1|G0|R2|R1|R0|

           Intensities are: 0x97 + 0x47 + 0x21
        */
    ubyte rgb = rom_hwcolors[i];
    ubyte r = ((rgb >> 0) & 1) * 0x21 + ((rgb >> 1) & 1) * 0x47 + ((rgb >> 2) & 1) * 0x97;
    ubyte g = ((rgb >> 3) & 1) * 0x21 + ((rgb >> 4) & 1) * 0x47 + ((rgb >> 5) & 1) * 0x97;
    ubyte b = ((rgb >> 6) & 1) * 0x47 + ((rgb >> 7) & 1) * 0x97;
    hw_colors[i] = 0xFF000000 | (b << 16) | (g << 8) | r;
  }
  for (int i = 0; i < 256; i++)
  {
    state.gfx.color_palette[i] = hw_colors[rom_palette[i] & 0xF];
    // first color in each color block is transparent
    if ((i & 3) == 0)
    {
      state.gfx.color_palette[i] &= 0x00FFFFFF;
    }
  }
}

void gfx_init()
{
  sg.Desc gfx = {
    buffer_pool_size: 2,
    image_pool_size: 3,
    shader_pool_size: 2,
    pipeline_pool_size: 2,
    attachments_pool_size: 1,
    environment: sglue.environment,
    logger: {func: &log.slog_func},
  };
  sg.setup(gfx);
  disable(state.gfx.fadein);
  disable(state.gfx.fadeout);
  state.gfx.fade = 0xFF;
  spr_clear();
  gfx_decode_tiles;
  gfx_decode_color_palette;
  gfx_create_resources;
}

void gfx_shutdown()
{
  sg.shutdown;
}

void gfx_add_vertex(float x, float y, float u, float v, ubyte color_code, ubyte opacity)
{
  assert(state.gfx.num_vertices < MAX_VERTICES);
  Vertex* vtx = &state.gfx.vertices[state.gfx.num_vertices++];
  vtx.x = x;
  vtx.y = y;
  vtx.u = u;
  vtx.v = v;
  vtx.attr = (opacity << 8) | color_code;
}

void gfx_add_tile_vertices(uint tx, uint ty, ubyte tile_code, ubyte color_code)
{
  assert((tx < DISPLAY_TILES_X) && (ty < DISPLAY_TILES_Y));
  const float dx = 1.0f / DISPLAY_TILES_X;
  const float dy = 1.0f / DISPLAY_TILES_Y;
  const float du = cast(float) TILE_WIDTH / TILE_TEXTURE_WIDTH;
  const float dv = cast(float) TILE_HEIGHT / TILE_TEXTURE_HEIGHT;

  const float x0 = tx * dx;
  const float x1 = x0 + dx;
  const float y0 = ty * dy;
  const float y1 = y0 + dy;
  const float u0 = tile_code * du;
  const float u1 = u0 + du;
  const float v0 = 0.0f;
  const float v1 = dv;
  /*
        x0,y0
        +-----+
        | *   |
        |   * |
        +-----+
                x1,y1
    */
  gfx_add_vertex(x0, y0, u0, v0, color_code, 0xFF);
  gfx_add_vertex(x1, y0, u1, v0, color_code, 0xFF);
  gfx_add_vertex(x1, y1, u1, v1, color_code, 0xFF);
  gfx_add_vertex(x0, y0, u0, v0, color_code, 0xFF);
  gfx_add_vertex(x1, y1, u1, v1, color_code, 0xFF);
  gfx_add_vertex(x0, y1, u0, v1, color_code, 0xFF);
}

void gfx_add_playfield_vertices()
{
  for (uint ty = 0; ty < DISPLAY_TILES_Y; ty++)
  {
    for (uint tx = 0; tx < DISPLAY_TILES_X; tx++)
    {
      const ubyte tile_code = state.gfx.video_ram[ty][tx];
      const ubyte color_code = state.gfx.color_ram[ty][tx] & 0x1F;
      gfx_add_tile_vertices(tx, ty, tile_code, color_code);
    }
  }
}

void gfx_add_debugmarker_vertices()
{
  for (int i = 0; i < NUM_DEBUG_MARKERS; i++)
  {
    const DebugMarker* dbg = &state.gfx.debug_marker[i];
    if (dbg.enabled)
    {
      gfx_add_tile_vertices(dbg.tile_pos.x, dbg.tile_pos.y, dbg.tile, dbg.color);
    }
  }
}

void gfx_add_sprite_vertices()
{
  const float dx = 1.0f / DISPLAY_PIXELS_X;
  const float dy = 1.0f / DISPLAY_PIXELS_Y;
  const float du = cast(float) SPRITE_WIDTH / TILE_TEXTURE_WIDTH;
  const float dv = cast(float) SPRITE_HEIGHT / TILE_TEXTURE_HEIGHT;
  for (int i = 0; i < NUM_SPRITES; i++)
  {
    const Sprite* spr = &state.gfx.sprite[i];
    if (spr.enabled)
    {
      float x0, x1, y0, y1;
      if (spr.flipx)
      {
        x1 = spr.pos.x * dx;
        x0 = x1 + dx * SPRITE_WIDTH;
      }
      else
      {
        x0 = spr.pos.x * dx;
        x1 = x0 + dx * SPRITE_WIDTH;
      }
      if (spr.flipy)
      {
        y1 = spr.pos.y * dy;
        y0 = y1 + dy * SPRITE_HEIGHT;
      }
      else
      {
        y0 = spr.pos.y * dy;
        y1 = y0 + dy * SPRITE_HEIGHT;
      }
      const float u0 = spr.tile * du;
      const float u1 = u0 + du;
      const float v0 = (cast(float) TILE_HEIGHT / TILE_TEXTURE_HEIGHT);
      const float v1 = v0 + dv;
      const ubyte color = spr.color;
      gfx_add_vertex(x0, y0, u0, v0, color, 0xFF);
      gfx_add_vertex(x1, y0, u1, v0, color, 0xFF);
      gfx_add_vertex(x1, y1, u1, v1, color, 0xFF);
      gfx_add_vertex(x0, y0, u0, v0, color, 0xFF);
      gfx_add_vertex(x1, y1, u1, v1, color, 0xFF);
      gfx_add_vertex(x0, y1, u0, v1, color, 0xFF);
    }
  }
}

void gfx_add_fade_vertices()
{
  // sprite tile 64 is a special 16x16 opaque block
  const float du = cast(float) SPRITE_WIDTH / TILE_TEXTURE_WIDTH;
  const float dv = cast(float) SPRITE_HEIGHT / TILE_TEXTURE_HEIGHT;
  const float u0 = 64 * du;
  const float u1 = u0 + du;
  const float v0 = cast(float) TILE_HEIGHT / TILE_TEXTURE_HEIGHT;
  const float v1 = v0 + dv;

  const ubyte fade = state.gfx.fade;
  gfx_add_vertex(0.0f, 0.0f, u0, v0, 0, fade);
  gfx_add_vertex(1.0f, 0.0f, u1, v0, 0, fade);
  gfx_add_vertex(1.0f, 1.0f, u1, v1, 0, fade);
  gfx_add_vertex(0.0f, 0.0f, u0, v0, 0, fade);
  gfx_add_vertex(1.0f, 1.0f, u1, v1, 0, fade);
  gfx_add_vertex(0.0f, 1.0f, u0, v1, 0, fade);
}

// adjust the viewport so that the aspect ratio is always correct
void gfx_adjust_viewport(int canvas_width, int canvas_height)
{
  const float canvas_aspect = cast(float) canvas_width / canvas_height;
  const float playfield_aspect = cast(float) DISPLAY_TILES_X / DISPLAY_TILES_Y;
  int vp_x, vp_y, vp_w, vp_h;
  const int border = 10;
  if (playfield_aspect < canvas_aspect)
  {
    vp_y = border;
    vp_h = canvas_height - 2 * border;
    vp_w = cast(int)(canvas_height * playfield_aspect - 2 * border);
    vp_x = (canvas_width - vp_w) / 2;
  }
  else
  {
    vp_x = border;
    vp_w = canvas_width - 2 * border;
    vp_h = cast(int)(canvas_width / playfield_aspect - 2 * border);
    vp_y = (canvas_height - vp_h) / 2;
  }
  sg.applyViewport(vp_x, vp_y, vp_w, vp_h, true);
}

// handle fadein/fadeout
void gfx_fade()
{
  if (between(state.gfx.fadein, 0, FADE_TICKS))
  {
    float t = cast(float) since(state.gfx.fadein) / FADE_TICKS;
    state.gfx.fade = cast(ubyte)(255.0f * (1.0f - t));
  }
  if (after_once(state.gfx.fadein, FADE_TICKS))
  {
    state.gfx.fade = 0;
  }
  if (between(state.gfx.fadeout, 0, FADE_TICKS))
  {
    float t = cast(float) since(state.gfx.fadeout) / FADE_TICKS;
    state.gfx.fade = cast(ubyte)(255.0f * t);
  }
  if (after_once(state.gfx.fadeout, FADE_TICKS))
  {
    state.gfx.fade = 255;
  }
}

void gfx_draw()
{
  // handle fade in/out
  gfx_fade();

  // update the playfield and sprite vertex buffer
  state.gfx.num_vertices = 0;
  gfx_add_playfield_vertices();
  gfx_add_sprite_vertices();
  gfx_add_debugmarker_vertices();
  if (state.gfx.fade > 0)
  {
    gfx_add_fade_vertices();
  }
  assert(state.gfx.num_vertices <= MAX_VERTICES);
  sg.Range rng = {
    ptr: state.gfx.vertices.ptr, size: state.gfx.num_vertices * Vertex.sizeof
  };
  sg.updateBuffer(state.gfx.offscreen.vbuf, rng);

  // render tiles and sprites into offscreen render target
  sg.Pass offs_pass = {
    action: state.gfx.pass_action, attachments: state.gfx.offscreen.attachments
  };
  sg.beginPass(offs_pass);
  sg.applyPipeline(state.gfx.offscreen.pip);
  sg.applyBindings(state.gfx.offscreen.bind);
  sg.draw(0, state.gfx.num_vertices, 1);
  sg.endPass;

  // upscale-render the offscreen render target into the display framebuffer
  sg.Pass display_pass = {
    action: state.gfx.pass_action, swapchain: sglue.swapchain
  };
  sg.beginPass(display_pass);
  gfx_adjust_viewport(sapp.width, sapp.height);
  sg.applyPipeline(state.gfx.display.pip);
  sg.applyBindings(state.gfx.display.bind);
  sg.draw(0, 4, 1);
  sg.endPass;
  sg.commit;
}

static State state;

// clear tile and color buffer
void vid_clear(ubyte tile_code, ubyte color_code)
{
  memset(&state.gfx.video_ram, tile_code, state.gfx.video_ram.sizeof);
  memset(&state.gfx.color_ram, color_code, state.gfx.color_ram.sizeof);
}

// clear the playfield's rectangle in the color buffer
void vid_color_playfield(ubyte color_code)
{
  for (int y = 3; y < DISPLAY_TILES_Y - 2; y++)
  {
    for (int x = 0; x < DISPLAY_TILES_X; x++)
    {
      state.gfx.color_ram[y][x] = color_code;
    }
  }
}

// check if a tile position is valid
bool valid_tile_pos(Int2 tile_pos)
{
  return ((tile_pos.x >= 0) && (tile_pos.x < DISPLAY_TILES_X) && (tile_pos.y >= 0) && (
      tile_pos.y < DISPLAY_TILES_Y));
}

// put a color into the color buffer
void vid_color(Int2 tile_pos, ubyte color_code)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.color_ram[tile_pos.y][tile_pos.x] = color_code;
}

// put a tile into the tile buffer
void vid_tile(Int2 tile_pos, ubyte tile_code)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.video_ram[tile_pos.y][tile_pos.x] = tile_code;
}

// put a colored tile into the tile and color buffers
void vid_color_tile(Int2 tile_pos, ubyte color_code, ubyte tile_code)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.video_ram[tile_pos.y][tile_pos.x] = tile_code;
  state.gfx.color_ram[tile_pos.y][tile_pos.x] = color_code;
}

// translate ASCII char into "NAMCO char"
char conv_char(char c)
{
  switch (c)
  {
  case ' ':
    c = 0x40;
    break;
  case '/':
    c = 58;
    break;
  case '-':
    c = 59;
    break;
  case '\"':
    c = 38;
    break;
  case '!':
    c = 'Z' + 1;
    break;
  default:
    break;
  }
  return c;
}

// put colored char into tile+color buffers
void vid_color_char(Int2 tile_pos, ubyte color_code, char chr)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.video_ram[tile_pos.y][tile_pos.x] = conv_char(chr);
  state.gfx.color_ram[tile_pos.y][tile_pos.x] = color_code;
}

// put char into tile buffer
void vid_char(Int2 tile_pos, char chr)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.video_ram[tile_pos.y][tile_pos.x] = conv_char(chr);
}

// put colored text into the tile+color buffers
void vid_color_text(Int2 tile_pos, ubyte color_code, const(char)* text)
{
  assert(valid_tile_pos(tile_pos));
  while (*text)
  {
    ubyte chr = cast(ubyte)*text++;
    if (tile_pos.x < DISPLAY_TILES_X)
    {
      vid_color_char(tile_pos, color_code, chr);
      tile_pos.x++;
    }
    else
    {
      break;
    }
  }
}

// put text into the tile buffer
void vid_text(Int2 tile_pos, const(char)* text)
{
  assert(valid_tile_pos(tile_pos));
  while (*text)
  {
    ubyte chr = cast(ubyte)*text++;
    if (tile_pos.x < DISPLAY_TILES_X)
    {
      vid_char(tile_pos, chr);
      tile_pos.x++;
    }
    else
    {
      break;
    }
  }
}

/* print colored score number into tile+color buffers from right to left(!),
    scores are /10, the last printed number is always 0,
    a zero-score will print as '00' (this is the same as on
    the Pacman arcade machine)
*/
void vid_color_score(Int2 tile_pos, ubyte color_code, uint score)
{
  vid_color_char(tile_pos, color_code, '0');
  tile_pos.x--;
  for (int digit = 0; digit < 8; digit++)
  {
    char chr = (score % 10) + '0';
    if (valid_tile_pos(tile_pos))
    {
      vid_color_char(tile_pos, color_code, chr);
      tile_pos.x--;
      score /= 10;
      if (0 == score)
      {
        break;
      }
    }
  }
}

/* draw a colored tile-quad arranged as:
    |t+1|t+0|
    |t+3|t+2|

   This is (for instance) used to render the current "lives" and fruit
   symbols at the lower border.
*/
void vid_draw_tile_quad(Int2 tile_pos, ubyte color_code, ubyte tile_code)
{
  for (ubyte yy = 0; yy < 2; yy++)
  {
    for (ubyte xx = 0; xx < 2; xx++)
    {
      auto t = cast(ubyte) tile_code + yy * 2 + (1 - xx);
      vid_color_tile(i2(cast(short)(xx + tile_pos.x), cast(short)(yy + tile_pos.y)), color_code, cast(
          ubyte) t);
    }
  }
}

// draw the fruit bonus score tiles (when Pacman has eaten the bonus fruit)
void vid_fruit_score(Fruit fruit_type)
{
  assert((fruit_type >= 0) && (fruit_type < Fruit.NUM_FRUITS));
  ubyte color_code = (fruit_type == Fruit.FRUIT_NONE) ? COLOR_DOT : COLOR_FRUIT_SCORE;
  for (int i = 0; i < 4; i++)
  {
    vid_color_tile(i2(cast(short)(12 + i), cast(short) 20), color_code, fruit_score_tiles[fruit_type][i]);
  }
}

// clear input state and disable input
void input_disable()
{
  memset(&state.input, 0, state.input.sizeof);
}

// enable input again
void input_enable()
{
  state.input.enabled = true;
}

// get the current input as dir_t
Dir input_dir(Dir default_dir)
{
  if (state.input.up)
  {
    return Dir.DIR_UP;
  }
  else if (state.input.down)
  {
    return Dir.DIR_DOWN;
  }
  else if (state.input.right)
  {
    return Dir.DIR_RIGHT;
  }
  else if (state.input.left)
  {
    return Dir.DIR_LEFT;
  }
  else
  {
    return default_dir;
  }
}

// return the number of ticks since a time trigger was triggered
uint since(scope ref Trigger t)
{
  if (state.timing.tick >= t.tick)
  {
    return state.timing.tick - t.tick;
  }
  else
  {
    return DISABLED_TICKS;
  }
}

// check if a time trigger is between begin and end tick
bool between(scope ref Trigger t, uint begin, uint end)
{
  assert(begin < end);
  if (t.tick != DISABLED_TICKS)
  {
    uint ticks = since(t);
    return (ticks >= begin) && (ticks < end);
  }
  else
  {
    return false;
  }
}

// check if a time trigger was triggered exactly N ticks ago
bool after_once(scope ref Trigger t, uint ticks)
{
  return since(t) == ticks;
}

// check if a time trigger was triggered more than N ticks ago
bool after(scope ref Trigger t, uint ticks)
{
  uint s = since(t);
  if (s != DISABLED_TICKS)
  {
    return s >= ticks;
  }
  else
  {
    return false;
  }
}

// same as between(t, 0, ticks)
bool before(scope ref Trigger t, uint ticks)
{
  uint s = since(t);
  if (s != DISABLED_TICKS)
  {
    return s < ticks;
  }
  else
  {
    return false;
  }
}

// disable and clear all sprites
void spr_clear()
{
  memset(&state.gfx.sprite, 0, state.gfx.sprite.sizeof);
}

// get pointer to pacman sprite
scope Sprite* spr_pacman()
{
  return &state.gfx.sprite[SpriteIndex.SPRITE_PACMAN];
}

// get pointer to ghost sprite
scope Sprite* spr_ghost(GhostType type)
{
  assert((type >= 0) && (type < GhostType.NUM_GHOSTS));
  return &state.gfx.sprite[SpriteIndex.SPRITE_BLINKY + type];
}

// get pointer to fruit sprite
scope Sprite* spr_fruit()
{
  return &state.gfx.sprite[SpriteIndex.SPRITE_FRUIT];
}

// set sprite to animated Pacman
void spr_anim_pacman(Dir dir, uint tick)
{
  // animation frames for horizontal and vertical movement
  const ubyte[4][2] tiles = [
    [44, 46, 48, 46], // horizontal (needs flipx)
    [45, 47, 48, 47] // vertical (needs flipy)
  ];
  Sprite* spr = spr_pacman();
  uint phase = (tick / 2) & 3;
  spr.tile = tiles[dir & 1][phase];
  spr.color = COLOR_PACMAN;
  spr.flipx = (dir == Dir.DIR_LEFT);
  spr.flipy = (dir == Dir.DIR_UP);
}

// set sprite to Pacman's death sequence
void spr_anim_pacman_death(uint tick)
{
  // the death animation tile sequence starts at sprite tile number 52 and ends at 63
  Sprite* spr = spr_pacman();
  uint tile = 52 + (tick / 8);
  if (tile > 63)
  {
    tile = 63;
  }
  spr.tile = cast(ubyte) tile;
  spr.flipx = spr.flipy = false;
}

// set sprite to animated ghost
void spr_anim_ghost(GhostType ghost_type, Dir dir, uint tick)
{
  assert((dir >= 0) && (dir < Dir.NUM_DIRS));
  const ubyte[2][4] tiles = [
    [32, 33], // right
    [34, 35], // down
    [36, 37], // left
    [38, 39], // up
  ];
  uint phase = (tick / 8) & 1;
  Sprite* spr = spr_ghost(ghost_type);
  spr.tile = tiles[dir][phase];
  spr.color = cast(ubyte)(COLOR_BLINKY + 2 * ghost_type);
  spr.flipx = false;
  spr.flipy = false;
}

// set sprite to frightened ghost
void spr_anim_ghost_frightened(GhostType ghost_type, uint tick)
{
  const ubyte[2] tiles = [28, 29];
  uint phase = (tick / 4) & 1;
  Sprite* spr = spr_ghost(ghost_type);
  spr.tile = tiles[phase];
  if (tick > cast(uint)(levelspec(state.game.round).fright_ticks - 60))
  {
    // towards end of frightening period, start blinking
    spr.color = (tick & 0x10) ? COLOR_FRIGHTENED : COLOR_FRIGHTENED_BLINKING;
  }
  else
  {
    spr.color = COLOR_FRIGHTENED;
  }
  spr.flipx = false;
  spr.flipy = false;
}

/* set sprite to ghost eyes, these are the normal ghost sprite
    images but with a different color code which makes
    only the eyes visible
*/
void spr_anim_ghost_eyes(GhostType ghost_type, Dir dir)
{
  assert((dir >= 0) && (dir < Dir.NUM_DIRS));
  const ubyte[Dir.NUM_DIRS] tiles = [32, 34, 36, 38];
  Sprite* spr = spr_ghost(ghost_type);
  spr.tile = tiles[dir];
  spr.color = COLOR_EYES;
  spr.flipx = false;
  spr.flipy = false;
}

// convert pixel position to tile position
Int2 pixel_to_tile_pos(Int2 pix_pos)
{
  return i2(pix_pos.x / TILE_WIDTH, pix_pos.y / TILE_HEIGHT);
}

// clamp tile pos to valid playfield coords
Int2 clamped_tile_pos(Int2 tile_pos)
{
  Int2 res = tile_pos;
  if (res.x < 0)
  {
    res.x = 0;
  }
  else if (res.x >= DISPLAY_TILES_X)
  {
    res.x = DISPLAY_TILES_X - 1;
  }
  if (res.y < 3)
  {
    res.y = 3;
  }
  else if (res.y >= (DISPLAY_TILES_Y - 2))
  {
    res.y = DISPLAY_TILES_Y - 3;
  }
  return res;
}

// convert a direction to a movement vector
Int2 dir2Vec(Dir dir)
{
  assert((dir >= 0) && (dir < Dir.NUM_DIRS));
  const Int2[Dir.NUM_DIRS] dir_map = [
    {+1, 0}, {0, +1}, {-1, 0}, {0, -1}
  ];
  return dir_map[dir];
}

// return the reverse direction
Dir reverse_dir(Dir dir)
{
  switch (dir)
  {
  case Dir.DIR_RIGHT:
    return Dir.DIR_LEFT;
  case Dir.DIR_DOWN:
    return Dir.DIR_UP;
  case Dir.DIR_LEFT:
    return Dir.DIR_RIGHT;
  default:
    return Dir.DIR_DOWN;
  }
}

// return tile code at tile position
ubyte tile_code_at(Int2 tile_pos)
{
  assert((tile_pos.x >= 0) && (tile_pos.x < DISPLAY_TILES_X));
  assert((tile_pos.y >= 0) && (tile_pos.y < DISPLAY_TILES_Y));
  return state.gfx.video_ram[tile_pos.y][tile_pos.x];
}

// check if a tile position contains a blocking tile (walls and ghost house door)
bool is_blocking_tile(Int2 tile_pos)
{
  return tile_code_at(tile_pos) >= 0xC0;
}

// check if a tile position contains a dot tile
bool is_dot(Int2 tile_pos)
{
  return tile_code_at(tile_pos) == TILE_DOT;
}

// check if a tile position contains a pill tile
bool is_pill(Int2 tile_pos)
{
  return tile_code_at(tile_pos) == TILE_PILL;
}

// check if a tile position is in the teleport tunnel
bool is_tunnel(Int2 tile_pos)
{
  return (tile_pos.y == 17) && ((tile_pos.x <= 5) || (tile_pos.x >= 22));
}

// check if a position is in the ghost's red zone, where upward movement is forbidden
// (see Pacman Dossier "Areas To Exploit")
bool is_redzone(Int2 tile_pos)
{
  return ((tile_pos.x >= 11) && (tile_pos.x <= 16) && ((tile_pos.y == 14) || (tile_pos.y == 26)));
}

// test if movement from a pixel position in a wanted direction is possible,
// allow_cornering is Pacman's feature to take a diagonal shortcut around corners
bool can_move(Int2 pos, Dir wanted_dir, bool allow_cornering)
{
  const Int2 dir_vec = dir2Vec(wanted_dir);
  const Int2 dist_mid = dist_to_tile_mid(pos);

  // distance to midpoint in move direction and perpendicular direction
  short move_dist_mid, perp_dist_mid;
  if (dir_vec.y != 0)
  {
    move_dist_mid = dist_mid.y;
    perp_dist_mid = dist_mid.x;
  }
  else
  {
    move_dist_mid = dist_mid.x;
    perp_dist_mid = dist_mid.y;
  }

  // look one tile ahead in movement direction
  const Int2 tile_pos = pixel_to_tile_pos(pos);
  const Int2 check_pos = clamped_tile_pos(add_i2(tile_pos, dir_vec));
  const bool is_blocked = is_blocking_tile(check_pos);
  if ((!allow_cornering && (0 != perp_dist_mid)) || (is_blocked && (0 == move_dist_mid)))
  {
    // way is blocked
    return false;
  }
  else
  {
    // way is free
    return true;
  }
}

// compute a new pixel position along a direction (without blocking check!)
Int2 move(Int2 pos, Dir dir, bool allow_cornering)
{
  const Int2 dir_vec = dir2Vec(dir);
  pos = add_i2(pos, dir_vec);

  // if cornering is allowed, drag the position towards the center-line
  if (allow_cornering)
  {
    const Int2 dist_mid = dist_to_tile_mid(pos);
    if (dir_vec.x != 0)
    {
      if (dist_mid.y < 0)
      {
        pos.y--;
      }
      else if (dist_mid.y > 0)
      {
        pos.y++;
      }
    }
    else if (dir_vec.y != 0)
    {
      if (dist_mid.x < 0)
      {
        pos.x--;
      }
      else if (dist_mid.x > 0)
      {
        pos.x++;
      }
    }
  }

  // wrap x-position around (only possible in the teleport-tunnel)
  if (pos.x < 0)
  {
    pos.x = DISPLAY_PIXELS_X - 1;
  }
  else if (pos.x >= DISPLAY_PIXELS_X)
  {
    pos.x = 0;
  }
  return pos;
}
