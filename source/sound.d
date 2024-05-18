module sound;

import data;
import rom;
import game : state;
import saudio = sokol.audio;
import log = sokol.log;

static void snd_init()
{
	saudio.Desc desc = {logger: {func: &log.slog_func},};
	saudio.setup(desc);

	// compute sample duration in nanoseconds
	int samples_per_sec = saudio.sampleRate;
	state.audio.sample_duration_ns = 1000_000_000 / samples_per_sec;

	/* compute number of 96kHz ticks per sample tick (the Namco sound generator
        runs at 96kHz), times 1000 for increased precision
    */
	state.audio.voice_tick_period = 96_000_000 / samples_per_sec;
}

static void snd_shutdown()
{
	saudio.shutdown;
}

// the snd_Voiceick() function updates the Namco sound generator and must be called with 96 kHz
static void snd_Voiceick()
{
	for (int i = 0; i < NUM_VOICES; i++)
	{
		Voice* voice = &state.audio.voice[i];
		voice.counter += voice.frequency;
		/* lookup current 4-bit sample from the waveform number and the
            topmost 5 bits of the 20-bit sample counter
        */
		uint wave_index = ((voice.waveform << 5) | ((voice.counter >> 15) & 0x1F)) & 0xFF;
		int sample = ((cast(int)(rom_wavetable[wave_index] & 0xF)) - 8) * voice.volume;
		voice.sample_acc += cast(float) sample; // sample is (-8..+7 wavetable value) * 16 (volume)
		voice.sample_div += 128.0f;
	}
}

// the snd_sample_tick() function must be called with sample frequency (e.g. 44.1kHz)
static void snd_sample_tick()
{
	float sm = 0.0f;
	for (int i = 0; i < NUM_VOICES; i++)
	{
		Voice* voice = &state.audio.voice[i];
		if (voice.sample_div > 0.0f)
		{
			sm += voice.sample_acc / voice.sample_div;
			voice.sample_acc = voice.sample_div = 0.0f;
		}
	}
	state.audio.sample_buffer[state.audio.num_samples++] = sm * 0.333333f * AUDIO_VOLUME;
	if (state.audio.num_samples == NUM_SAMPLES)
	{
		saudio.push(&state.audio.sample_buffer[0], state.audio.num_samples);
		state.audio.num_samples = 0;
	}
}

// the sound subsystem's per-frame function
static void snd_frame(int frame_time_ns)
{
	// for each sample to generate...
	state.audio.sample_accum -= frame_time_ns;
	while (state.audio.sample_accum < 0)
	{
		state.audio.sample_accum += state.audio.sample_duration_ns;
		// tick the sound generator at 96 KHz
		state.audio.voice_tick_accum -= state.audio.voice_tick_period;
		while (state.audio.voice_tick_accum < 0)
		{
			state.audio.voice_tick_accum += 1000;
			snd_Voiceick();
		}
		// generate a new sample, and push out to sokol-audio when local sample buffer full
		snd_sample_tick();
	}
}

/* The sound system's 60 Hz tick function (called from game tick).
    Updates the sound 'hardware registers' for all active sound effects.
*/
static void snd_tick()
{
	// for each active sound effect...
	for (int sound_slot = 0; sound_slot < NUM_SOUNDS; sound_slot++)
	{
		Sound* snd = &state.audio.sound[sound_slot];
		if (snd.func)
		{
			// procedural sound effect
			snd.func(sound_slot);
		}
		else if (snd.flags & SoundFlag.SOUNDFLAG_ALL_VOICES)
		{
			// register-dump sound effect
			assert(snd.data);
			if (snd.cur_tick == snd.num_ticks)
			{
				snd_stop(sound_slot);
				continue;
			}

			// decode register dump values into voice 'registers'
			const(uint)* cur_ptr = &snd.data[snd.cur_tick * snd.stride];
			for (int i = 0; i < NUM_VOICES; i++)
			{
				if (snd.flags & (1 << i))
				{
					Voice* voice = &state.audio.voice[i];
					uint val = *cur_ptr++;
					// 20 bits frequency
					voice.frequency = val & ((1 << 20) - 1);
					// 3 bits waveform
					voice.waveform = (val >> 24) & 7;
					// 4 bits volume
					voice.volume = (val >> 28) & 0xF;
				}
			}
		}
		snd.cur_tick++;
	}
}

