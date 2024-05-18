module game;
import data;
import core.stdc.string : memset;

// set time trigger to the next game tick
static void start(ref Trigger t)
{
  t.tick = state.timing.tick + 1;
}

// set time trigger to a future tick
static void start_after(ref Trigger t, uint ticks)
{
  t.tick = state.timing.tick + ticks;
}

// check if a time trigger is triggered
static bool now(ref Trigger t)
{
  return t.tick == state.timing.tick;
}

// set a debug marker
version (DbgMarkers)
{
  static void dbg_marker(int index, Int2 tile_pos, ubyte tile_code, ubyte color_code)
  {
    assert((index >= 0) && (index < NUM_DEBUG_MARKERS));
    state.gfx.debug_marker[index].enabled = true;
    state.gfx.debug_marker[index].tile = tile_code;
    state.gfx.debug_marker[index].color = color_code;
    state.gfx.debug_marker[index].tile_pos = clamped_tile_pos(tile_pos);
  }
}

// dfmt off
// initialize the playfield tiles
static void game_init_playfield() {
    vid_color_playfield(COLOR_DOT);
    // decode the playfield from an ASCII map into tiles codes
    static const (char)* tiles =
       //0123456789012345678901234567
        "0UUUUUUUUUUUU45UUUUUUUUUUUU1
        L............rl............R
        L.ebbf.ebbbf.rl.ebbbf.ebbf.R
        LPr  l.r   l.rl.r   l.r  lPR
        L.guuh.guuuh.gh.guuuh.guuh.R
        L..........................R
        L.ebbf.ef.ebbbbbbf.ef.ebbf.R
        L.guuh.rl.guuyxuuh.rl.guuh.R
        L......rl....rl....rl......R
        2BBBBf.rzbbf rl ebbwl.eBBBB3
             L.rxuuh gh guuyl.R     
             L.rl          rl.R     
             L.rl mjs--tjn rl.R     
        UUUUUh.gh i      q gh.gUUUUU
              .   i      q   .      
        BBBBBf.ef i      q ef.eBBBBB
             L.rl okkkkkkp rl.R     
             L.rl          rl.R     
             L.rl ebbbbbbf rl.R     
        0UUUUh.gh guuyxuuh gh.gUUUU1
        L............rl............R
        L.ebbf.ebbbf.rl.ebbbf.ebbf.R
        L.guyl.guuuh.gh.guuuh.rxuh.R
        LP..rl.......  .......rl..PR
        6bf.rl.ef.ebbbbbbf.ef.rl.eb8
        7uh.gh.rl.guuyxuuh.rl.gh.gu9
        L......rl....rl....rl......R
        L.ebbbbwzbbf.rl.ebbwzbbbbf.R
        L.guuuuuuuuh.gh.guuuuuuuuh.R
        L..........................R
        2BBBBBBBBBBBBBBBBBBBBBBBBBB3"; // 33
       //0123456789012345678901234567
    ubyte[128] t = void;
    for (int i = 0; i < 128; i++) { t[i]=TILE_DOT; }
    t[' ']=0x40; t['0']=0xD1; t['1']=0xD0; t['2']=0xD5; t['3']=0xD4; t['4']=0xFB;
    t['5']=0xFA; t['6']=0xD7; t['7']=0xD9; t['8']=0xD6; t['9']=0xD8; t['U']=0xDB;
    t['L']=0xD3; t['R']=0xD2; t['B']=0xDC; t['b']=0xDF; t['e']=0xE7; t['f']=0xE6;
    t['g']=0xEB; t['h']=0xEA; t['l']=0xE8; t['r']=0xE9; t['u']=0xE5; t['w']=0xF5;
    t['x']=0xF2; t['y']=0xF3; t['z']=0xF4; t['m']=0xED; t['n']=0xEC; t['o']=0xEF;
    t['p']=0xEE; t['j']=0xDD; t['i']=0xD2; t['k']=0xDB; t['q']=0xD3; t['s']=0xF1;
    t['t']=0xF0; t['-']=TILE_DOOR; t['P']=TILE_PILL;
    for (int y = 3, i = 0; y <= 33; y++) {
        for (int x = 0; x < 28; x++, i++) {
            state.gfx.video_ram[y][x] = t[tiles[i] & 127];
        }
    }
    // ghost house gate colors
    vid_color(i2(13,15), 0x18);
    vid_color(i2(14,15), 0x18);
}
// dfmt on

