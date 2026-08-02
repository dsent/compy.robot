--- Console front end for the robot. Open this project and
--- the prompt can drive the robot a line at a time:
---
---     require"robot_console"
---     m"40 -40 1"
---
--- Running this file only prints that reminder. The require
--- belongs at the prompt, because a module loaded by a
--- running program lands in the program's environment, out
--- of the prompt's reach.

print("robot console")
print('  require"robot_console"  -- load it, once per start')
print('  m"40 -40 1"             -- left, right, seconds')