// clear all active sound effects and start outputting silence
static void snd_clear()
{
	import core.stdc.string : memset;

	memset(&state.audio.voice, 0, state.audio.voice.sizeof);
	memset(&state.audio.sound, 0, state.audio.sound.sizeof);
}

// start a sound effect
static void snd_start(int slot, const SoundDesc* desc)
{
  assert((slot >= 0) && (slot < NUM_SOUNDS));
  assert(desc);
  assert((desc.ptr && desc.size) || desc.func);

  Sound* snd = &state.audio.sound[slot];
  // *snd = cast(Sound) { 0 };
  int num_voices = 0;
  for (int i = 0; i < NUM_VOICES; i++)
  {
    if (desc.voice[i])
    {
      snd.flags |= (1 << i);
      num_voices++;
    }
  }
  if (desc.func)
  {
    // procedural sounds only need a callback function
    snd.func = desc.func;
  }
  else
  {
    assert(num_voices > 0);
    assert((desc.size % (num_voices * uint.sizeof)) == 0);
    snd.stride = num_voices;
    snd.num_ticks = desc.size / (snd.stride * uint.sizeof);
    snd.data = desc.ptr;
  }
}

// stop a sound effect
static void snd_stop(int slot)
{
  assert((slot >= 0) && (slot < NUM_SOUNDS));

  // silence the sound's output voices
  for (int i = 0; i < NUM_VOICES; i++)
  {
    if (state.audio.sound[slot].flags & (1 << i))
    {
      // state.audio.voice[i] = cast(Voice) { 0 };
    }
  }

  // clear the sound slot
  // state.audio.sound[slot] = cast(Sound) { 0 };
}

// procedural sound effects
static void snd_func_eatdot1(int slot)
{
  assert((slot >= 0) && (slot < NUM_SOUNDS));
  const Sound* snd = &state.audio.sound[slot];
  Voice* voice = &state.audio.voice[2];
  if (snd.cur_tick == 0)
  {
    voice.volume = 12;
    voice.waveform = 2;
    voice.frequency = 0x1500;
  }
  else if (snd.cur_tick == 5)
  {
    snd_stop(slot);
  }
  else
  {
    voice.frequency -= 0x0300;
  }
}

static void snd_func_eatdot2(int slot)
{
  assert((slot >= 0) && (slot < NUM_SOUNDS));
  const Sound* snd = &state.audio.sound[slot];
  Voice* voice = &state.audio.voice[2];
  if (snd.cur_tick == 0)
  {
    voice.volume = 12;
    voice.waveform = 2;
    voice.frequency = 0x0700;
  }
  else if (snd.cur_tick == 5)
  {
    snd_stop(slot);
  }
  else
  {
    voice.frequency += 0x300;
  }
}

static void snd_func_eatghost(int slot)
{
  assert((slot >= 0) && (slot < NUM_SOUNDS));
  const Sound* snd = &state.audio.sound[slot];
  Voice* voice = &state.audio.voice[2];
  if (snd.cur_tick == 0)
  {
    voice.volume = 12;
    voice.waveform = 5;
    voice.frequency = 0;
  }
  else if (snd.cur_tick == 32)
  {
    snd_stop(slot);
  }
  else
  {
    voice.frequency += 0x20;
  }
}

static void snd_func_eatfruit(int slot)
{
  assert((slot >= 0) && (slot < NUM_SOUNDS));
  const Sound* snd = &state.audio.sound[slot];
  Voice* voice = &state.audio.voice[2];
  if (snd.cur_tick == 0)
  {
    voice.volume = 15;
    voice.waveform = 6;
    voice.frequency = 0x1600;
  }
  else if (snd.cur_tick == 23)
  {
    snd_stop(slot);
  }
  else if (snd.cur_tick < 11)
  {
    voice.frequency -= 0x200;
  }
  else
  {
    voice.frequency += 0x0200;
  }
}

static void snd_func_weeooh(int slot)
{
  assert((slot >= 0) && (slot < NUM_SOUNDS));
  const Sound* snd = &state.audio.sound[slot];
  Voice* voice = &state.audio.voice[1];
  if (snd.cur_tick == 0)
  {
    voice.volume = 6;
    voice.waveform = 6;
    voice.frequency = 0x1000;
  }
  else if ((snd.cur_tick % 24) < 12)
  {
    voice.frequency += 0x0200;
  }
  else
  {
    voice.frequency -= 0x0200;
  }
}