// disable all game loop timers
static void game_disable_timers()
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
static void game_init()
{
  input_enable();
  game_disable_timers();
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

// // setup state at start of a game round
// static void game_round_init() {
//     spr_clear();

//     // clear the "PLAYER ONE" text
//     vid_color_text(i2(9,14), 0x10, "          ");

//     /* if a new round was started because Pacman has "won" (eaten all dots),
//         redraw the playfield and reset the global dot counter
//     */
//     if (state.game.num_dots_eaten == NUM_DOTS) {
//         state.game.round++;
//         state.game.num_dots_eaten = 0;
//         game_init_playfield();
//         state.game.global_dot_counter_active = false;
//     }
//     else {
//         /* if the previous round was lost, use the global dot counter
//            to detect when ghosts should leave the ghost house instead
//            of the per-ghost dot counter
//         */
//         if (state.game.num_lives != NUM_LIVES) {
//             state.game.global_dot_counter_active = true;
//             state.game.global_dot_counter = 0;
//         }
//         state.game.num_lives--;
//     }
//     assert(state.game.num_lives >= 0);

//     state.game.active_fruit = FRUIT_NONE;
//     state.game.freeze = FREEZETYPE_READY;
//     state.game.xorshift = 0x12345678;   // random-number-generator seed
//     state.game.num_ghosts_eaten = 0;
//     game_disable_timers();

//     vid_color_text(i2(11, 20), 0x9, "READY!");

//     // the force-house timer forces ghosts out of the house if Pacman isn't
//     // eating dots for a while
//     start(state.game.force_leave_house);

//     // Pacman starts running to the left
//     State.Game.Pacman pacman = {
//         actor: {
//             dir: Dir.DIR_LEFT,
//             pos: { x: 14 * 8, y: 26 * 8 + 4 },
//         },
//     };
//     State.Gfx.Sprite[SPRITE_PACMAN] sprite = { enabled: true, color: COLOR_PACMAN };

//     // Blinky starts outside the ghost house, looking to the left, and in scatter mode
//     Gtate.Game.Ghost[GHOSTTYPE_BLINKY] ghost = {
//         actor: {
//             dir: DIR_LEFT,
//             pos: ghost_starting_pos[GHOSTTYPE_BLINKY],
//         },
//         type: GHOSTTYPE_BLINKY,
//         next_dir: DIR_LEFT,
//         state: GHOSTSTATE_SCATTER,
//         frightened: disabled_timer(),
//         eaten: disabled_timer(),
//         dot_counter: 0,
//         dot_limit: 0
//     };
//     sprite[SPRITE_BLINKY].enabled=true;
//     sprite[SPRITE_BLINKY].color= COLOR_BLINKY;

//     // Pinky starts in the middle slot of the ghost house, moving down
//     state.game.ghost[GHOSTTYPE_PINKY] = (ghost_t) {
//         .actor = {
//             .dir = DIR_DOWN,
//             .pos = ghost_starting_pos[GHOSTTYPE_PINKY],
//         },
//         .type = GHOSTTYPE_PINKY,
//         .next_dir = DIR_DOWN,
//         .state = GHOSTSTATE_HOUSE,
//         .frightened = disabled_timer(),
//         .eaten = disabled_timer(),
//         .dot_counter = 0,
//         .dot_limit = 0
//     };
//     state.gfx.sprite[SPRITE_PINKY] = (Sprite) { .enabled = true, .color = COLOR_PINKY };

//     // Inky starts in the left slot of the ghost house moving up
//     state.game.ghost[GHOSTTYPE_INKY] = (ghost_t) {
//         .actor = {
//             .dir = DIR_UP,
//             .pos = ghost_starting_pos[GHOSTTYPE_INKY],
//         },
//         .type = GHOSTTYPE_INKY,
//         .next_dir = DIR_UP,
//         .state = GHOSTSTATE_HOUSE,
//         .frightened = disabled_timer(),
//         .eaten = disabled_timer(),
//         .dot_counter = 0,
//         // FIXME: needs to be adjusted by current round!
//         .dot_limit = 30
//     };
//     state.gfx.sprite[SPRITE_INKY] = (Sprite) { .enabled = true, .color = COLOR_INKY };

//     // Clyde starts in the right slot of the ghost house, moving up
//     state.game.ghost[GHOSTTYPE_CLYDE] = (ghost_t) {
//         .actor = {
//             .dir = DIR_UP,
//             .pos = ghost_starting_pos[GHOSTTYPE_CLYDE],
//         },
//         .type = GHOSTTYPE_CLYDE,
//         .next_dir = DIR_UP,
//         .state = GHOSTSTATE_HOUSE,
//         .frightened = disabled_timer(),
//         .eaten = disabled_timer(),
//         .dot_counter = 0,
//         // FIXME: needs to be adjusted by current round!
//         .dot_limit = 60,
//     };
//     state.gfx.sprite[SPRITE_CLYDE] = (Sprite) { .enabled = true, .color = COLOR_CLYDE };
// }

// // update dynamic background tiles
// static void game_update_tiles() {
//     // print score and hiscore
//     vid_color_score(i2(6,1), COLOR_DEFAULT, state.game.score);
//     if (state.game.hiscore > 0) {
//         vid_color_score(i2(16,1), COLOR_DEFAULT, state.game.hiscore);
//     }

//     // update the energizer pill colors (blinking/non-blinking)
//     static const Int2 pill_pos[NUM_PILLS] = { { 1, 6 }, { 26, 6 }, { 1, 26 }, { 26, 26 } };
//     for (int i = 0; i < NUM_PILLS; i++) {
//         if (state.game.freeze) {
//             vid_color(pill_pos[i], COLOR_DOT);
//         }
//         else {
//             vid_color(pill_pos[i], (state.timing.tick & 0x8) ? 0x10:0);
//         }
//     }

//     // clear the fruit-eaten score after Pacman has eaten a bonus fruit
//     if (after_once(state.game.fruit_eaten, 2*60)) {
//         vid_fruit_score(FRUIT_NONE);
//     }

//     // remaining lives at bottom left screen
//     for (int i = 0; i < NUM_LIVES; i++) {
//         ubyte color = (i < state.game.num_lives) ? COLOR_PACMAN : 0;
//         vid_draw_tile_quad(i2(2+2*i,34), color, TILE_LIFE);
//     }

//     // bonus fruit list in bottom-right corner
//     {
//         int16_t x = 24;
//         for (int i = ((int)state.game.round - NUM_STATUS_FRUITS + 1); i <= (int)state.game.round; i++) {
//             if (i >= 0) {
//                 fruit_t fruit = levelspec(i).bonus_fruit;
//                 ubyte tile_code = fruit_tiles_colors[fruit][0];
//                 ubyte color_code = fruit_tiles_colors[fruit][2];
//                 vid_draw_tile_quad(i2(x,34), color_code, tile_code);
//                 x -= 2;
//             }
//         }
//     }

//     // if game round was won, render the entire playfield as blinking blue/white
//     if (after(state.game.round_won, 1*60)) {
//         if (since(state.game.round_won) & 0x10) {
//             vid_color_playfield(COLOR_DOT);
//         }
//         else {
//             vid_color_playfield(COLOR_WHITE_BORDER);
//         }
//     }
// }

// // this function takes care of updating all sprite images during gameplay
// static void game_update_sprites() {
//     // update Pacman sprite
//     {
//         Sprite* spr = spr_pacman();
//         if (spr.enabled) {
//             const actor_t* actor = &state.game.pacman.actor;
//             spr.pos = actor_to_sprite_pos(actor.pos);
//             if (state.game.freeze & FREEZETYPE_EAT_GHOST) {
//                 // hide Pacman shortly after he's eaten a ghost (via an invisible Sprite tile)
//                 spr.tile = SPRITETILE_INVISIBLE;
//             }
//             else if (state.game.freeze & (FREEZETYPE_PRELUDE|FREEZETYPE_READY)) {
//                 // special case game frozen at start of round, show Pacman with 'closed mouth'
//                 spr.tile = SPRITETILE_PACMAN_CLOSED_MOUTH;
//             }
//             else if (state.game.freeze & FREEZETYPE_DEAD) {
//                 // play the Pacman-death-animation after a short pause
//                 if (after(state.game.pacman_eaten, PACMAN_EATEN_TICKS)) {
//                     spr_anim_pacman_death(since(state.game.pacman_eaten) - PACMAN_EATEN_TICKS);
//                 }
//             }
//             else {
//                 // regular Pacman animation
//                 spr_anim_pacman(actor.dir, actor.anim_tick);
//             }
//         }
//     }

//     // update ghost sprites
//     for (int i = 0; i < NUM_GHOSTS; i++) {
//         Sprite* sprite = spr_ghost(i);
//         if (sprite.enabled) {
//             const ghost_t* ghost = &state.game.ghost[i];
//             sprite.pos = actor_to_sprite_pos(ghost.actor.pos);
//             // if Pacman has just died, hide ghosts
//             if (state.game.freeze & FREEZETYPE_DEAD) {
//                 if (after(state.game.pacman_eaten, PACMAN_EATEN_TICKS)) {
//                     sprite.tile = SPRITETILE_INVISIBLE;
//                 }
//             }
//             // if Pacman has won the round, hide ghosts
//             else if (state.game.freeze & FREEZETYPE_WON) {
//                 sprite.tile = SPRITETILE_INVISIBLE;
//             }
//             else switch (ghost.state) {
//                 case GHOSTSTATE_EYES:
//                     if (before(ghost.eaten, GHOST_EATEN_FREEZE_TICKS)) {
//                         // if the ghost was *just* eaten by Pacman, the ghost's sprite
//                         // is replaced with a score number for a short time
//                         // (200 for the first ghost, followed by 400, 800 and 1600)
//                         sprite.tile = SPRITETILE_SCORE_200 + state.game.num_ghosts_eaten - 1;
//                         sprite.color = COLOR_GHOST_SCORE;
//                     }
//                     else {
//                         // afterwards, the ghost's eyes are shown, heading back to the ghost house
//                         spr_anim_ghost_eyes(i, ghost.next_dir);
//                     }
//                     break;
//                 case GHOSTSTATE_ENTERHOUSE:
//                     // ...still show the ghost eyes while entering the ghost house
//                     spr_anim_ghost_eyes(i, ghost.actor.dir);
//                     break;
//                 case GHOSTSTATE_FRIGHTENED:
//                     // when inside the ghost house, show the normal ghost images
//                     // (FIXME: ghost's inside the ghost house also show the
//                     // frightened appearance when Pacman has eaten an energizer pill)
//                     spr_anim_ghost_frightened(i, since(ghost.frightened));
//                     break;
//                 default:
//                     // show the regular ghost sprite image, the ghost's
//                     // 'next_dir' is used to visualize the direction the ghost
//                     // is heading to, this has the effect that ghosts already look
//                     // into the direction they will move into one tile ahead
//                     spr_anim_ghost(i, ghost.next_dir, ghost.actor.anim_tick);
//                     break;
//             }
//         }
//     }

//     // hide or display the currently active bonus fruit
//     if (state.game.active_fruit == FRUIT_NONE) {
//         spr_fruit().enabled = false;
//     }
//     else {
//         Sprite* spr = spr_fruit();
//         spr.enabled = true;
//         spr.pos = i2(13 * TILE_WIDTH, 19 * TILE_HEIGHT + TILE_HEIGHT/2);
//         spr.tile = fruit_tiles_colors[state.game.active_fruit][1];
//         spr.color = fruit_tiles_colors[state.game.active_fruit][2];
//     }
// }

// // return true if Pacman should move in this tick, when eating dots, Pacman
// // is slightly slower than ghosts, otherwise slightly faster
// static bool game_pacman_should_move() {
//     if (now(state.game.dot_eaten)) {
//         // eating a dot causes Pacman to stop for 1 tick
//         return false;
//     }
//     else if (since(state.game.pill_eaten) < 3) {
//         // eating an energizer pill causes Pacman to stop for 3 ticks
//         return false;
//     }
//     else {
//         return 0 != (state.timing.tick % 8);
//     }
// }

// // return number of pixels a ghost should move this tick, this can't be a simple
// // move/don't move boolean return value, because ghosts in eye state move faster
// // than one pixel per tick
// static int game_ghost_speed(const ghost_t* ghost) {
//     assert(ghost);
//     switch (ghost.state) {
//         case GHOSTSTATE_HOUSE:
//         case GHOSTSTATE_LEAVEHOUSE:
//             // inside house at half speed (estimated)
//             return state.timing.tick & 1;
//         case GHOSTSTATE_FRIGHTENED:
//             // move at 50% speed when frightened
//             return state.timing.tick & 1;
//         case GHOSTSTATE_EYES:
//         case GHOSTSTATE_ENTERHOUSE:
//             // estimated 1.5x when in eye state, Pacman Dossier is silent on this
//             return (state.timing.tick & 1) ? 1 : 2;
//         default:
//             if (is_tunnel(pixel_to_tile_pos(ghost.actor.pos))) {
//                 // move drastically slower when inside tunnel
//                 return ((state.timing.tick * 2) % 4) ? 1 : 0;
//             }
//             else {
//                 // otherwise move just a bit slower than Pacman
//                 return (state.timing.tick % 7) ? 1 : 0;
//             }
//     }
// }

// // return the current global scatter or chase phase
// static ghoststate_t game_scatter_chase_phase() {
//     uint t = since(state.game.round_started);
//     if (t < 7*60)       return GHOSTSTATE_SCATTER;
//     else if (t < 27*60) return GHOSTSTATE_CHASE;
//     else if (t < 34*60) return GHOSTSTATE_SCATTER;
//     else if (t < 54*60) return GHOSTSTATE_CHASE;
//     else if (t < 59*60) return GHOSTSTATE_SCATTER;
//     else if (t < 79*60) return GHOSTSTATE_CHASE;
//     else if (t < 84*60) return GHOSTSTATE_SCATTER;
//     else return GHOSTSTATE_CHASE;
// }

// // this function takes care of switching ghosts into a new state, this is one
// // of two important functions of the ghost AI (the other being the target selection
// // function below)
// static void game_update_ghost_state(ghost_t* ghost) {
//     assert(ghost);
//     ghoststate_t new_state = ghost.state;
//     switch (ghost.state) {
//         case GHOSTSTATE_EYES:
//             // When in eye state (heading back to the ghost house), check if the
//             // target position in front of the ghost house has been reached, then
//             // switch into ENTERHOUSE state. Since ghosts in eye state move faster
//             // than one pixel per tick, do a fuzzy comparison with the target pos
//             if (nearequal_i2(ghost.actor.pos, i2(ANTEPORTAS_X, ANTEPORTAS_Y), 1)) {
//                 new_state = GHOSTSTATE_ENTERHOUSE;
//             }
//             break;
//         case GHOSTSTATE_ENTERHOUSE:
//             // Ghosts that enter the ghost house during the gameplay loop immediately
//             // leave the house again after reaching their target position inside the house.
//             if (nearequal_i2(ghost.actor.pos, ghost_house_target_pos[ghost.type], 1)) {
//                 new_state = GHOSTSTATE_LEAVEHOUSE;
//             }
//             break;
//         case GHOSTSTATE_HOUSE:
//             // Ghosts only remain in the "house state" after a new game round
//             // has been started. The conditions when ghosts leave the house
//             // are a bit complicated, best to check the Pacman Dossier for the details.
//             if (after_once(state.game.force_leave_house, 4*60)) {
//                 // if Pacman hasn't eaten dots for 4 seconds, the next ghost
//                 // is forced out of the house
//                 // FIXME: time is reduced to 3 seconds after round 5
//                 new_state = GHOSTSTATE_LEAVEHOUSE;
//                 start(&state.game.force_leave_house);
//             }
//             else if (state.game.global_dot_counter_active) {
//                 // if Pacman has lost a life this round, the global dot counter is used
//                 if ((ghost.type == GHOSTTYPE_PINKY) && (state.game.global_dot_counter == 7)) {
//                     new_state = GHOSTSTATE_LEAVEHOUSE;
//                 }
//                 else if ((ghost.type == GHOSTTYPE_INKY) && (state.game.global_dot_counter == 17)) {
//                     new_state = GHOSTSTATE_LEAVEHOUSE;
//                 }
//                 else if ((ghost.type == GHOSTTYPE_CLYDE) && (state.game.global_dot_counter == 32)) {
//                     new_state = GHOSTSTATE_LEAVEHOUSE;
//                     // NOTE that global dot counter is deactivated if (and only if) Clyde
//                     // is in the house and the dot counter reaches 32
//                     state.game.global_dot_counter_active = false;
//                 }
//             }
//             else if (ghost.dot_counter == ghost.dot_limit) {
//                 // in the normal case, check the ghost's personal dot counter
//                 new_state = GHOSTSTATE_LEAVEHOUSE;
//             }
//             break;
//         case GHOSTSTATE_LEAVEHOUSE:
//             // ghosts immediately switch to scatter mode after leaving the ghost house
//             if (ghost.actor.pos.y == ANTEPORTAS_Y) {
//                 new_state = GHOSTSTATE_SCATTER;
//             }
//             break;
//         default:
//             // switch between frightened, scatter and chase mode
//             if (before(ghost.frightened, levelspec(state.game.round).fright_ticks)) {
//                 new_state = GHOSTSTATE_FRIGHTENED;
//             }
//             else {
//                 new_state = game_scatter_chase_phase();
//             }
//     }
//     // handle state transitions
//     if (new_state != ghost.state) {
//         switch (ghost.state) {
//             case GHOSTSTATE_LEAVEHOUSE:
//                 // after leaving the ghost house, head to the left
//                 ghost.next_dir = ghost.actor.dir = DIR_LEFT;
//                 break;
//             case GHOSTSTATE_ENTERHOUSE:
//                 // a ghost that was eaten is immune to frighten until Pacman eats enother pill
//                 disable(&ghost.frightened);
//                 break;
//             case GHOSTSTATE_FRIGHTENED:
//                 // don't reverse direction when leaving frightened state
//                 break;
//             case GHOSTSTATE_SCATTER:
//             case GHOSTSTATE_CHASE:
//                 // any transition from scatter and chase mode causes a reversal of direction
//                 ghost.next_dir = reverse_dir(ghost.actor.dir);
//                 break;
//             default:
//                 break;
//         }
//         ghost.state = new_state;
//     }
// }

// // update the ghost's target position, this is the other important function
// // of the ghost's AI
// static void game_update_ghost_target(ghost_t* ghost) {
//     assert(ghost);
//     Int2 pos = ghost.target_pos;
//     switch (ghost.state) {
//         case GHOSTSTATE_SCATTER:
//             // when in scatter mode, each ghost heads to its own scatter
//             // target position in the playfield corners
//             assert((ghost.type >= 0) && (ghost.type < NUM_GHOSTS));
//             pos = ghost_scatter_targets[ghost.type];
//             break;
//         case GHOSTSTATE_CHASE:
//             // when in chase mode, each ghost has its own particular
//             // chase behaviour (see the Pacman Dossier for details)
//             {
//                 const actor_t* pm = &state.game.pacman.actor;
//                 const Int2 pm_pos = pixel_to_tile_pos(pm.pos);
//                 const Int2 pm_dir = dir_to_vec(pm.dir);
//                 switch (ghost.type) {
//                     case GHOSTTYPE_BLINKY:
//                         // Blinky directly chases Pacman
//                         pos = pm_pos;
//                         break;
//                     case GHOSTTYPE_PINKY:
//                         // Pinky target is 4 tiles ahead of Pacman
//                         // FIXME: does not reproduce 'diagonal overflow'
//                         pos = add_i2(pm_pos, mul_i2(pm_dir, 4));
//                         break;
//                     case GHOSTTYPE_INKY:
//                         // Inky targets an extrapolated pos along a line two tiles
//                         // ahead of Pacman through Blinky
//                         {
//                             const Int2 blinky_pos = pixel_to_tile_pos(state.game.ghost[GHOSTTYPE_BLINKY].actor.pos);
//                             const Int2 p = add_i2(pm_pos, mul_i2(pm_dir, 2));
//                             const Int2 d = sub_i2(p, blinky_pos);
//                             pos = add_i2(blinky_pos, mul_i2(d, 2));
//                         }
//                         break;
//                     case GHOSTTYPE_CLYDE:
//                         // if Clyde is far away from Pacman, he chases Pacman,
//                         // but if close he moves towards the scatter target
//                         if (squared_distance_i2(pixel_to_tile_pos(ghost.actor.pos), pm_pos) > 64) {
//                             pos = pm_pos;
//                         }
//                         else {
//                             pos = ghost_scatter_targets[GHOSTTYPE_CLYDE];
//                         }
//                         break;
//                     default:
//                         break;
//                 }
//             }
//             break;
//         case GHOSTSTATE_FRIGHTENED:
//             // in frightened state just select a random target position
//             // this has the effect that ghosts in frightened state
//             // move in a random direction at each intersection
//             pos = i2(xorshift32() % DISPLAY_TILES_X, xorshift32() % DISPLAY_TILES_Y);
//             break;
//         case GHOSTSTATE_EYES:
//             // move towards the ghost house door
//             pos = i2(13, 14);
//             break;
//         default:
//             break;
//     }
//     ghost.target_pos = pos;
// }

// // compute the next ghost direction, return true if resulting movement
// // should always happen regardless of current ghost position or blocking
// // tiles (this special case is used for movement inside the ghost house)
// static bool game_update_ghost_dir(ghost_t* ghost) {
//     assert(ghost);
//     // inside ghost-house, just move up and down
//     if (ghost.state == GHOSTSTATE_HOUSE) {
//         if (ghost.actor.pos.y <= 17*TILE_HEIGHT) {
//             ghost.next_dir = DIR_DOWN;
//         }
//         else if (ghost.actor.pos.y >= 18*TILE_HEIGHT) {
//             ghost.next_dir = DIR_UP;
//         }
//         ghost.actor.dir = ghost.next_dir;
//         // force movement
//         return true;
//     }
//     // navigate the ghost out of the ghost house
//     else if (ghost.state == GHOSTSTATE_LEAVEHOUSE) {
//         const Int2 pos = ghost.actor.pos;
//         if (pos.x == ANTEPORTAS_X) {
//             if (pos.y > ANTEPORTAS_Y) {
//                 ghost.next_dir = DIR_UP;
//             }
//         }
//         else {
//             const int16_t mid_y = 17*TILE_HEIGHT + TILE_HEIGHT/2;
//             if (pos.y > mid_y) {
//                 ghost.next_dir = DIR_UP;
//             }
//             else if (pos.y < mid_y) {
//                 ghost.next_dir = DIR_DOWN;
//             }
//             else {
//                 ghost.next_dir = (pos.x > ANTEPORTAS_X) ? DIR_LEFT:DIR_RIGHT;
//             }
//         }
//         ghost.actor.dir = ghost.next_dir;
//         return true;
//     }
//     // navigate towards the ghost house target pos
//     else if (ghost.state == GHOSTSTATE_ENTERHOUSE) {
//         const Int2 pos = ghost.actor.pos;
//         const Int2 tile_pos = pixel_to_tile_pos(pos);
//         const Int2 tgt_pos = ghost_house_target_pos[ghost.type];
//         if (tile_pos.y == 14) {
//             if (pos.x != ANTEPORTAS_X) {
//                 ghost.next_dir = (pos.x < ANTEPORTAS_X) ? DIR_RIGHT:DIR_LEFT;
//             }
//             else {
//                 ghost.next_dir = DIR_DOWN;
//             }
//         }
//         else if (pos.y == tgt_pos.y) {
//             ghost.next_dir = (pos.x < tgt_pos.x) ? DIR_RIGHT:DIR_LEFT;
//         }
//         ghost.actor.dir = ghost.next_dir;
//         return true;
//     }
//     // scatter/chase/frightened: just head towards the current target point
//     else {
//         // only compute new direction when currently at midpoint of tile
//         const Int2 dist_to_mid = dist_to_tile_mid(ghost.actor.pos);
//         if ((dist_to_mid.x == 0) && (dist_to_mid.y == 0)) {
//             // new direction is the previously computed next-direction
//             ghost.actor.dir = ghost.next_dir;

//             // compute new next-direction
//             const Int2 dir_vec = dir_to_vec(ghost.actor.dir);
//             const Int2 lookahead_pos = add_i2(pixel_to_tile_pos(ghost.actor.pos), dir_vec);

//             // try each direction and take the one that moves closest to the target
//             const Dir dirs[NUM_DIRS] = { DIR_UP, DIR_LEFT, DIR_DOWN, DIR_RIGHT };
//             int min_dist = 100000;
//             int dist = 0;
//             for (int i = 0; i < NUM_DIRS; i++) {
//                 const Dir dir = dirs[i];
//                 // if ghost is in one of the two 'red zones', forbid upward movement
//                 // (see Pacman Dossier "Areas To Exploit")
//                 if (is_redzone(lookahead_pos) && (dir == DIR_UP) && (ghost.state != GHOSTSTATE_EYES)) {
//                     continue;
//                 }
//                 const Dir revdir = reverse_dir(dir);
//                 const Int2 test_pos = clamped_tile_pos(add_i2(lookahead_pos, dir_to_vec(dir)));
//                 if ((revdir != ghost.actor.dir) && !is_blocking_tile(test_pos)) {
//                     if ((dist = squared_distance_i2(test_pos, ghost.target_pos)) < min_dist) {
//                         min_dist = dist;
//                         ghost.next_dir = dir;
//                     }
//                 }
//             }
//         }
//         return false;
//     }
// }

// /* Update the dot counters used to decide whether ghosts must leave the house.

//     This is called each time Pacman eats a dot.

//     Each ghost has a dot limit which is reset at the start of a round. Each time
//     Pacman eats a dot, the highest priority ghost in the ghost house counts
//     down its dot counter.

//     When the ghost's dot counter reaches zero the ghost leaves the house
//     and the next highest-priority dot counter starts counting.

//     If a life is lost, the personal dot counters are deactivated and instead
//     a global dot counter is used.

//     If pacman doesn't eat dots for a while, the next ghost is forced out of the
//     house using a timer.
// */
// static void game_update_ghosthouse_dot_counters() {
//     // if the new round was started because Pacman lost a life, use the global
//     // dot counter (this mode will be deactivated again after all ghosts left the
//     // house)
//     if (state.game.global_dot_counter_active) {
//         state.game.global_dot_counter++;
//     }
//     else {
//         // otherwise each ghost has his own personal dot counter to decide
//         // when to leave the ghost house
//         for (int i = 0; i < NUM_GHOSTS; i++) {
//             if (state.game.ghost[i].dot_counter < state.game.ghost[i].dot_limit) {
//                 state.game.ghost[i].dot_counter++;
//                 break;
//             }
//         }
//     }
// }

// // called when a dot or pill has been eaten, checks if a round has been won
// // (all dots and pills eaten), whether to show the bonus fruit, and finally
// // plays the dot-eaten sound effect
// static void game_update_dots_eaten() {
//     state.game.num_dots_eaten++;
//     if (state.game.num_dots_eaten == NUM_DOTS) {
//         // all dots eaten, round won
//         start(&state.game.round_won);
//         snd_clear();
//     }
//     else if ((state.game.num_dots_eaten == 70) || (state.game.num_dots_eaten == 170)) {
//         // at 70 and 170 dots, show the bonus fruit
//         start(&state.game.fruit_active);
//     }

//     // play alternating crunch sound effect when a dot has been eaten
//     if (state.game.num_dots_eaten & 1) {
//         snd_start(2, &snd_eatdot1);
//     }
//     else {
//         snd_start(2, &snd_eatdot2);
//     }
// }

// // the central Pacman and ghost behaviour function, called once per game tick
// static void game_update_actors() {
//     // Pacman "AI"
//     if (game_pacman_should_move()) {
//         // move Pacman with cornering allowed
//         actor_t* actor = &state.game.pacman.actor;
//         const Dir wanted_dir = input_dir(actor.dir);
//         const bool allow_cornering = true;
//         // look ahead to check if the wanted direction is blocked
//         if (can_move(actor.pos, wanted_dir, allow_cornering)) {
//             actor.dir = wanted_dir;
//         }
//         // move into the selected direction
//         if (can_move(actor.pos, actor.dir, allow_cornering)) {
//             actor.pos = move(actor.pos, actor.dir, allow_cornering);
//             actor.anim_tick++;
//         }
//         // eat dot or energizer pill?
//         const Int2 tile_pos = pixel_to_tile_pos(actor.pos);
//         if (is_dot(tile_pos)) {
//             vid_tile(tile_pos, TILE_SPACE);
//             state.game.score += 1;
//             start(&state.game.dot_eaten);
//             start(&state.game.force_leave_house);
//             game_update_dots_eaten();
//             game_update_ghosthouse_dot_counters();
//         }
//         if (is_pill(tile_pos)) {
//             vid_tile(tile_pos, TILE_SPACE);
//             state.game.score += 5;
//             game_update_dots_eaten();
//             start(&state.game.pill_eaten);
//             state.game.num_ghosts_eaten = 0;
//             for (int i = 0; i < NUM_GHOSTS; i++) {
//                 start(&state.game.ghost[i].frightened);
//             }
//             snd_start(1, &snd_frightened);
//         }
//         // check if Pacman eats the bonus fruit
//         if (state.game.active_fruit != FRUIT_NONE) {
//             const Int2 test_pos = pixel_to_tile_pos(add_i2(actor.pos, i2(TILE_WIDTH/2, 0)));
//             if (equal_i2(test_pos, i2(14, 20))) {
//                 start(&state.game.fruit_eaten);
//                 uint score = levelspec(state.game.round).bonus_score;
//                 state.game.score += score;
//                 vid_fruit_score(state.game.active_fruit);
//                 state.game.active_fruit = FRUIT_NONE;
//                 snd_start(2, &snd_eatfruit);
//             }
//         }
//         // check if Pacman collides with any ghost
//         for (int i = 0; i < NUM_GHOSTS; i++) {
//             ghost_t* ghost = &state.game.ghost[i];
//             const Int2 ghost_tile_pos = pixel_to_tile_pos(ghost.actor.pos);
//             if (equal_i2(tile_pos, ghost_tile_pos)) {
//                 if (ghost.state == GHOSTSTATE_FRIGHTENED) {
//                     // Pacman eats a frightened ghost
//                     ghost.state = GHOSTSTATE_EYES;
//                     start(&ghost.eaten);
//                     start(&state.game.ghost_eaten);
//                     state.game.num_ghosts_eaten++;
//                     // increase score by 20, 40, 80, 160
//                     state.game.score += 10 * (1<<state.game.num_ghosts_eaten);
//                     state.game.freeze |= FREEZETYPE_EAT_GHOST;
//                     snd_start(2, &snd_eatghost);
//                 }
//                 else if ((ghost.state == GHOSTSTATE_CHASE) || (ghost.state == GHOSTSTATE_SCATTER)) {
//                     // otherwise, ghost eats Pacman, Pacman loses a life
//                     #if !DBG_GODMODE
//                     snd_clear();
//                     start(&state.game.pacman_eaten);
//                     state.game.freeze |= FREEZETYPE_DEAD;
//                     // if Pacman has any lives left start a new round, otherwise start the game-over sequence
//                     if (state.game.num_lives > 0) {
//                         start_after(&state.game.ready_started, PACMAN_EATEN_TICKS+PACMAN_DEATH_TICKS);
//                     }
//                     else {
//                         start_after(&state.game.game_over, PACMAN_EATEN_TICKS+PACMAN_DEATH_TICKS);
//                     }
//                     #endif
//                 }
//             }
//         }
//     }

//     // Ghost "AIs"
//     for (int ghost_index = 0; ghost_index < NUM_GHOSTS; ghost_index++) {
//         ghost_t* ghost = &state.game.ghost[ghost_index];
//         // handle ghost-state transitions
//         game_update_ghost_state(ghost);
//         // update the ghost's target position
//         game_update_ghost_target(ghost);
//         // finally, move the ghost towards the current target position
//         const int num_move_ticks = game_ghost_speed(ghost);
//         for (int i = 0; i < num_move_ticks; i++) {
//             bool force_move = game_update_ghost_dir(ghost);
//             actor_t* actor = &ghost.actor;
//             const bool allow_cornering = false;
//             if (force_move || can_move(actor.pos, actor.dir, allow_cornering)) {
//                 actor.pos = move(actor.pos, actor.dir, allow_cornering);
//                 actor.anim_tick++;
//             }
//         }
//     }
// }

// // the central game tick function, called at 60 Hz
// static void game_tick() {
//     // debug: skip prelude
//     #if DBG_SKIP_PRELUDE
//         const int prelude_ticks_per_sec = 1;
//     #else
//         const int prelude_ticks_per_sec = 60;
//     #endif

//     // initialize game state once
//     if (now(state.game.started)) {
//         start(&state.gfx.fadein);
//         start_after(&state.game.ready_started, 2*prelude_ticks_per_sec);
//         snd_start(0, &snd_prelude);
//         game_init();
//     }
//     // initialize new round (each time Pacman looses a life), make actors visible, remove "PLAYER ONE", start a new life
//     if (now(state.game.ready_started)) {
//         game_round_init();
//         // after 2 seconds start the interactive game loop
//         start_after(&state.game.round_started, 2*60+10);
//     }
//     if (now(state.game.round_started)) {
//         state.game.freeze &= ~FREEZETYPE_READY;
//         // clear the 'READY!' message
//         vid_color_text(i2(11,20), 0x10, "      ");
//         snd_start(1, &snd_weeooh);
//     }

//     // activate/deactivate bonus fruit
//     if (now(state.game.fruit_active)) {
//         state.game.active_fruit = levelspec(state.game.round).bonus_fruit;
//     }
//     else if (after_once(state.game.fruit_active, FRUITACTIVE_TICKS)) {
//         state.game.active_fruit = FRUIT_NONE;
//     }

//     // stop frightened sound and start weeooh sound
//     if (after_once(state.game.pill_eaten, levelspec(state.game.round).fright_ticks)) {
//         snd_start(1, &snd_weeooh);
//     }

//     // if game is frozen because Pacman ate a ghost, unfreeze after a while
//     if (state.game.freeze & FREEZETYPE_EAT_GHOST) {
//         if (after_once(state.game.ghost_eaten, GHOST_EATEN_FREEZE_TICKS)) {
//             state.game.freeze &= ~FREEZETYPE_EAT_GHOST;
//         }
//     }

//     // play pacman-death sound
//     if (after_once(state.game.pacman_eaten, PACMAN_EATEN_TICKS)) {
//         snd_start(2, &snd_dead);
//     }

//     // the actually important part: update Pacman and ghosts, update dynamic
//     // background tiles, and update the sprite images
//     if (!state.game.freeze) {
//         game_update_actors();
//     }
//     game_update_tiles();
//     game_update_sprites();

//     // update hiscore
//     if (state.game.score > state.game.hiscore) {
//         state.game.hiscore = state.game.score;
//     }

//     // check for end-round condition
//     if (now(state.game.round_won)) {
//         state.game.freeze |= FREEZETYPE_WON;
//         start_after(&state.game.ready_started, ROUNDWON_TICKS);
//     }
//     if (now(state.game.game_over)) {
//         // display game over string
//         vid_color_text(i2(9,20), 0x01, "GAME  OVER");
//         input_disable();
//         start_after(&state.gfx.fadeout, GAMEOVER_TICKS);
//         start_after(&state.intro.started, GAMEOVER_TICKS+FADE_TICKS);
//     }

//     #if DBG_ESCAPE
//         if (state.input.esc) {
//             input_disable();
//             start(&state.gfx.fadeout);
//             start_after(&state.intro.started, FADE_TICKS);
//         }
//     #endif

//     #if DBG_MARKERS
//         // visualize current ghost targets
//         for (int i = 0; i < NUM_GHOSTS; i++) {
//             const ghost_t* ghost = &state.game.ghost[i];
//             ubyte tile = 'X';
//             switch (ghost.state) {
//                 case GHOSTSTATE_NONE:       tile = 'N'; break;
//                 case GHOSTSTATE_CHASE:      tile = 'C'; break;
//                 case GHOSTSTATE_SCATTER:    tile = 'S'; break;
//                 case GHOSTSTATE_FRIGHTENED: tile = 'F'; break;
//                 case GHOSTSTATE_EYES:       tile = 'E'; break;
//                 case GHOSTSTATE_HOUSE:      tile = 'H'; break;
//                 case GHOSTSTATE_LEAVEHOUSE: tile = 'L'; break;
//                 case GHOSTSTATE_ENTERHOUSE: tile = 'E'; break;
//             }
//             dbg_marker(i, state.game.ghost[i].target_pos, tile, COLOR_BLINKY+2*i);
//         }
//     #endif
// }

// /*== INTRO GAMESTATE CODE ====================================================*/

// static void intro_tick() {

//     // on intro-state enter, enable input and draw any initial text
//     if (now(state.intro.started)) {
//         snd_clear();
//         spr_clear();
//         start(&state.gfx.fadein);
//         input_enable();
//         vid_clear(TILE_SPACE, COLOR_DEFAULT);
//         vid_text(i2(3,0),  "1UP   HIGH SCORE   2UP");
//         vid_color_score(i2(6,1), COLOR_DEFAULT, 0);
//         if (state.game.hiscore > 0) {
//             vid_color_score(i2(16,1), COLOR_DEFAULT, state.game.hiscore);
//         }
//         vid_text(i2(7,5),  "CHARACTER / NICKNAME");
//         vid_text(i2(3,35), "CREDIT  0");
//     }

//     // draw the animated 'ghost image.. name.. nickname' lines
//     uint delay = 30;
//     const char* names[] = { "-SHADOW", "-SPEEDY", "-BASHFUL", "-POKEY" };
//     const char* nicknames[] = { "BLINKY", "PINKY", "INKY", "CLYDE" };
//     for (int i = 0; i < 4; i++) {
//         const ubyte color = 2*i + 1;
//         const ubyte y = 3*i + 6;
//         // 2*3 ghost image created from tiles (no sprite!)
//         delay += 30;
//         if (after_once(state.intro.started, delay)) {
//             vid_color_tile(i2(4,y+0), color, TILE_GHOST+0); vid_color_tile(i2(5,y+0), color, TILE_GHOST+1);
//             vid_color_tile(i2(4,y+1), color, TILE_GHOST+2); vid_color_tile(i2(5,y+1), color, TILE_GHOST+3);
//             vid_color_tile(i2(4,y+2), color, TILE_GHOST+4); vid_color_tile(i2(5,y+2), color, TILE_GHOST+5);
//         }
//         // after 1 second, the name of the ghost
//         delay += 60;
//         if (after_once(state.intro.started, delay)) {
//             vid_color_text(i2(7,y+1), color, names[i]);
//         }
//         // after 0.5 seconds, the nickname of the ghost
//         delay += 30;
//         if (after_once(state.intro.started, delay)) {
//             vid_color_text(i2(17,y+1), color, nicknames[i]);
//         }
//     }

//     // . 10 PTS
//     // O 50 PTS
//     delay += 60;
//     if (after_once(state.intro.started, delay)) {
//         vid_color_tile(i2(10,24), COLOR_DOT, TILE_DOT);
//         vid_text(i2(12,24), "10 \x5D\x5E\x5F");
//         vid_color_tile(i2(10,26), COLOR_DOT, TILE_PILL);
//         vid_text(i2(12,26), "50 \x5D\x5E\x5F");
//     }

//     // blinking "press any key" text
//     delay += 60;
//     if (after(state.intro.started, delay)) {
//         if (since(state.intro.started) & 0x20) {
//             vid_color_text(i2(3,31), 3, "                       ");
//         }
//         else {
//             vid_color_text(i2(3,31), 3, "PRESS ANY KEY TO START!");
//         }
//     }

//     // FIXME: animated chase sequence

//     // if a key is pressed, advance to game state
//     if (state.input.anykey) {
//         input_disable();
//         start(&state.gfx.fadeout);
//         start_after(&state.game.started, FADE_TICKS);
//     }
// }

// /*== GFX SUBSYSTEM ===========================================================*/

// /* create all sokol-gfx resources */
// static void gfx_create_resources() {
//     // pass action for clearing the background to black
//     state.gfx.pass_action = (sg_pass_action) {
//         .colors[0] = { .load_action = SG_LOADACTION_CLEAR, .clear_value = { 0.0f, 0.0f, 0.0f, 1.0f } }
//     };

//     // create a dynamic vertex buffer for the tile and sprite quads
//     state.gfx.offscreen.vbuf = sg_make_buffer(&(sg_buffer_desc){
//         .type = SG_BUFFERTYPE_VERTEXBUFFER,
//         .usage = SG_USAGE_STREAM,
//         .size = sizeof(state.gfx.vertices),
//     });

//     // create a simple quad vertex buffer for rendering the offscreen render target to the display
//     float quad_verts[]= { 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f };
//     state.gfx.display.quad_vbuf = sg_make_buffer(&(sg_buffer_desc){
//         .data = SG_RANGE(quad_verts)
//     });

//     // shader sources for all platforms (FIXME: should we use precompiled shader blobs instead?)
//     const char* offscreen_vs_src = 0;
//     const char* offscreen_fs_src = 0;
//     const char* display_vs_src = 0;
//     const char* display_fs_src = 0;
//     switch (sg_query_backend()) {
//         case SG_BACKEND_METAL_MACOS:
//             offscreen_vs_src =
//                 "#include <metal_stdlib>\n"
//                 "using namespace metal;\n"
//                 "struct vs_in {\n"
//                 "  float4 pos [[attribute(0)]];\n"
//                 "  float2 uv [[attribute(1)]];\n"
//                 "  float4 data [[attribute(2)]];\n"
//                 "};\n"
//                 "struct vs_out {\n"
//                 "  float4 pos [[position]];\n"
//                 "  float2 uv;\n"
//                 "  float4 data;\n"
//                 "};\n"
//                 "vertex vs_out _main(vs_in in [[stage_in]]) {\n"
//                 "  vs_out out;\n"
//                 "  out.pos = float4((in.pos.xy - 0.5) * float2(2.0, -2.0), 0.5, 1.0);\n"
//                 "  out.uv  = in.uv;"
//                 "  out.data = in.data;\n"
//                 "  return out;\n"
//                 "}\n";
//             offscreen_fs_src =
//                 "#include <metal_stdlib>\n"
//                 "using namespace metal;\n"
//                 "struct ps_in {\n"
//                 "  float2 uv;\n"
//                 "  float4 data;\n"
//                 "};\n"
//                 "fragment float4 _main(ps_in in [[stage_in]],\n"
//                 "                      texture2d<float> tile_tex [[texture(0)]],\n"
//                 "                      texture2d<float> pal_tex [[texture(1)]],\n"
//                 "                      sampler tile_smp [[sampler(0)]],\n"
//                 "                      sampler pal_smp [[sampler(1)]])\n"
//                 "{\n"
//                 "  float color_code = in.data.x;\n" // (0..31) / 255
//                 "  float tile_color = tile_tex.sample(tile_smp, in.uv).x;\n" // (0..3) / 255
//                 "  float2 pal_uv = float2(color_code * 4 + tile_color, 0);\n"
//                 "  float4 color = pal_tex.sample(pal_smp, pal_uv) * float4(1, 1, 1, in.data.y);\n"
//                 "  return color;\n"
//                 "}\n";
//             display_vs_src =
//                 "#include <metal_stdlib>\n"
//                 "using namespace metal;\n"
//                 "struct vs_in {\n"
//                 "  float4 pos [[attribute(0)]];\n"
//                 "};\n"
//                 "struct vs_out {\n"
//                 "  float4 pos [[position]];\n"
//                 "  float2 uv;\n"
//                 "};\n"
//                 "vertex vs_out _main(vs_in in[[stage_in]]) {\n"
//                 "  vs_out out;\n"
//                 "  out.pos = float4((in.pos.xy - 0.5) * float2(2.0, -2.0), 0.0, 1.0);\n"
//                 "  out.uv = in.pos.xy;\n"
//                 "  return out;\n"
//                 "}\n";
//             display_fs_src =
//                 "#include <metal_stdlib>\n"
//                 "using namespace metal;\n"
//                 "struct ps_in {\n"
//                 "  float2 uv;\n"
//                 "};\n"
//                 "fragment float4 _main(ps_in in [[stage_in]],\n"
//                 "                      texture2d<float> tex [[texture(0)]],\n"
//                 "                      sampler smp [[sampler(0)]])\n"
//                 "{\n"
//                 "  return tex.sample(smp, in.uv);\n"
//                 "}\n";
//             break;
//         case SG_BACKEND_D3D11:
//             offscreen_vs_src =
//                 "struct vs_in {\n"
//                 "  float4 pos: POSITION;\n"
//                 "  float2 uv: TEXCOORD0;\n"
//                 "  float4 data: TEXCOORD1;\n"
//                 "};\n"
//                 "struct vs_out {\n"
//                 "  float2 uv: UV;\n"
//                 "  float4 data: DATA;\n"
//                 "  float4 pos: SV_Position;\n"
//                 "};\n"
//                 "vs_out main(vs_in inp) {\n"
//                 "  vs_out outp;"
//                 "  outp.pos = float4(inp.pos.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);\n"
//                 "  outp.uv  = inp.uv;"
//                 "  outp.data = inp.data;\n"
//                 "  return outp;\n"
//                 "}\n";
//             offscreen_fs_src =
//                 "Texture2D<float4> tile_tex: register(t0);\n"
//                 "Texture2D<float4> pal_tex: register(t1);\n"
//                 "sampler tile_smp: register(s0);\n"
//                 "sampler pal_smp: register(s1);\n"
//                 "float4 main(float2 uv: UV, float4 data: DATA): SV_Target0 {\n"
//                 "  float color_code = data.x;\n"
//                 "  float tile_color = tile_tex.Sample(tile_smp, uv).x;\n"
//                 "  float2 pal_uv = float2(color_code * 4 + tile_color, 0);\n"
//                 "  float4 color = pal_tex.Sample(pal_smp, pal_uv) * float4(1, 1, 1, data.y);\n"
//                 "  return color;\n"
//                 "}\n";
//             display_vs_src =
//                 "struct vs_out {\n"
//                 "  float2 uv: UV;\n"
//                 "  float4 pos: SV_Position;\n"
//                 "};\n"
//                 "vs_out main(float4 pos: POSITION) {\n"
//                 "  vs_out outp;\n"
//                 "  outp.pos = float4((pos.xy - 0.5) * float2(2.0, -2.0), 0.0, 1.0);\n"
//                 "  outp.uv = pos.xy;\n"
//                 "  return outp;\n"
//                 "}\n";
//             display_fs_src =
//                 "Texture2D<float4> tex: register(t0);\n"
//                 "sampler smp: register(s0);\n"
//                 "float4 main(float2 uv: UV): SV_Target0 {\n"
//                 "  return tex.Sample(smp, uv);\n"
//                 "}\n";
//             break;
//         case SG_BACKEND_GLCORE:
//             offscreen_vs_src =
//                 "#version 410\n"
//                 "layout(location=0) in vec4 pos;\n"
//                 "layout(location=1) in vec2 uv_in;\n"
//                 "layout(location=2) in vec4 data_in;\n"
//                 "out vec2 uv;\n"
//                 "out vec4 data;\n"
//                 "void main() {\n"
//                 "  gl_Position = vec4((pos.xy - 0.5) * vec2(2.0, -2.0), 0.5, 1.0);\n"
//                 "  uv  = uv_in;"
//                 "  data = data_in;\n"
//                 "}\n";
//             offscreen_fs_src =
//                 "#version 410\n"
//                 "uniform sampler2D tile_tex;\n"
//                 "uniform sampler2D pal_tex;\n"
//                 "in vec2 uv;\n"
//                 "in vec4 data;\n"
//                 "out vec4 frag_color;\n"
//                 "void main() {\n"
//                 "  float color_code = data.x;\n"
//                 "  float tile_color = texture(tile_tex, uv).x;\n"
//                 "  vec2 pal_uv = vec2(color_code * 4 + tile_color, 0);\n"
//                 "  frag_color = texture(pal_tex, pal_uv) * vec4(1, 1, 1, data.y);\n"
//                 "}\n";
//             display_vs_src =
//                 "#version 410\n"
//                 "layout(location=0) in vec4 pos;\n"
//                 "out vec2 uv;\n"
//                 "void main() {\n"
//                 "  gl_Position = vec4((pos.xy - 0.5) * 2.0, 0.0, 1.0);\n"
//                 "  uv = pos.xy;\n"
//                 "}\n";
//             display_fs_src =
//                 "#version 410\n"
//                 "uniform sampler2D tex;\n"
//                 "in vec2 uv;\n"
//                 "out vec4 frag_color;\n"
//                 "void main() {\n"
//                 "  frag_color = texture(tex, uv);\n"
//                 "}\n";
//                 break;
//         case SG_BACKEND_GLES3:
//             offscreen_vs_src =
//                 "attribute vec4 pos;\n"
//                 "attribute vec2 uv_in;\n"
//                 "attribute vec4 data_in;\n"
//                 "varying vec2 uv;\n"
//                 "varying vec4 data;\n"
//                 "void main() {\n"
//                 "  gl_Position = vec4((pos.xy - 0.5) * vec2(2.0, -2.0), 0.5, 1.0);\n"
//                 "  uv  = uv_in;"
//                 "  data = data_in;\n"
//                 "}\n";
//             offscreen_fs_src =
//                 "precision mediump float;\n"
//                 "uniform sampler2D tile_tex;\n"
//                 "uniform sampler2D pal_tex;\n"
//                 "varying vec2 uv;\n"
//                 "varying vec4 data;\n"
//                 "void main() {\n"
//                 "  float color_code = data.x;\n"
//                 "  float tile_color = texture2D(tile_tex, uv).x;\n"
//                 "  vec2 pal_uv = vec2(color_code * 4.0 + tile_color, 0.0);\n"
//                 "  gl_FragColor = texture2D(pal_tex, pal_uv) * vec4(1.0, 1.0, 1.0, data.y);\n"
//                 "}\n";
//             display_vs_src =
//                 "attribute vec4 pos;\n"
//                 "varying vec2 uv;\n"
//                 "void main() {\n"
//                 "  gl_Position = vec4((pos.xy - 0.5) * 2.0, 0.0, 1.0);\n"
//                 "  uv = pos.xy;\n"
//                 "}\n";
//             display_fs_src =
//                 "precision mediump float;\n"
//                 "uniform sampler2D tex;\n"
//                 "varying vec2 uv;\n"
//                 "void main() {\n"
//                 "  gl_FragColor = texture2D(tex, uv);\n"
//                 "}\n";
//                 break;
//         default:
//             assert(false);
//     }

//     // create pipeline and shader object for rendering into offscreen render target
//     state.gfx.offscreen.pip = sg_make_pipeline(&(sg_pipeline_desc){
//         .shader = sg_make_shader(&(sg_shader_desc){
//            .attrs = {
//                 [0] = { .name="pos", .sem_name="POSITION" },
//                 [1] = { .name="uv_in", .sem_name="TEXCOORD", .sem_index=0 },
//                 [2] = { .name="data_in", .sem_name="TEXCOORD", .sem_index=1 },
//             },
//             .vs.source = offscreen_vs_src,
//             .fs = {
//                 .images = {
//                     [0] = { .used = true },
//                     [1] = { .used = true },
//                 },
//                 .samplers = {
//                     [0] = { .used = true },
//                     [1] = { .used = true },
//                 },
//                 .image_sampler_pairs = {
//                     [0] = { .used = true, .image_slot = 0, .sampler_slot = 0, .glsl_name = "tile_tex" },
//                     [1] = { .used = true, .image_slot = 1, .sampler_slot = 1, .glsl_name = "pal_tex" },
//                 },
//                 .source = offscreen_fs_src
//             }
//         }),
//         .layout = {
//             .attrs = {
//                 [0].format = SG_VERTEXFORMAT_FLOAT2,
//                 [1].format = SG_VERTEXFORMAT_FLOAT2,
//                 [2].format = SG_VERTEXFORMAT_UBYTE4N,
//             }
//         },
//         .depth.pixel_format = SG_PIXELFORMAT_NONE,
//         .colors[0] = {
//             .pixel_format = SG_PIXELFORMAT_RGBA8,
//             .blend = {
//                 .enabled = true,
//                 .src_factor_rgb = SG_BLENDFACTOR_SRC_ALPHA,
//                 .dst_factor_rgb = SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
//             }
//         }
//     });

//     // create pipeline and shader for rendering into display
//     state.gfx.display.pip = sg_make_pipeline(&(sg_pipeline_desc){
//         .shader = sg_make_shader(&(sg_shader_desc){
//             .attrs[0] = { .name="pos", .sem_name="POSITION" },
//             .vs.source = display_vs_src,
//             .fs = {
//                 .images[0].used = true,
//                 .samplers[0].used = true,
//                 .image_sampler_pairs[0] = { .used = true, .image_slot = 0, .sampler_slot = 0, .glsl_name = "tex" },
//                 .source = display_fs_src
//             }
//         }),
//         .layout.attrs[0].format = SG_VERTEXFORMAT_FLOAT2,
//         .primitive_type = SG_PRIMITIVETYPE_TRIANGLE_STRIP
//     });

//     // create a render target image with a fixed upscale ratio
//     state.gfx.offscreen.render_target = sg_make_image(&(sg_image_desc){
//         .render_target = true,
//         .width = DISPLAY_PIXELS_X * 2,
//         .height = DISPLAY_PIXELS_Y * 2,
//         .pixel_format = SG_PIXELFORMAT_RGBA8,
//     });

//     // create an sampler to render the offscreen render target with linear upscale filtering
//     state.gfx.display.sampler = sg_make_sampler(&(sg_sampler_desc){
//         .min_filter = SG_FILTER_LINEAR,
//         .mag_filter = SG_FILTER_LINEAR,
//         .wrap_u = SG_WRAP_CLAMP_TO_EDGE,
//         .wrap_v = SG_WRAP_CLAMP_TO_EDGE,
//     });

//     // pass object for rendering into the offscreen render target
//     state.gfx.offscreen.attachments = sg_make_attachments(&(sg_attachments_desc){
//         .colors[0].image = state.gfx.offscreen.render_target
//     });

//     // create the 'tile-ROM-texture'
//     state.gfx.offscreen.tile_img = sg_make_image(&(sg_image_desc){
//         .width  = TILE_TEXTURE_WIDTH,
//         .height = TILE_TEXTURE_HEIGHT,
//         .pixel_format = SG_PIXELFORMAT_R8,
//         .data.subimage[0][0] = SG_RANGE(state.gfx.tile_pixels)
//     });

//     // create the palette texture
//     state.gfx.offscreen.palette_img = sg_make_image(&(sg_image_desc){
//         .width = 256,
//         .height = 1,
//         .pixel_format = SG_PIXELFORMAT_RGBA8,
//         .data.subimage[0][0] = SG_RANGE(state.gfx.color_palette)
//     });

//     // create a sampler with nearest filtering for the offscreen pass
//     state.gfx.offscreen.sampler = sg_make_sampler(&(sg_sampler_desc){
//         .min_filter = SG_FILTER_NEAREST,
//         .mag_filter = SG_FILTER_NEAREST,
//         .wrap_u = SG_WRAP_CLAMP_TO_EDGE,
//         .wrap_v = SG_WRAP_CLAMP_TO_EDGE,
//     });
// }

// /*
//     8x4 tile decoder (taken from: https://github.com/floooh/chips/blob/master/systems/namco.h)

//     This decodes 2-bit-per-pixel tile data from Pacman ROM dumps into
//     8-bit-per-pixel texture data (without doing the RGB palette lookup,
//     this happens during rendering in the pixel shader).

//     The Pacman ROM tile layout isn't exactly strightforward, both 8x8 tiles
//     and 16x16 sprites are built from 8x4 pixel blocks layed out linearly
//     in memory, and to add to the confusion, since Pacman is an arcade machine
//     with the display 90 degree rotated, all the ROM tile data is counter-rotated.

//     Tile decoding only happens once at startup from ROM dumps into a texture.
// */
// static inline void gfx_decode_tile_8x4(
//     uint tex_x,
//     uint tex_y,
//     const ubyte* tile_base,
//     uint tile_stride,
//     uint tile_offset,
//     ubyte tile_code)
// {
//     for (uint tx = 0; tx < TILE_WIDTH; tx++) {
//         uint ti = tile_code * tile_stride + tile_offset + (7 - tx);
//         for (uint ty = 0; ty < (TILE_HEIGHT/2); ty++) {
//             ubyte p_hi = (tile_base[ti] >> (7 - ty)) & 1;
//             ubyte p_lo = (tile_base[ti] >> (3 - ty)) & 1;
//             ubyte p = (p_hi << 1) | p_lo;
//             state.gfx.tile_pixels[tex_y + ty][tex_x + tx] = p;
//         }
//     }
// }

// // decode an 8x8 tile into the tile texture's upper half
// static inline void gfx_decode_tile(ubyte tile_code) {
//     uint x = tile_code * TILE_WIDTH;
//     uint y0 = 0;
//     uint y1 = y0 + (TILE_HEIGHT / 2);
//     gfx_decode_tile_8x4(x, y0, rom_tiles, 16, 8, tile_code);
//     gfx_decode_tile_8x4(x, y1, rom_tiles, 16, 0, tile_code);
// }

// // decode a 16x16 sprite into the tile texture's lower half
// static inline void gfx_decode_sprite(ubyte sprite_code) {
//     uint x0 = sprite_code * SPRITE_WIDTH;
//     uint x1 = x0 + TILE_WIDTH;
//     uint y0 = TILE_HEIGHT;
//     uint y1 = y0 + (TILE_HEIGHT / 2);
//     uint y2 = y1 + (TILE_HEIGHT / 2);
//     uint y3 = y2 + (TILE_HEIGHT / 2);
//     gfx_decode_tile_8x4(x0, y0, rom_sprites, 64, 40, sprite_code);
//     gfx_decode_tile_8x4(x1, y0, rom_sprites, 64,  8, sprite_code);
//     gfx_decode_tile_8x4(x0, y1, rom_sprites, 64, 48, sprite_code);
//     gfx_decode_tile_8x4(x1, y1, rom_sprites, 64, 16, sprite_code);
//     gfx_decode_tile_8x4(x0, y2, rom_sprites, 64, 56, sprite_code);
//     gfx_decode_tile_8x4(x1, y2, rom_sprites, 64, 24, sprite_code);
//     gfx_decode_tile_8x4(x0, y3, rom_sprites, 64, 32, sprite_code);
//     gfx_decode_tile_8x4(x1, y3, rom_sprites, 64,  0, sprite_code);
// }

// // decode the Pacman tile- and sprite-ROM-dumps into a 8bpp texture
// static void gfx_decode_tiles() {
//     for (uint tile_code = 0; tile_code < 256; tile_code++) {
//         gfx_decode_tile(tile_code);
//     }
//     for (uint sprite_code = 0; sprite_code < 64; sprite_code++) {
//         gfx_decode_sprite(sprite_code);
//     }
//     // write a special opaque 16x16 block which will be used for the fade-effect
//     for (uint y = TILE_HEIGHT; y < TILE_TEXTURE_HEIGHT; y++) {
//         for (uint x = 64*SPRITE_WIDTH; x < 65*SPRITE_WIDTH; x++) {
//             state.gfx.tile_pixels[y][x] = 1;
//         }
//     }
// }

// /* decode the Pacman color palette into a palette texture, on the original
//     hardware, color lookup happens in two steps, first through 256-entry
//     palette which indirects into a 32-entry hardware-color palette
//     (of which only 16 entries are used on the Pacman hardware)
// */
// static void gfx_decode_color_palette() {
//     uint hw_colors[32];
//     for (int i = 0; i < 32; i++) {
//        /*
//            Each color ROM entry describes an RGB color in 1 byte:

//            | 7| 6| 5| 4| 3| 2| 1| 0|
//            |B1|B0|G2|G1|G0|R2|R1|R0|

//            Intensities are: 0x97 + 0x47 + 0x21
//         */
//         ubyte rgb = rom_hwcolors[i];
//         ubyte r = ((rgb>>0)&1) * 0x21 + ((rgb>>1)&1) * 0x47 + ((rgb>>2)&1) * 0x97;
//         ubyte g = ((rgb>>3)&1) * 0x21 + ((rgb>>4)&1) * 0x47 + ((rgb>>5)&1) * 0x97;
//         ubyte b = ((rgb>>6)&1) * 0x47 + ((rgb>>7)&1) * 0x97;
//         hw_colors[i] = 0xFF000000 | (b<<16) | (g<<8) | r;
//     }
//     for (int i = 0; i < 256; i++) {
//         state.gfx.color_palette[i] = hw_colors[rom_palette[i] & 0xF];
//         // first color in each color block is transparent
//         if ((i & 3) == 0) {
//             state.gfx.color_palette[i] &= 0x00FFFFFF;
//         }
//     }
// }

// static void gfx_init() {
//     sg_setup(&(sg_desc){
//         // reduce pool allocation size to what's actually needed
//         .buffer_pool_size = 2,
//         .image_pool_size = 3,
//         .shader_pool_size = 2,
//         .pipeline_pool_size = 2,
//         .attachments_pool_size = 1,
//         .environment = sglue_environment(),
//         .logger.func = slog_func,
//     });
//     disable(&state.gfx.fadein);
//     disable(&state.gfx.fadeout);
//     state.gfx.fade = 0xFF;
//     spr_clear();
//     gfx_decode_tiles();
//     gfx_decode_color_palette();
//     gfx_create_resources();
// }

// static void gfx_shutdown() {
//     sg_shutdown();
// }

// static void gfx_add_vertex(float x, float y, float u, float v, ubyte color_code, ubyte opacity) {
//     assert(state.gfx.num_vertices < MAX_VERTICES);
//     vertex_t* vtx = &state.gfx.vertices[state.gfx.num_vertices++];
//     vtx.x = x;
//     vtx.y = y;
//     vtx.u = u;
//     vtx.v = v;
//     vtx.attr = (opacity<<8) | color_code;
// }

// static void gfx_add_tile_vertices(uint tx, uint ty, ubyte tile_code, ubyte color_code) {
//     assert((tx < DISPLAY_TILES_X) && (ty < DISPLAY_TILES_Y));
//     const float dx = 1.0f / DISPLAY_TILES_X;
//     const float dy = 1.0f / DISPLAY_TILES_Y;
//     const float du = (float)TILE_WIDTH / TILE_TEXTURE_WIDTH;
//     const float dv = (float)TILE_HEIGHT / TILE_TEXTURE_HEIGHT;

//     const float x0 = tx * dx;
//     const float x1 = x0 + dx;
//     const float y0 = ty * dy;
//     const float y1 = y0 + dy;
//     const float u0 = tile_code * du;
//     const float u1 = u0 + du;
//     const float v0 = 0.0f;
//     const float v1 = dv;
//     /*
//         x0,y0
//         +-----+
//         | *   |
//         |   * |
//         +-----+
//                 x1,y1
//     */
//     gfx_add_vertex(x0, y0, u0, v0, color_code, 0xFF);
//     gfx_add_vertex(x1, y0, u1, v0, color_code, 0xFF);
//     gfx_add_vertex(x1, y1, u1, v1, color_code, 0xFF);
//     gfx_add_vertex(x0, y0, u0, v0, color_code, 0xFF);
//     gfx_add_vertex(x1, y1, u1, v1, color_code, 0xFF);
//     gfx_add_vertex(x0, y1, u0, v1, color_code, 0xFF);
// }

// static void gfx_add_playfield_vertices() {
//     for (uint ty = 0; ty < DISPLAY_TILES_Y; ty++) {
//         for (uint tx = 0; tx < DISPLAY_TILES_X; tx++) {
//             const ubyte tile_code = state.gfx.video_ram[ty][tx];
//             const ubyte color_code = state.gfx.color_ram[ty][tx] & 0x1F;
//             gfx_add_tile_vertices(tx, ty, tile_code, color_code);
//         }
//     }
// }

// static void gfx_add_debugmarker_vertices() {
//     for (int i = 0; i < NUM_DEBUG_MARKERS; i++) {
//         const debugmarker_t* dbg = &state.gfx.debug_marker[i];
//         if (dbg.enabled) {
//             gfx_add_tile_vertices(dbg.tile_pos.x, dbg.tile_pos.y, dbg.tile, dbg.color);
//         }
//     }
// }

// static void gfx_add_sprite_vertices() {
//     const float dx = 1.0f / DISPLAY_PIXELS_X;
//     const float dy = 1.0f / DISPLAY_PIXELS_Y;
//     const float du = (float)SPRITE_WIDTH / TILE_TEXTURE_WIDTH;
//     const float dv = (float)SPRITE_HEIGHT / TILE_TEXTURE_HEIGHT;
//     for (int i = 0; i < NUM_SPRITES; i++) {
//         const Sprite* spr = &state.gfx.sprite[i];
//         if (spr.enabled) {
//             float x0, x1, y0, y1;
//             if (spr.flipx) {
//                 x1 = spr.pos.x * dx;
//                 x0 = x1 + dx * SPRITE_WIDTH;
//             }
//             else {
//                 x0 = spr.pos.x * dx;
//                 x1 = x0 + dx * SPRITE_WIDTH;
//             }
//             if (spr.flipy) {
//                 y1 = spr.pos.y * dy;
//                 y0 = y1 + dy * SPRITE_HEIGHT;
//             }
//             else {
//                 y0 = spr.pos.y * dy;
//                 y1 = y0 + dy * SPRITE_HEIGHT;
//             }
//             const float u0 = spr.tile * du;
//             const float u1 = u0 + du;
//             const float v0 = ((float)TILE_HEIGHT / TILE_TEXTURE_HEIGHT);
//             const float v1 = v0 + dv;
//             const ubyte color = spr.color;
//             gfx_add_vertex(x0, y0, u0, v0, color, 0xFF);
//             gfx_add_vertex(x1, y0, u1, v0, color, 0xFF);
//             gfx_add_vertex(x1, y1, u1, v1, color, 0xFF);
//             gfx_add_vertex(x0, y0, u0, v0, color, 0xFF);
//             gfx_add_vertex(x1, y1, u1, v1, color, 0xFF);
//             gfx_add_vertex(x0, y1, u0, v1, color, 0xFF);
//         }
//     }
// }

// static void gfx_add_fade_vertices() {
//     // sprite tile 64 is a special 16x16 opaque block
//     const float du = (float)SPRITE_WIDTH / TILE_TEXTURE_WIDTH;
//     const float dv = (float)SPRITE_HEIGHT / TILE_TEXTURE_HEIGHT;
//     const float u0 = 64 * du;
//     const float u1 = u0 + du;
//     const float v0 = (float)TILE_HEIGHT / TILE_TEXTURE_HEIGHT;
//     const float v1 = v0 + dv;

//     const ubyte fade = state.gfx.fade;
//     gfx_add_vertex(0.0f, 0.0f, u0, v0, 0, fade);
//     gfx_add_vertex(1.0f, 0.0f, u1, v0, 0, fade);
//     gfx_add_vertex(1.0f, 1.0f, u1, v1, 0, fade);
//     gfx_add_vertex(0.0f, 0.0f, u0, v0, 0, fade);
//     gfx_add_vertex(1.0f, 1.0f, u1, v1, 0, fade);
//     gfx_add_vertex(0.0f, 1.0f, u0, v1, 0, fade);
// }

// // adjust the viewport so that the aspect ratio is always correct
// static void gfx_adjust_viewport(int canvas_width, int canvas_height) {
//     const float canvas_aspect = (float)canvas_width / (float)canvas_height;
//     const float playfield_aspect = (float)DISPLAY_TILES_X / (float)DISPLAY_TILES_Y;
//     int vp_x, vp_y, vp_w, vp_h;
//     const int border = 10;
//     if (playfield_aspect < canvas_aspect) {
//         vp_y = border;
//         vp_h = canvas_height - 2*border;
//         vp_w = (int)(canvas_height * playfield_aspect - 2*border);
//         vp_x = (canvas_width - vp_w) / 2;
//     }
//     else {
//         vp_x = border;
//         vp_w = canvas_width - 2*border;
//         vp_h = (int)(canvas_width / playfield_aspect - 2*border);
//         vp_y = (canvas_height - vp_h) / 2;
//     }
//     sg_apply_viewport(vp_x, vp_y, vp_w, vp_h, true);
// }

// // handle fadein/fadeout
// static void gfx_fade() {
//     if (between(state.gfx.fadein, 0, FADE_TICKS)) {
//         float t = (float)since(state.gfx.fadein) / FADE_TICKS;
//         state.gfx.fade = (ubyte) (255.0f * (1.0f - t));
//     }
//     if (after_once(state.gfx.fadein, FADE_TICKS)) {
//         state.gfx.fade = 0;
//     }
//     if (between(state.gfx.fadeout, 0, FADE_TICKS)) {
//         float t = (float)since(state.gfx.fadeout) / FADE_TICKS;
//         state.gfx.fade = (ubyte) (255.0f * t);
//     }
//     if (after_once(state.gfx.fadeout, FADE_TICKS)) {
//         state.gfx.fade = 255;
//     }
// }

// static void gfx_draw() {
//     // handle fade in/out
//     gfx_fade();

//     // update the playfield and sprite vertex buffer
//     state.gfx.num_vertices = 0;
//     gfx_add_playfield_vertices();
//     gfx_add_sprite_vertices();
//     gfx_add_debugmarker_vertices();
//     if (state.gfx.fade > 0) {
//         gfx_add_fade_vertices();
//     }
//     assert(state.gfx.num_vertices <= MAX_VERTICES);
//     sg_update_buffer(state.gfx.offscreen.vbuf, &(sg_range){ .ptr=state.gfx.vertices, .size=state.gfx.num_vertices * sizeof(vertex_t) });

//     // render tiles and sprites into offscreen render target
//     sg_begin_pass(&(sg_pass){ .action = state.gfx.pass_action, .attachments = state.gfx.offscreen.attachments });
//     sg_apply_pipeline(state.gfx.offscreen.pip);
//     sg_apply_bindings(&(sg_bindings){
//         .vertex_buffers[0] = state.gfx.offscreen.vbuf,
//         .fs = {
//             .images = {
//                 [0] = state.gfx.offscreen.tile_img,
//                 [1] = state.gfx.offscreen.palette_img,
//             },
//             .samplers[0] = state.gfx.offscreen.sampler,
//             .samplers[1] = state.gfx.offscreen.sampler,
//         }
//     });
//     sg_draw(0, state.gfx.num_vertices, 1);
//     sg_end_pass();

//     // upscale-render the offscreen render target into the display framebuffer
//     const int canvas_width = sapp_width();
//     const int canvas_height = sapp_height();
//     sg_begin_pass(&(sg_pass){ .action = state.gfx.pass_action, .swapchain = sglue_swapchain() });
//     gfx_adjust_viewport(canvas_width, canvas_height);
//     sg_apply_pipeline(state.gfx.display.pip);
//     sg_apply_bindings(&(sg_bindings){
//         .vertex_buffers[0] = state.gfx.display.quad_vbuf,
//         .fs = {
//             .images[0] = state.gfx.offscreen.render_target,
//             .samplers[0] = state.gfx.display.sampler,
//         }
//     });
//     sg_draw(0, 4, 1);
//     sg_end_pass();
//     sg_commit();
// }

static State state;

// clear tile and color buffer
static void vid_clear(ubyte tile_code, ubyte color_code)
{
  memset(&state.gfx.video_ram, tile_code, state.gfx.video_ram.sizeof);
  memset(&state.gfx.color_ram, color_code, state.gfx.color_ram.sizeof);
}

// clear the playfield's rectangle in the color buffer
static void vid_color_playfield(ubyte color_code)
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
static bool valid_tile_pos(Int2 tile_pos)
{
  return ((tile_pos.x >= 0) && (tile_pos.x < DISPLAY_TILES_X) && (tile_pos.y >= 0) && (
      tile_pos.y < DISPLAY_TILES_Y));
}

// put a color into the color buffer
static void vid_color(Int2 tile_pos, ubyte color_code)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.color_ram[tile_pos.y][tile_pos.x] = color_code;
}

