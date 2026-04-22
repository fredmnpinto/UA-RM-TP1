# Agent Guide - Peter Corke Robotics Toolbox

## Student Information

- **Student number**: 129466
- **Main function file**: rm1_129466.m
- **Output file naming convention**:
  - `loc_129466.txt` - Localization results
  - `DD_129466.txt` - Dead reckoning results
  - `TRI_129466.txt` - Triangulation results
  - `OMNI_129466.txt` - Omnidirectional robot results

## Documentation Location

**IMPORTANT**: The Peter Corke Robotics Toolbox documentation is located locally in:
- **File**: `peter_corke_toolbox.md` (in project root)
- **Size**: ~400KB (large file)

This file contains the complete reference documentation converted from the original PDF.

## How to Look Up Functions

### Method 1: Use the codesearch Tool (RECOMMENDED)
The most efficient way to find function definitions is to use the `codesearch` tool:
```
Search query: "FunctionName" or "function description"
```
This searches the local documentation and returns relevant code examples and usage.

### Method 2: Use grep for Headers
If you know the function name, search for its header:
```
Pattern: ^## FunctionName
```
Example: `^## Bicycle` finds the Bicycle class documentation at line ~1915.

### Method 3: Direct Read with Line Numbers
After finding the line number, read directly:
```
Read: peter_corke_toolbox.md from line X (reading ~100 lines)
```

## Key Functions for This Assignment

### Mobile Robot Kinematics
| Function | Line | Description |
|----------|------|-------------|
| Bicycle | 1915 | Bicycle/unicycle kinematic model |
| Bicycle.f | 1972 | Forward motion model |
| Bicycle.deriv | 1960 | Derivative for EKF |
| Bicycle.Fx | 1997 | Jacobian wrt state |
| Bicycle.Fv | 1985 | Jacobian wrt noise |

### Transformations & Rotations
| Function | Line | Description |
|----------|------|-------------|
| angvec2r | 5644 | Angle-axis to rotation matrix |
| eul2tr | 5920 | Euler angles to transform |
| tr2eul | 12248 | Transform to Euler angles |
| Twist | 13096 | Twist class for 2D/3D |
| Twist.se | 13338 | SE(2) element |

### Path Planning (if needed)
| Function | Line | Description |
|----------|------|-------------|
| Astar | 1138 | A* path planning |
| Dstar | 2373 | D* dynamic path planning |
| Bug2 | 2057 | Bug2 path planning |

## Usage Pattern

When you need to use a RTB function:

1. **First**: Use `codesearch` tool with query like "Bicycle kinematic model MATLAB"
2. **Read**: The returned context for usage examples
3. **Implement**: Based on the documented syntax

## Example Lookup

```matlab
% To find Bicycle class usage:
% 1. codesearch("Bicycle class kinematic model")
% 2. Read relevant sections
% 3. Use as documented:
bicycle = Bicycle(V, L);  % max linear velocity, wheelbase
```

## Notes

- The documentation is in Markdown format
- Headers are formatted as `## FunctionName.ClassName` for class methods
- Each function has usage examples in the documentation
- Take notes with a grain of salt - this is converted documentation