static void snd_func_frightened(int slot)
{
  assert((slot >= 0) && (slot < NUM_SOUNDS));
  const Sound* snd = &state.audio.sound[slot];
  Voice* voice = &state.audio.voice[1];
  if (snd.cur_tick == 0)
  {
    voice.volume = 10;
    voice.waveform = 4;
    voice.frequency = 0x0180;
  }
  else if ((snd.cur_tick % 8) == 0)
  {
    voice.frequency = 0x0180;
  }
  else
  {
    voice.frequency += 0x180;
  }
}

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
__gshared const(uint)[490] snd_dump_prelude = [
	0xE20002E0, 0xF0001700,
	0xD20002E0, 0xF0001700,
	0xC20002E0, 0xF0001700,
	0xB20002E0, 0xF0001700,
	0xA20002E0, 0xF0000000,
	0x920002E0, 0xF0000000,
	0x820002E0, 0xF0000000,
	0x720002E0, 0xF0000000,
	0x620002E0, 0xF0002E00,
	0x520002E0, 0xF0002E00,
	0x420002E0, 0xF0002E00,
	0x320002E0, 0xF0002E00,
	0x220002E0, 0xF0000000,
	0x120002E0, 0xF0000000,
	0x020002E0, 0xF0000000,
	0xE2000000, 0xF0002280,
	0xD2000000, 0xF0002280,
	0xC2000000, 0xF0002280,
	0xB2000000, 0xF0002280,
	0xA2000000, 0xF0000000,
	0x92000000, 0xF0000000,
	0x82000000, 0xF0000000,
	0x72000000, 0xF0000000,
	0xE2000450, 0xF0001D00,
	0xD2000450, 0xF0001D00,
	0xC2000450, 0xF0001D00,
	0xB2000450, 0xF0001D00,
	0xA2000450, 0xF0000000,
	0x92000450, 0xF0000000,
	0x82000450, 0xF0000000,
	0x72000450, 0xF0000000,
	0xE20002E0, 0xF0002E00,
	0xD20002E0, 0xF0002E00,
	0xC20002E0, 0xF0002E00,
	0xB20002E0, 0xF0002E00,
	0xA20002E0, 0xF0002280,
	0x920002E0, 0xF0002280,
	0x820002E0, 0xF0002280,
	0x720002E0, 0xF0002280,
	0x620002E0, 0xF0000000,
	0x520002E0, 0xF0000000,
	0x420002E0, 0xF0000000,
	0x320002E0, 0xF0000000,
	0x220002E0, 0xF0000000,
	0x120002E0, 0xF0000000,
	0x020002E0, 0xF0000000,
	0xE2000000, 0xF0001D00,
	0xD2000000, 0xF0001D00,
	0xC2000000, 0xF0001D00,
	0xB2000000, 0xF0001D00,
	0xA2000000, 0xF0001D00,
	0x92000000, 0xF0001D00,
	0x82000000, 0xF0001D00,
	0x72000000, 0xF0001D00,
	0xE2000450, 0xF0000000,
	0xD2000450, 0xF0000000,
	0xC2000450, 0xF0000000,
	0xB2000450, 0xF0000000,
	0xA2000450, 0xF0000000,
	0x92000450, 0xF0000000,
	0x82000450, 0xF0000000,
	0x72000450, 0xF0000000,
	0xE2000308, 0xF0001840,
	0xD2000308, 0xF0001840,
	0xC2000308, 0xF0001840,
	0xB2000308, 0xF0001840,
	0xA2000308, 0xF0000000,
	0x92000308, 0xF0000000,
	0x82000308, 0xF0000000,
	0x72000308, 0xF0000000,
	0x62000308, 0xF00030C0,
	0x52000308, 0xF00030C0,
	0x42000308, 0xF00030C0,
	0x32000308, 0xF00030C0,
	0x22000308, 0xF0000000,
	0x12000308, 0xF0000000,
	0x02000308, 0xF0000000,
	0xE2000000, 0xF0002480,
	0xD2000000, 0xF0002480,
	0xC2000000, 0xF0002480,
	0xB2000000, 0xF0002480,
	0xA2000000, 0xF0000000,
	0x92000000, 0xF0000000,
	0x82000000, 0xF0000000,
	0x72000000, 0xF0000000,
	0xE2000490, 0xF0001EC0,
	0xD2000490, 0xF0001EC0,
	0xC2000490, 0xF0001EC0,
	0xB2000490, 0xF0001EC0,
	0xA2000490, 0xF0000000,
	0x92000490, 0xF0000000,
	0x82000490, 0xF0000000,
	0x72000490, 0xF0000000,
	0xE2000308, 0xF00030C0,
	0xD2000308, 0xF00030C0,
	0xC2000308, 0xF00030C0,
	0xB2000308, 0xF00030C0,
	0xA2000308, 0xF0002480,
	0x92000308, 0xF0002480,
	0x82000308, 0xF0002480,
	0x72000308, 0xF0002480,
	0x62000308, 0xF0000000,
	0x52000308, 0xF0000000,
	0x42000308, 0xF0000000,
	0x32000308, 0xF0000000,
	0x22000308, 0xF0000000,
	0x12000308, 0xF0000000,
	0x02000308, 0xF0000000,
	0xE2000000, 0xF0001EC0,
	0xD2000000, 0xF0001EC0,
	0xC2000000, 0xF0001EC0,
	0xB2000000, 0xF0001EC0,
	0xA2000000, 0xF0001EC0,
	0x92000000, 0xF0001EC0,
	0x82000000, 0xF0001EC0,
	0x72000000, 0xF0001EC0,
	0xE2000490, 0xF0000000,
	0xD2000490, 0xF0000000,
	0xC2000490, 0xF0000000,
	0xB2000490, 0xF0000000,
	0xA2000490, 0xF0000000,
	0x92000490, 0xF0000000,
	0x82000490, 0xF0000000,
	0x72000490, 0xF0000000,
	0xE20002E0, 0xF0001700,
	0xD20002E0, 0xF0001700,
	0xC20002E0, 0xF0001700,
	0xB20002E0, 0xF0001700,
	0xA20002E0, 0xF0000000,
	0x920002E0, 0xF0000000,
	0x820002E0, 0xF0000000,
	0x720002E0, 0xF0000000,
	0x620002E0, 0xF0002E00,
	0x520002E0, 0xF0002E00,
	0x420002E0, 0xF0002E00,
	0x320002E0, 0xF0002E00,
	0x220002E0, 0xF0000000,
	0x120002E0, 0xF0000000,
	0x020002E0, 0xF0000000,
	0xE2000000, 0xF0002280,
	0xD2000000, 0xF0002280,
	0xC2000000, 0xF0002280,
	0xB2000000, 0xF0002280,
	0xA2000000, 0xF0000000,
	0x92000000, 0xF0000000,
	0x82000000, 0xF0000000,
	0x72000000, 0xF0000000,
	0xE2000450, 0xF0001D00,
	0xD2000450, 0xF0001D00,
	0xC2000450, 0xF0001D00,
	0xB2000450, 0xF0001D00,
	0xA2000450, 0xF0000000,
	0x92000450, 0xF0000000,
	0x82000450, 0xF0000000,
	0x72000450, 0xF0000000,
	0xE20002E0, 0xF0002E00,
	0xD20002E0, 0xF0002E00,
	0xC20002E0, 0xF0002E00,
	0xB20002E0, 0xF0002E00,
	0xA20002E0, 0xF0002280,
	0x920002E0, 0xF0002280,
	0x820002E0, 0xF0002280,
	0x720002E0, 0xF0002280,
	0x620002E0, 0xF0000000,
	0x520002E0, 0xF0000000,
	0x420002E0, 0xF0000000,
	0x320002E0, 0xF0000000,
	0x220002E0, 0xF0000000,
	0x120002E0, 0xF0000000,
	0x020002E0, 0xF0000000,
	0xE2000000, 0xF0001D00,
	0xD2000000, 0xF0001D00,
	0xC2000000, 0xF0001D00,
	0xB2000000, 0xF0001D00,
	0xA2000000, 0xF0001D00,
	0x92000000, 0xF0001D00,
	0x82000000, 0xF0001D00,
	0x72000000, 0xF0001D00,
	0xE2000450, 0xF0000000,
	0xD2000450, 0xF0000000,
	0xC2000450, 0xF0000000,
	0xB2000450, 0xF0000000,
	0xA2000450, 0xF0000000,
	0x92000450, 0xF0000000,
	0x82000450, 0xF0000000,
	0x72000450, 0xF0000000,
	0xE2000450, 0xF0001B40,
	0xD2000450, 0xF0001B40,
	0xC2000450, 0xF0001B40,
	0xB2000450, 0xF0001B40,
	0xA2000450, 0xF0001D00,
	0x92000450, 0xF0001D00,
	0x82000450, 0xF0001D00,
	0x72000450, 0xF0001D00,
	0x62000450, 0xF0001EC0,
	0x52000450, 0xF0001EC0,
	0x42000450, 0xF0001EC0,
	0x32000450, 0xF0001EC0,
	0x22000450, 0xF0000000,
	0x12000450, 0xF0000000,
	0x02000450, 0xF0000000,
	0xE20004D0, 0xF0001EC0,
	0xD20004D0, 0xF0001EC0,
	0xC20004D0, 0xF0001EC0,
	0xB20004D0, 0xF0001EC0,
	0xA20004D0, 0xF0002080,
	0x920004D0, 0xF0002080,
	0x820004D0, 0xF0002080,
	0x720004D0, 0xF0002080,
	0x620004D0, 0xF0002280,
	0x520004D0, 0xF0002280,
	0x420004D0, 0xF0002280,
	0x320004D0, 0xF0002280,
	0x220004D0, 0xF0000000,
	0x120004D0, 0xF0000000,
	0x020004D0, 0xF0000000,
	0xE2000568, 0xF0002280,
	0xD2000568, 0xF0002280,
	0xC2000568, 0xF0002280,
	0xB2000568, 0xF0002280,
	0xA2000568, 0xF0002480,
	0x92000568, 0xF0002480,
	0x82000568, 0xF0002480,
	0x72000568, 0xF0002480,
	0x62000568, 0xF0002680,
	0x52000568, 0xF0002680,
	0x42000568, 0xF0002680,
	0x32000568, 0xF0002680,
	0x22000568, 0xF0000000,
	0x12000568, 0xF0000000,
	0x02000568, 0xF0000000,
	0xE20005C0, 0xF0002E00,
	0xD20005C0, 0xF0002E00,
	0xC20005C0, 0xF0002E00,
	0xB20005C0, 0xF0002E00,
	0xA20005C0, 0xF0002E00,
	0x920005C0, 0xF0002E00,
	0x820005C0, 0xF0002E00,
	0x720005C0, 0xF0002E00,
	0x620005C0, 0x00000E80,
	0x520005C0, 0x00000E80,
	0x420005C0, 0x00000E80,
	0x320005C0, 0x00000E80,
	0x220005C0, 0x00000E80,
	0x120005C0, 0x00000E80,
];

