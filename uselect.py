#!/usr/bin/env python2.7

import curses;
import itertools;
import os;
import re;
import sys;

#------------------------------------------------------------------------------
class Console:
	def __init__(self):
		# Save the original stdin and stdout, and reopen them to /dev/tty,
		# so that curses will work.
		self.stdin = os.dup(0);
		self.ttyin = open('/dev/tty', 'r');
		os.dup2(self.ttyin.fileno(), 0);

		self.stdout = os.dup(1);
		self.ttyout = open('/dev/tty', 'w');
		os.dup2(self.ttyout.fileno(), 1);

	def __del__(self):
		# Restore the original stdin and stdout.
		os.dup2(self.stdin,  0);
		os.dup2(self.stdout, 1);

#------------------------------------------------------------------------------
class Line:

	def __init__(self, text, can_select):
		self.text = text;
		self.can_select = can_select;
		self.is_selected = 0;

#------------------------------------------------------------------------------
class Selector:

	def __init__(self, line_wanted, text_lines):
		self.x = 1;
		self.lines = map(lambda t: Line(t, line_wanted(t)), text_lines);

		line_count = len(self.lines);

		prev_selectable = None;
		for i, line in enumerate(self.lines):
			line.prev_selectable = prev_selectable;
			if line.can_select:
				prev_selectable = i;
		self.last_selectable = prev_selectable;

		next_selectable = None;
		for j, line in enumerate(reversed(self.lines)):
			line.next_selectable = next_selectable;
			if line.can_select:
				next_selectable = line_count - j - 1;
		self.first_selectable = next_selectable;

	def next_selectable(self, line, dirn):
		if dirn < 0:
			return self.lines[line].prev_selectable;
		else:
			return self.lines[line].next_selectable;

	def print_lines(self):
		for line in self.lines:
			if line.is_selected:
				sys.stdout.write(line.text);

