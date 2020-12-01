(
s.waitForBoot {
	// an mdapiano synthdef that I modified to take an amplitude argument
	// so that the further you are from (0,0), the quieter it gets
	// I aso turned up the decay so that when you're at the edges of the screen,
	// all that's left is decay
	SynthDef(\mdapiano, {arg out=0, freq=440, gate=1, vel=25, amp, dec=1.5;
		var son = MdaPiano.ar(freq, gate, vel, decay: dec, release: dec, stereo: 0, sustain: 1, mul: amp);
		DetectSilence.ar(son, 0.01, doneAction:2);
		Out.ar(out, son * 0.1);
	}).add;

	b = [\train, \bar, \traffic, \playground, \street, \gale, \rain, \forest, \stream, \wind].collect{|val| Buffer.read(s,(val++".wav").resolveRelative) };

	// set the starting position to (0,0)
	~xPos = ~xPrev = 0;
	~yPos = ~yPrev = 0;

	// you can increase or decrease ~stepSize to move faster or slower
	~stepSize = 2;
	// you can increase or decrease ~speed to increase or decrease the speed of playback
	~speed = 0.25;

	~s1 = Scale.dorian.degrees;
	~s2 = Scale.lydian.degrees;
	~s3 = Scale.phrygian.degrees;
	~s4 = Scale.mixolydian.degrees;

	// each biome is represented by a rising and falling scale
	~b1 = ~s1 ++ ~s1.keep(6).reverse.drop(-1);
	~b2 = ~s2 ++ ~s2.keep(6).reverse.drop(-1);
	~b3 = ~s3 ++ ~s3.keep(6).reverse.drop(-1);
	~b4 = ~s4 ++ ~s4.keep(6).reverse.drop(-1);

	// a convenience function which polls ~xPos and ~yPos to find the appropriate biome
	~bPrev = ~b1;
	~getBiome = {
		case
		{ (~xPos > 0) && (~yPos > 0) } {~bPrev = ~b1; ~b1}
		{ (~xPos > 0) && (~yPos < 0) } {~bPrev = ~b2; ~b2}
		{ (~xPos < 0) && (~yPos < 0) } {~bPrev = ~b3; ~b3}
		{ (~xPos < 0) && (~yPos > 0) } {~bPrev = ~b4; ~b4}
		{ (~xPos == 0) || (~yPos == 0) } {~bPrev};
	};

	// each ~speed duration, t polls ~xPos and ~yPos to calculate the new playback amplitude
	// then, play the next scale degree in appropriate scale for the biome and increment the degree
	~i = 0;
	t = Routine {
		inf.do {
			~amp = 100 - ((~xPos.pow(2) + ~yPos.pow(2)).sqrt / 354 * 100);
			Synth(\mdapiano, [\freq, (~getBiome.value.wrapAt(~i) + 60).midicps, \amp, ~amp]);
			~i = ~i + 1;
			~speed.wait;
		};
	};

	t.play;

	w = Window.new("", Rect(500, 500, 500, 500)).front;

	// create four panels with the same extent as the four biomes, each a random color
	~panels = {arg i;
		~corners = [[0, 0], [0, 250], [250, 0], [250, 250]];
		p = UserView(w, Rect(~corners[i][0], ~corners[i][1], 250, 250));
		p.background = Color.rand;
	} ! 4;

    // each time v is refreshed, draw a black line from the previous position to the current one
	// do not clear the lines that have already been drawn
	v = UserView(w, w.view.bounds).clearOnRefresh_(false);
	v.drawFunc = {
		Pen.strokeColor = Color.black;
		Pen.width = 2;
		Pen.line((~yPrev + 250)@(250 - ~xPrev), (~yPos + 250)@(250 - ~xPos));
		Pen.stroke;
	};

	~active = List[];
	v.keyDownAction = {arg view, char, modifiers, unicode, keycode;
		// with each key press, draw a new line representing the most recent move
		v.refresh;
		switch (keycode,
			65361, {~yPrev = ~yPos; ~yPos = ~yPos - ~stepSize}, // left
			65363, {~yPrev = ~yPos; ~yPos = ~yPos + ~stepSize}, // right
			65362, {~xPrev = ~xPos; ~xPos = ~xPos + ~stepSize}, // up
			65364, {~xPrev = ~xPos; ~xPos = ~xPos - ~stepSize}, // down
			// each number key plays an ambient sample and adds it to a list of active samples
			// when space is pressed, free all active samples and empty the list
			32,    {~active.do {arg buf; buf.free}; ~active = List[]}, // spacebar
			48,    {~active.add(b[0].play(true))}, // 0 ...
			49,    {~active.add(b[1].play(true))},
			50,    {~active.add(b[2].play(true))},
			51,    {~active.add(b[3].play(true))},
			52,    {~active.add(b[4].play(true))},
			53,    {~active.add(b[5].play(true))},
			54,    {~active.add(b[6].play(true))},
			55,    {~active.add(b[7].play(true))},
			56,    {~active.add(b[8].play(true))},
			57,    {~active.add(b[9].play(true))},
		);
	};

	w.onClose = ({t.stop; ~active.do {arg buf; buf.free}});
};
)