// put a tile into the tile buffer
static void vid_tile(Int2 tile_pos, ubyte tile_code)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.video_ram[tile_pos.y][tile_pos.x] = tile_code;
}

// put a colored tile into the tile and color buffers
static void vid_color_tile(Int2 tile_pos, ubyte color_code, ubyte tile_code)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.video_ram[tile_pos.y][tile_pos.x] = tile_code;
  state.gfx.color_ram[tile_pos.y][tile_pos.x] = color_code;
}

// translate ASCII char into "NAMCO char"
static char conv_char(char c)
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
static void vid_color_char(Int2 tile_pos, ubyte color_code, char chr)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.video_ram[tile_pos.y][tile_pos.x] = conv_char(chr);
  state.gfx.color_ram[tile_pos.y][tile_pos.x] = color_code;
}

// put char into tile buffer
static void vid_char(Int2 tile_pos, char chr)
{
  assert(valid_tile_pos(tile_pos));
  state.gfx.video_ram[tile_pos.y][tile_pos.x] = conv_char(chr);
}

// put colored text into the tile+color buffers
static void vid_color_text(Int2 tile_pos, ubyte color_code, const(char)* text)
{
  assert(valid_tile_pos(tile_pos));
  ubyte chr;
  // while ((chr = cast(ubyte) *text++)) {
  //     if (tile_pos.x < DISPLAY_TILES_X) {
  //         vid_color_char(tile_pos, color_code, chr);
  //         tile_pos.x++;
  //     }
  //     else {
  //         break;
  //     }
  // }
}