__gshared const(uint)[90] snd_dump_dead = [
	0xF1001F00,
	0xF1001E00,
	0xF1001D00,
	0xF1001C00,
	0xF1001B00,
	0xF1001C00,
	0xF1001D00,
	0xF1001E00,
	0xF1001F00,
	0xF1002000,
	0xF1002100,
	0xE1001D00,
	0xE1001C00,
	0xE1001B00,
	0xE1001A00,
	0xE1001900,
	0xE1001800,
	0xE1001900,
	0xE1001A00,
	0xE1001B00,
	0xE1001C00,
	0xE1001D00,
	0xE1001E00,
	0xD1001B00,
	0xD1001A00,
	0xD1001900,
	0xD1001800,
	0xD1001700,
	0xD1001600,
	0xD1001700,
	0xD1001800,
	0xD1001900,
	0xD1001A00,
	0xD1001B00,
	0xD1001C00,
	0xC1001900,
	0xC1001800,
	0xC1001700,
	0xC1001600,
	0xC1001500,
	0xC1001400,
	0xC1001500,
	0xC1001600,
	0xC1001700,
	0xC1001800,
	0xC1001900,
	0xC1001A00,
	0xB1001700,
	0xB1001600,
	0xB1001500,
	0xB1001400,
	0xB1001300,
	0xB1001200,
	0xB1001300,
	0xB1001400,
	0xB1001500,
	0xB1001600,
	0xB1001700,
	0xB1001800,
	0xA1001500,
	0xA1001400,
	0xA1001300,
	0xA1001200,
	0xA1001100,
	0xA1001000,
	0xA1001100,
	0xA1001200,
	0x80000800,
	0x80001000,
	0x80001800,
	0x80002000,
	0x80002800,
	0x80003000,
	0x80003800,
	0x80004000,
	0x80004800,
	0x80005000,
	0x80005800,
	0x00000000,
	0x80000800,
	0x80001000,
	0x80001800,
	0x80002000,
	0x80002800,
	0x80003000,
	0x80003800,
	0x80004000,
	0x80004800,
	0x80005000,
	0x80005800,
];
