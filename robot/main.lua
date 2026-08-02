--- Starter program for the robot.
---
--- robot_move(left, right, seconds) turns the two wheels at
--- the given speeds and returns only when the move is over,
--- so the program reads top to bottom as a list of actions.
--- Speeds run from -100 to 100; a negative speed spins that
--- wheel backwards, so opposite speeds turn the robot in
--- place.
---
--- Edit the moves below and run again.

require("robot.move")

robot_move(-40, 40, 1)  -- spin one way
robot_move(40, -40, 1)  -- and back again