// put text into the tile buffer
static void vid_text(Int2 tile_pos, const(char)* text)
{
  assert(valid_tile_pos(tile_pos));
  ubyte chr;
  // while ((chr = cast(ubyte) *text++)) {
  //     if (tile_pos.x < DISPLAY_TILES_X) {
  //         vid_char(tile_pos, chr);
  //         tile_pos.x++;
  //     }
  //     else {
  //         break;
  //     }
  // }
}

/* print colored score number into tile+color buffers from right to left(!),
    scores are /10, the last printed number is always 0,
    a zero-score will print as '00' (this is the same as on
    the Pacman arcade machine)
*/
static void vid_color_score(Int2 tile_pos, ubyte color_code, uint score)
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
static void vid_draw_tile_quad(Int2 tile_pos, ubyte color_code, ubyte tile_code)
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
static void vid_fruit_score(Fruit fruit_type)
{
  assert((fruit_type >= 0) && (fruit_type < Fruit.NUM_FRUITS));
  ubyte color_code = (fruit_type == Fruit.FRUIT_NONE) ? COLOR_DOT : COLOR_FRUIT_SCORE;
  for (int i = 0; i < 4; i++)
  {
    vid_color_tile(i2(cast(short)(12 + i), cast(short) 20), color_code, fruit_score_tiles[fruit_type][i]);
  }
}