#------------------------------------------------------------------------------
class UI:

	color_name = {
		'black':     [ curses.COLOR_BLACK,   0 ],
		'white':     [ curses.COLOR_WHITE,   0 ],
		'red':       [ curses.COLOR_RED,     0 ],
		'yellow':    [ curses.COLOR_YELLOW,  0 ],
		'green':     [ curses.COLOR_GREEN,   0 ],
		'cyan':      [ curses.COLOR_CYAN,    0 ],
		'blue':      [ curses.COLOR_BLUE,    0 ],
		'magenta':   [ curses.COLOR_MAGENTA, 0 ],

		'base02':    [ curses.COLOR_BLACK,   0 ],
		'base2':     [ curses.COLOR_WHITE,   0 ],
		'base03':    [ curses.COLOR_BLACK,   curses.A_BOLD ],
		'base01':    [ curses.COLOR_GREEN,   curses.A_BOLD ],
		'base00':    [ curses.COLOR_YELLOW,  curses.A_BOLD ],
		'base0':     [ curses.COLOR_BLUE,    curses.A_BOLD ],
		'base1':     [ curses.COLOR_CYAN,    curses.A_BOLD ],
		'base3':     [ curses.COLOR_WHITE,   curses.A_BOLD ],
		'orange':    [ curses.COLOR_RED,     curses.A_BOLD ],
		'violet':    [ curses.COLOR_MAGENTA, curses.A_BOLD ],

		'default':   [ 0, 0 ],
		'':          [ 0, 0 ],
		None:        [ 0, 0 ],
	};

	attr_name = {
		'blink':     curses.A_BLINK,
		'bold':      curses.A_BOLD,
		'dim':       curses.A_DIM,
		'reverse':   curses.A_REVERSE,
		'standout':  curses.A_STANDOUT,
		'underline': curses.A_UNDERLINE,
		'':		 	 0,
		None:		 0,
	};

	colors = {
		'cursor_selected': 'green,base02',
		'cursor_selectable': 'base1,base02',
		'cursor_unselectable': 'base1,base02',
		'nocursor_selected': 'green',
		'nocursor_selectable': 'base0',
		'nocursor_unselectable': 'base01',
	};

	def __init__(self, selector):
		self.selector = selector;

	def _init_curses(self, window):
		self.window = window;
		curses.cbreak();
		curses.noecho();
		curses.start_color();
		curses.use_default_colors();
		window.keypad(1);
		self._update_size();
		self._exit_requested = 0;
		self._next_color_pair = 1;
		self._color_table = {};
		for k,v in UI.colors.iteritems():
			self._color_table[k] = self._parse_color(v);

	# Is this necessary in the presence of curses.wrapper?
	def _deinit_curses(self):
		curses.nocbreak();
		curses.endwin();

	def run(self):
		console = Console();
		curses.wrapper(self._run);

	def _run(self, window):
		self._init_curses(window);
		self.cursor = self.selector.first_selectable;
		self.first_line = max(0, self.cursor - self.height + 2);

		need_redraw = 1;
		while not self._exit_requested:
			if need_redraw:
				self._draw();

			# Update
			need_redraw = self._update();

		# Teardown
		self._deinit_curses();

	def _draw(self):
		self._update_size();
		self.window.erase();

		line_count = min(self.height - 1, len(self.selector.lines) - self.first_line);
		for y in range(0, line_count):
			self._draw_line(y, self.first_line + y);

		self.window.refresh();

	def _draw_line(self, y, line_no):
		line = self.selector.lines[line_no];
		prefix = '  ';
		color = 'cursor_';
		if line_no != self.cursor:
			color = 'no' + color;
		if line.is_selected:
			color = color + 'selected';
			prefix = '# ';
		elif line.can_select:
			color = color + 'selectable';
			prefix = '. ';
		else:
			color = color + 'unselectable';
		self._set_color(color);
		self.window.addstr(y, 0, prefix + line.text);

	def _update(self):
		key = self.window.getch();
		line = self.selector.lines[self.cursor];

		if key == ord('\n'):
			# If there are no selected lines, select this one
			# (sounds wrong, but feels quite natural in practice)
			if next(itertools.ifilter(lambda line: line.is_selected, self.selector.lines), None) == None:
				line.is_selected = 1;
			self._exit_requested = 1;
		elif key == ord('q'):
			for line in self.selector.lines:
				line.is_selected = 0;
			self._exit_requested = 1;
		elif key == ord('k'):
			self._move_cursor(-1);
		elif key == ord('j'):
			self._move_cursor(+1);
		elif key == ord('g'):
			self._cursor_to_end(-1);
		elif key == ord('G'):
			self._cursor_to_end(+1);
		elif key == ord(' '):
			line.is_selected ^= line.can_select;
		else:
			return 0;

		if self.cursor < self.first_line:
			self.first_line = self.cursor;
		elif self.cursor >= self.first_line + self.height - 1:
			self.first_line = self.cursor - self.height + 2;

		return 1;

	def _set_cursor(self, new_cursor):
		if new_cursor != None:
			self.cursor = new_cursor;
		return new_cursor;

	def _move_cursor(self, dirn):
		new_cursor = self.selector.next_selectable(self.cursor, dirn);
		if self._set_cursor(new_cursor) == None:
			self._cursor_to_end(dirn);

	def _cursor_to_end(self, dirn):
		slr = self.selector;
		line_count = len(slr.lines);
		if dirn < 0:
			self._set_cursor(slr.first_selectable);
			self._first_line = 0;
		else:
			self._set_cursor(slr.last_selectable);
			self._first_line = max(0, line_count - self.height + 1);

	def _update_size(self):
		self.height, self.width = self.window.getmaxyx();

	def _parse_color(self, color):
		components = color.split(',');
		fg, bg, attr = (0, -1, 0);
		n = len(components);
		if (n >= 1):
			c = self.color_name[components[0]];
			fg    = c[0];
			attr |= c[1];
		if (n >= 2):
			c = self.color_name[components[1]];
			bg    = c[0];
			attr |= c[1];
		if (n >= 3):
			attr |= self.attr_name[components[2]];
		return self._make_color(fg, bg, attr);

	def _make_color(self, fg, bg, attr):
		pair = self._next_color_pair;
		self._next_color_pair += 1;
		curses.init_pair(pair, fg, bg);
		return attr | curses.color_pair(pair);

	def _set_color(self, name):
		self.window.attrset(self._color_table[name]);

#------------------------------------------------------------------------------
def make_wanted(pattern):
	regex = re.compile(pattern);
	return lambda line: regex.search(line) != None;

s = Selector(make_wanted('\.pm$'), sys.stdin.readlines());
u = UI(s);
u.run();
s.print_lines();
