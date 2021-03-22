Game Runner
-----------

The `run` game runner takes two programs to run to play against each
other. By default, the game uses no cards, so supply the `--cards`
option (followed by two cards) to play a game with cards.

GUI
---

Running `gui --interactive` runs a Santorini GUI in a mode that lets
you play the game. To play with cards, supply the `--cards` option
(followed by two cards). Note that the button label for the current
player changes from having an "X" to a checkmark when you can have
completed changes to the board that make a valid turn.

You can use `--player1` or `--player2` to specify a player program for
interactive mode. If you use the GUI to back up to an older game
state, the player program must be prepared to receive a board state
that is not consistent with the preceding board states.

The `gui` program can also read from stdin to display a sequence
boards. If that input is the output of `run`, then the GUI shows a
record of the game. The `gui` program accepts a JSON strings on input
as a description of the board to follow, so sending it input intended
for `check-turn` causes `gui` to show pairs of pre- and post-turn
boards with the pre-turn board description at the bottom left.

You can both send input to `gui` and supply the ` --interactive` flag,
which lets you see a game history but also go back and retry manually
from some game step. (See "Replay from Here" in the "Game" menu.) Be
sure to supply the same `--cards` arguments to `gui` as to `run`. If
you supply both input and `--player1` or `--player2`, then the player
program must be repared to receive a board without the initial
player-setup step.

The GUI draws a red box around a player that is at level 3, but note
that such a move isn't necessarily a win (because a token must
specifically move up a level to win).

Tournament
----------

The `tournament` program runs a tournament. Use `tournament--help` for
options. The default configuraton runs 10 rounds per configuration, a
30-second timeout, and no cards. If you supply more than 2 executables
or `--all-cards`, then you'll want fewer rounds --- probably just 1
round per configuration with `--all-cards`.

Demo Players
------------

The `play-random`, `play-search`, and `play-rate` players are a little
more flexible than the game protocol requires: they accept, at any
time, either a setup JSON array or a turn JSON board.

The `play-search` player just looks for a win or loss in the current
and next two turns. The `play-rate` player performs a more general
minimax search with a board-ranking heuristic.