// clear input state and disable input
static void input_disable()
{
  memset(&state.input, 0, state.input.sizeof);
}

// enable input again
static void input_enable()
{
  state.input.enabled = true;
}

// get the current input as dir_t
static Dir input_dir(Dir default_dir)
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
static uint since(ref Trigger t)
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
static bool between(ref Trigger t, uint begin, uint end)
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
static bool after_once(ref Trigger t, uint ticks)
{
  return since(t) == ticks;
}

// check if a time trigger was triggered more than N ticks ago
static bool after(ref Trigger t, uint ticks)
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
static bool before(ref Trigger t, uint ticks)
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
static void spr_clear()
{
  memset(&state.gfx.sprite, 0, state.gfx.sprite.sizeof);
}

// get pointer to pacman sprite
static Sprite* spr_pacman()
{
  return &state.gfx.sprite[SpriteIndex.SPRITE_PACMAN];
}

// get pointer to ghost sprite
static Sprite* spr_ghost(GhostType type)
{
  assert((type >= 0) && (type < GhostType.NUM_GHOSTS));
  return &state.gfx.sprite[SpriteIndex.SPRITE_BLINKY + type];
}

// get pointer to fruit sprite
static Sprite* spr_fruit()
{
  return &state.gfx.sprite[SpriteIndex.SPRITE_FRUIT];
}

