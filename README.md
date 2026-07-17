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
While Direct BLE (Option 3) is the most elegant solution, we have a very tight deadline (a few days). Therefore, we will only spend a limited amount of time experimenting with it before falling back to simpler methods if needed.

**The BLE Pairing Challenge:**
If we use a BLE connection (Options 2 or 3), we must carefully design the pairing process—both the technical implementation and the user experience (UX). Since there will be 6+ robot/computer pairs operating in the same classroom in close proximity, we need a robust way to ensure each student's netbook connects to their own robot and not someone else's.

## Microbit firmware choice 

If I'm not completely wrong, the the TPBot comes with various firmwares through
which the Microbit can drive it. 

TPBot microbit firmware options:

- TPBot microbit firmware is one of the unmodified ones
  - this can only work if it can be driven at least with USB
  - and in this case we need to make sure that from the compy we can speak
    that protocol, possibly by linking into the Compy IDE some library that
    talks this protocol
- TPBot microbit firmware is modified by us
  - in this case, we can design a wire protocol that implements the minimal
    functions that we need

At the moment I do not know enough to make a call between these.

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
