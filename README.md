# Compy Robot - a temporary repo to give compy a Robot implementation

## Background

The real compy robot implementation is a nice design with a micro:bit firmware
implemented such that the C++ firmware that drives the TPBot is linked with a
Lua interpreter, and connecting the micro:bit with USB to a computer results
in the appearing serial port being a Lua REPL. That Lua REPL supports built-in
functions to actuate the various features of the TPBot.

A further idea was to drive the TPBot via Bluetooth Low Energy (BLE). Fearing
that it'll be hard to pair the Compy netbook programmatically with the micro:bit
with BLE, the idea was that the initial implementation will work so that the
compy is connected to a micro:bit via USB, that micro:bit is connected via BLE
to the micro:bit in the TPBot, and that drives the TPBot.

The project members reported that they ran into some instability, they suspect
the C++ micro:bit firmware of the TPBot to contain some kind of a bug that makes
BLE unusable if the audio of the micro:bit was used.

Higher level aspects, for example the Compy Lua application level interface was
not fully designed yet.

The orginal lesson plan in ../../compy/lesson-plans/lesson-plan_4-6/ contains
significant, load-bearing parts of the lessons building on assumed capability
of the TPBot robot that it can be driven to reproduce the robot running in the
Maze.

Additionally to all the above issues, the developers of the roboth API learned
that the TPBot cannot be driven with precision, and that likely the only way
to lead it on a grid is to utilize some kind of sensors which feed back current
position, possibly direction. This increases the complexity of designing a
solution that can be delivered in time and provides an API that students can
use to implement the lesson plan.

Moreover, a lesson series is already ongoing, they did 2 of the lessons so
far. The decision can be just to silently drop the robot from the lesson plan,
maybe replacing it with something else, or, and that's what we are aiming for,
to significantly rewrite the lesson plan, so that it requires less both from
the TPBot, and from the software that supports an API.

## Goal

The primary, short term goal of this project is to come up with some lesson
elements for the currently ongoing lessons which include moving TPBot robots,
and to implement the necessary software modules in time for it.

We deliver by deadline, and not a feature set. There's only one feature that
is a must: the kids must be able to play with a robot that moves, and must
be able to do so via calling some built-in functions from a compy-program.

## Physical setup

There are three potential ways to connect the Compy Netbook to the TPBot:

1. **Direct USB**:
   `Compy Netbook <---USB Cable---> Micro:bit (Plugged into TPBot)`
   - The simplest and most reliable method, but restricts the robot's movement due to the cable.
2. **USB Bridge to BLE**:
   `Compy Netbook <---USB Cable---> Micro:bit <--Bluetooth (BLE)--> Micro:bit (Plugged into TPBot)`
   - Uses an intermediate Micro:bit connected to the computer to wirelessly control the robot. 
3. **Direct BLE**:
   `Compy Netbook <--Bluetooth (BLE)--> Micro:bit (Plugged into TPBot)`
   - The ideal, fully wireless setup.

**Implementation Strategy:**
Decision: we start with Direct USB (Option 1) to have a working solution as
soon as possible, and look into better options later. The wire protocol is
designed to be transport-agnostic: from the Compy side, Options 1 and 2 are
indistinguishable (both present a serial port), so the BLE bridge (Option 2)
can be added later without changing anything on the Compy side. Direct BLE
(Option 3) remains the long-term ideal but is out of scope for this deadline.

For the Obstacle Course game a cable is tolerable: the course is short, and
while the cable slightly affects the trajectory, in a game about estimating
and tuning parameters that is just one more source of error, which is part
of the fun anyway.

**The BLE Pairing Challenge:**
If we use a BLE connection (Options 2 or 3), we must carefully design the pairing process—both the technical implementation and the user experience (UX). Since there will be 6+ robot/computer pairs operating in the same classroom in close proximity, we need a robust way to ensure each student's netbook connects to their own robot and not someone else's.

## Micro:bit Firmware Choice

The TPBot itself is simply a chassis with a motor controller; the actual "firmware" runs on the Micro:bit plugged into it. We have two main paths for what to flash onto that Micro:bit:

1. **Use an Existing/Stock Firmware**:
   - The Micro:bit runs a pre-existing environment (like standard MicroPython or a stock MakeCode setup).
   - **Requirement**: This only works if the firmware can receive motor commands over USB serial. We would need to build a library on the Compy Netbook side to translate our Lua commands into that specific protocol.
   
2. **Develop a Custom Firmware**:
   - We write and flash our own custom C++ or MicroPython firmware to the Micro:bit.
   - **Advantage**: We have complete control over the wire protocol. We can design a very simple, minimal protocol tailored exactly to the few functions we need (like `robot_move`), which keeps the Compy integration much easier.

**Decision**: we go with a custom MicroPython script (Option 2). It is faster
to develop than custom C++ (no toolchain needed) and simpler than
reverse-engineering the protocol of a stock firmware. The micro:bit becomes a
dumb executor: a small loop reads a command line from UART (e.g. `M 20 80 3400`),
drives the motors over I2C, and replies `OK`. A text-based line protocol can
also be debugged by hand from any serial terminal, which is valuable during a
lesson.

**Constraint**: Python stays strictly inside the micro:bit firmware. No Python
of any kind on the Compy side — the Compy side is Lua only, talking to the
robot over the serial protocol.

The Lua REPL of the original firmware design is not needed at this stage:
Lua already runs on the netbook, so the firmware only needs to execute motor
commands.

## Games

Given that the information is that only rudimentary control is possible with
the basic robot control APIs, we should give up the plan to implement the Maze
with the robot as part of this course. A different idea that I propose we go with
is an **Obstacle Course Challenge**:

1. **The Setup**: An "Adversary" (e.g. a teacher or another student) places a few obstacles in front of the robot to create a course.
2. **The Rules**: The Adversary specifies exactly how the robot must navigate the course (for example: "pass the first obstacle on the left, then the second on the right").
3. **The Challenge**: The "Player" must write a sequence of programmed commands to navigate the robot past the obstacles according to the Adversary's rules. Real-time remote control is not allowed; the entire path must be pre-programmed!

Because the robot's movement may be slightly imprecise, the player will need to experiment and estimate how long and how fast to rotate each wheel to achieve the perfect run. This turns the hardware limitations into a fun game of trial and error.

## Build-in Lua API

The API available for the Compy user initially is extremely simple. Something
along the lines of

robot_move(20, 80, 3.4)

meaning: rotate the left wheel with 20% of whatever is controllable of the TPBot
(speed? energy?), the right wheel with 80%, for 3.4 seconds.

Two semantic details, decided upfront:

1. **The call is blocking.** `robot_move` returns only after the movement has
   completed. This way a student's program reads top to bottom as a plain
   sequence of actions — no command queues, no callbacks, nothing to explain
   beyond "the robot does one line at a time".
2. **Negative speeds are allowed.** A negative value spins that wheel
   backwards, so e.g. `robot_move(-50, 50, 1)` turns the robot in place.
   This is cheaper than a separate turn function and extends the game
   naturally (reversing out of a dead end, pivoting between obstacles).