// set sprite to animated Pacman
static void spr_anim_pacman(Dir dir, uint tick)
{
  // animation frames for horizontal and vertical movement
  static const ubyte[4][2] tiles = [
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
static void spr_anim_pacman_death(uint tick)
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
static void spr_anim_ghost(GhostType ghost_type, Dir dir, uint tick)
{
  assert((dir >= 0) && (dir < Dir.NUM_DIRS));
  static const ubyte[2][4] tiles = [
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
// static void spr_anim_ghost_frightened(GhostType ghost_type, uint tick) {
//     static const ubyte[2] tiles = [ 28, 29 ];
//     uint phase = (tick / 4) & 1;
//     Sprite* spr = spr_ghost(ghost_type);
//     spr.tile = tiles[phase];
//     if (tick > cast(uint)(levelspec(state.game.round).fright_ticks - 60)) {
//         // towards end of frightening period, start blinking
//         spr.color = (tick & 0x10) ? COLOR_FRIGHTENED : COLOR_FRIGHTENED_BLINKING;
//     }
//     else {
//         spr.color = COLOR_FRIGHTENED;
//     }
//     spr.flipx = false;
//     spr.flipy = false;
// }

/* set sprite to ghost eyes, these are the normal ghost sprite
    images but with a different color code which makes
    only the eyes visible
*/
static void spr_anim_ghost_eyes(GhostType ghost_type, Dir dir)
{
  assert((dir >= 0) && (dir < Dir.NUM_DIRS));
  static const ubyte[Dir.NUM_DIRS] tiles = [32, 34, 36, 38];
  Sprite* spr = spr_ghost(ghost_type);
  spr.tile = tiles[dir];
  spr.color = COLOR_EYES;
  spr.flipx = false;
  spr.flipy = false;
}

// convert pixel position to tile position
static Int2 pixel_to_tile_pos(Int2 pix_pos)
{
  return i2(pix_pos.x / TILE_WIDTH, pix_pos.y / TILE_HEIGHT);
}

// clamp tile pos to valid playfield coords
static Int2 clamped_tile_pos(Int2 tile_pos)
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
static Int2 dir2Vec(Dir dir)
{
  assert((dir >= 0) && (dir < Dir.NUM_DIRS));
  static const Int2[Dir.NUM_DIRS] dir_map = [
    {+1, 0}, {0, +1}, {-1, 0}, {0, -1}
  ];
  return dir_map[dir];
}

// return the reverse direction
static Dir reverse_dir(Dir dir)
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
static ubyte tile_code_at(Int2 tile_pos)
{
  assert((tile_pos.x >= 0) && (tile_pos.x < DISPLAY_TILES_X));
  assert((tile_pos.y >= 0) && (tile_pos.y < DISPLAY_TILES_Y));
  return state.gfx.video_ram[tile_pos.y][tile_pos.x];
}

// check if a tile position contains a blocking tile (walls and ghost house door)
static bool is_blocking_tile(Int2 tile_pos)
{
  return tile_code_at(tile_pos) >= 0xC0;
}

// check if a tile position contains a dot tile
static bool is_dot(Int2 tile_pos)
{
  return tile_code_at(tile_pos) == TILE_DOT;
}

// check if a tile position contains a pill tile
static bool is_pill(Int2 tile_pos)
{
  return tile_code_at(tile_pos) == TILE_PILL;
}

// check if a tile position is in the teleport tunnel
static bool is_tunnel(Int2 tile_pos)
{
  return (tile_pos.y == 17) && ((tile_pos.x <= 5) || (tile_pos.x >= 22));
}

// check if a position is in the ghost's red zone, where upward movement is forbidden
// (see Pacman Dossier "Areas To Exploit")
static bool is_redzone(Int2 tile_pos)
{
  return ((tile_pos.x >= 11) && (tile_pos.x <= 16) && ((tile_pos.y == 14) || (tile_pos.y == 26)));
}

// test if movement from a pixel position in a wanted direction is possible,
// allow_cornering is Pacman's feature to take a diagonal shortcut around corners
// static bool can_move(Int2 pos, Dir wanted_dir, bool allow_cornering) {
//     const Int2 dir_vec = dir_to_vec(wanted_dir);
//     const Int2 dist_mid = dist_to_tile_mid(pos);

//     // distance to midpoint in move direction and perpendicular direction
//     int16_t move_dist_mid, perp_dist_mid;
//     if (dir_vec.y != 0) {
//         move_dist_mid = dist_mid.y;
//         perp_dist_mid = dist_mid.x;
//     }
//     else {
//         move_dist_mid = dist_mid.x;
//         perp_dist_mid = dist_mid.y;
//     }

//     // look one tile ahead in movement direction
//     const Int2 tile_pos = pixel_to_tile_pos(pos);
//     const Int2 check_pos = clamped_tile_pos(add_i2(tile_pos, dir_vec));
//     const bool is_blocked = is_blocking_tile(check_pos);
//     if ((!allow_cornering && (0 != perp_dist_mid)) || (is_blocked && (0 == move_dist_mid))) {
//         // way is blocked
//         return false;
//     }
//     else {
//         // way is free
//         return true;
//     }
// }

// compute a new pixel position along a direction (without blocking check!)
// static Int2 move(Int2 pos, Dir dir, bool allow_cornering) {
//     const Int2 dir_vec = dir_to_vec(dir);
//     pos = add_i2(pos, dir_vec);

//     // if cornering is allowed, drag the position towards the center-line
//     if (allow_cornering) {
//         const Int2 dist_mid = dist_to_tile_mid(pos);
//         if (dir_vec.x != 0) {
//             if (dist_mid.y < 0)      { pos.y--; }
//             else if (dist_mid.y > 0) { pos.y++; }
//         }
//         else if (dir_vec.y != 0) {
//             if (dist_mid.x < 0)      { pos.x--; }
//             else if (dist_mid.x > 0) { pos.x++; }
//         }
//     }

//     // wrap x-position around (only possible in the teleport-tunnel)
//     if (pos.x < 0) {
//         pos.x = DISPLAY_PIXELS_X - 1;
//     }
//     else if (pos.x >= DISPLAY_PIXELS_X) {
//         pos.x = 0;
//     }
//     return pos;
// }
