```
Universidade de Aveiro
```
# Robótica Móvel

```
Assignment no. 1 - March/April 2026
```
## Robot Probabilistic Localization using Redundant Landmarks

```
Mestrado em Robótica e Sistemas Inteligentes
```
# 1 Main objective

Localization of a robot in environments with multiple landmarks along a path that starts at a reference
point and passes through all the intermediate landmarks (beacons) until stopping at the last one.

B (^2) B 1
B 3
B 4
robot
path
Figure 1:Illustration of a scenario where a robot follows a trajectory that passes through several landmarks and
performs localization with a redundant constellation of landmarks. The 4 landmarks in the figure are
merely illustrative: the solution to be developed must handle any number of landmarks greater than 2.
The landmarks (or beacons) have known positions, and it is assumed that the robot has a sensor that
allows it to identify and distinguish the beacons and measure their distance and orientation in relation to
its current position, but with an associated uncertainty. However, even if, in general, there is redundancy
of beacons (more than strictly necessary), there are situations in which one or more beacons may not be
detectable, in which case the necessary adaptations must be made to use only known information. It is
intended that the localization is the best possible and therefore it is recommended to use the maximum
amount of information available to do so, although it is possible to do localization using only part of the
total information at each moment.
While other tools are viable, the use of Extended Kalman Filters (EKF) is expected using appropriate
motion and observation models. The main result of the simulation should be the successive estimated
robot locations along the trajectory.

# 2 Description

Localization can be done deterministically using the classic approaches of triangulation and trilateration, or
with probabilistic models that take into account the kinematic model and the predicted movement of the
robot, as well as the observation model of the sensors. In either case, obviously, the readings of the range
and/or direction data measured by the sensors on board are necessary. To reduce localization errors due
to measurement uncertainty, probabilistic solutions such as Extended Kalman Filters are recommended
under certain conditions (such as the requirement of the Gaussian nature of the variables involved).
The aim is to have the best possible localization and, hence, the more beacons used in each obser-
vation, the more robust is the solution expected to be, since it takes advantage of the redundancy that
may exist at any time. In the exercises done in classes, examples were always made with only two visible
beacons (although they were not always the same). In this work, we intend to use as many beacons
as possible at each instant to strengthen the confidence of the localization, but there is a risk that one
or more beacons may fail to be detected! In that situation, the program has to deal appropriately with
this information, especially in the observation models and, more specifically, in the innovation calcula-
tion, either in the innovation covariance matrix or in the Kalman gain matrix, which both depend on the


Jacobian of the observation functionh(). This Jacobian of functionh()will have variable dimensions
depending on the number of measurements (beacons) used at each instant.

## 2.1 Generic equations for the Kalman Filter

In the following expressions, and adopting the ISO 80000-2 directives, vectors are represented by a bold
italic lower case letter (likeuk) and matrices are represented by a bold italic upper case letter (likePk).
Also, in general, predicted quantities are represented by a overlay bar (likeu ̄k+1) and updated estimated
quantities are represented with a overlay hat (likeuˆk+1).
Prediction with the process model:



```

```
```
x ̄k+1=f(ˆxk,uk,wk)
P ̄k+1=Jfx(ˆxk,uk,wk)PkJ⊺f
x(ˆxk,uk,wk) +
+Jfw(ˆxk,uk,wk)QkJ
⊺
fw(ˆxk,uk,wk)
```
### (1)

```
where
```
- f()is the function of the process:
    ■it allows obtaining the next state depending on the current state (ˆxk) and the control variables
       (uk), which are the linear and angular velocities.
- Pis the process state covariance matrix
- Qis the process error covariance matrix
- Jfx(ˆxk,uk,wk)is the jacobian of functionf in relation tox;
- Jfw(ˆxk,uk,wk)is the jacobian of functionf in relatin tow;
    ■both evaluated at(ˆxk,uk,wk)

In all the previous expressions, as the process noise (control variables) is generally assumed to be
zero-mean Gaussian,wk ∼ N(0,Q), we normally usewk = 0. Some literature considers that the
control input refers to the next moment and, in this case,uk+1can be used instead ofuk, but in any
case it is the control value applied to estimate the next state.
Update using observation:
(
ˆxk+1= ̄xk+1+K(zk+1−h( ̄xk+1))
Pk+1=P ̄k+1−KSK⊺

### (2)

```
where
```
- zk+1is the vector of all sensorial readings obtained at a given time.
- zk+1−h( ̄xk+1)is the innovation
- Sis innovation covariance given by:
    ■S=Jh( ̄xk+1)P ̄k+1J⊺h( ̄xk+1) +R
    ■Ris the covariance matrix of the observations (sensory measurements)
- Kis the Kalman gain given by:
    ■K=P ̄k+1J⊺h( ̄xk+1)S−^1
- whereJh( ̄xk+1)
    ■is the jacobian of functionh()in relation toxevaluated atx ̄k+1.

## 2.2 Environment and trajectory

The scenario is a rectangular geometry environment whereNpassing points are defined that also corre-
spond to the position of landmarks or beaconsBn(n= 1, 2 ,···,N) that can be detected with a given
measurement uncertainty.


The robot must try to execute a trajectory that starts at the initial point(0, 0 ,0)and passes through
all the beacons, stopping at the last one in the list.
To define the motion model, more particularly the control variables, the trajectory must be specified
in such a way that the velocity control parameters (linear and angular) are defined at regular intervals in
each section between beacons, thus defining the points where it is expected to update the robot control
signals (and if there are new observations from the sensors).
In fact, whenever there are new observations, the localization estimate can be updated. Thus, the
velocity control updates (angular and linear) are conditioned by the availability rate of the sensors and
the desired velocity for the movement.
To simplify the estimation of the trajectory points, and since this is a kinematic simulation and not a
reactive motion adapted during execution, for this calculation it is assumed that the robot moves along
a linear segment at constant velocity. The actual positions on the desired final trajectory may be slightly
different, but this is not decisive and is described below.
As an example, if the sensors have an update interval of1 s, and the average linear velocity of the
robot is intended to be5 m/sthen, in a segment of20 mbetween two beacons, 520 × 1 = 4intermediate
points for updating sensor readings and control inputs (velocities) will be defined. These points are in
addition to the points of the beacons themselves and the starting point that make up the total trajectory.
To understand this better, follows another example: between each pair of beacons (and between the
starting point and the first beacon), there must be points where new sensor readings will be taken and
a new control will be imposed, approximately every∆d= ∆t×V (inm) in the linear trajectory, where
∆tis the interval between successive sensor readings (ins) andV is the linear velocity (m/s). Follows
a numerical example: consider two consecutive beaconsB 1 =

### 

### 10 10

### 

```
andB 2 =
```
### 

### 40 50

### 

, the linear
distance between them is 50 meters (

### 

### 40 − 10 50 − 10

 (^)
= 50); with a linear velocity ofV = 5 m/s
and a sensor update interval∆t= 2 s, 550 × 2 = 5intervals, that is, 4 intermediate points, as shown in
Figure 2.
10 15 20 25 30 35 40
0
5
10
15
20
25
30
35
40
45
50
∆d
= 10 m
V = 5 m/s;∆t= 2 s;∆d= 10 m
5 steps between pairs of beacons, i.e., 4 intermediate points
x (m)
y (m)
Bn
Bn+
Figure 2:Illustration of the calculation of the number of points to use in the trajectory segment between successive
beacons. The linear section of the trajectory was divided into segments of10 m, which is the value for
the desired velocity and the sampling time of the sensors.

## 2.3 Sensor measurements

The measurements (observations) of the sensors will be simulated using a provided function called:
BeaconDetection(). This function returns the distance and direction readings in relation to the robot’s
posture that is passed as an argument. Measurements are uncertain and under some conditions are not


available for the following possible reasons: too close or too far from the beacon, or even due to sporadic
failures. In these situations the beacon measurements come asNaN(not-a-number). In addition to the
measurements, the returned data also has information about the beacons, such as their coordinates in
the world. The general description ofBeaconDetection()is as follows:
function [B]=BeaconDetection(N,P,obsNoise)
%
% Function that does two main tasks:
% Creates a set of up to N beacons in a fixed arrangement.
% Returns informations of those beacons as described.
%
% INPUTS:
% N - number of beacons to create/use (N>3) but large values may not be respected
% P - current estimated position (x,y,a). (0,0,0) if absent.
% obsNoise - observation noise [range, heading]. If not passed, use a default value
%
% OUTPUT
% B - array of structures with data from beacons:
% B.X - real beacon X position (fixed and known)
% B.Y - real beacon Y position (fixed and known)
% B.d - measured distance (with uncertainty)
% B.a - measured angle (with uncertainty)
% B.dn - sigma in B.d (either the passed in obsNoise or a default)
% B.an - sigma in B.a (either the passed in obsNoise or a default)
%
% NOTES:
% Occasionally B.d and B.a are not available (too close or to far from beacon)
% and in those cases their value is NaN and sensorial data is not available.

The robot must start at point(0, 0 ,0), that is, at the origin and oriented horizontally to the right.
The planned trajectory must be smooth and pass through all pointsBnand end at the last one. Of the
various possibilities for defining such a trajectory, the Hermite cubic polynomial interpolation should be
adopted, which, inMatlab, is obtained with thepchip()function, that is, Piecewise Cubic Hermite
Interpolating Polynomial. The control and observation points are defined along this trajectory.
These points must be evenly spaced inx and the respective values iny are obtained by applying
exactly the aforementionedpchip()function. This does not always result in uniform spacing along the
path because of the smooth interpolation adopted, but it is an approximate process and greatly simplifies
the definition of these control points! Figure 3 illustrates a case with 6 beacons in a rectangular space
of 300 × 160 where on the right the trajectory with Hermite interpolation is shown and the marking of
the different points along the trajectory to try to simulate a regularity throughout the movement.

```
0 50 100 150 200 250 300
```
```
0
```
```
50
```
```
100
```
```
150
```
```
0 50 100 150 200 250 300
```
```
0
```
```
50
```
```
100
```
```
150
```
```
V= 5 m/s;∆t= 2 s;∆d= 10 m
Beacons and the linearised path Steps between pairs of beacons = 7, 11, 6, 7, 9, 9
Path by Hermite polynomial interpolation (pchip)
```
```
x (m) x (m)
```
```
y (m)
```
Figure 3:Trajectory that starts at the origin and passes through 6 beacons. On the right, the illustration of the
intervals that define the control and observation points along the interpolated trajectory.

The interpolated trajectory represented on the right side of Figure 3 is considered the ideal planned
trajectory for the case of 6 beacons and, therefore, will be defined as theground truthfor all comparisons
and analyses that will be carried out. Other trajectories of a similar nature will be defined for other values
of the number of beacons.


## 2.4 Motion models and physical requirements

The calculation for the planning and localization can be done for a generic robot where the control inputs
are linear and angular velocities, and this will be the recommended methodology in the general case.
However, for some reason, the defined trajectories may demand excessive mechanical requirements.
For example, a certain linear or angular velocity of the robot may need excessive angular velocity values
for a traction wheel, or steering limits for a directional wheel.
Thus, an analysis of the angular velocities of the traction wheels (and the values of the steering wheel
of a tricycle) must be carried out for three robots with different kinematic models along the path to be
executed, namely:

- Differential drive
- Tricycle
- Omnidirectional drive
    These kinematic models are different, but can be parametrized in a similar way: they all have a
parameterLwhich is the distance that relates the relative position of the wheels, as illustrated in Figure
4, and the tricycle has a second parameter which is the direction of the front wheel, and is calledα.

```
ω
```
```
L
```
```
Yr
```
```
Xr
```
```
ICR
```
```
ω L
```
```
Yr
```
```
Xr
```
```
R
```
```
α
```
```
ICR α
```
```
ω
```
```
Yr L
```
```
Xr
```
```
Figure 4:Kinematic models of robots to use: differential, tricycle and omnidirectional.
```
Thus, after establishing the trajectory with the geometric and kinematic requirements calculated with
the methodology presented earlier, the consequences for each of the kinematic models in the velocities
of the traction wheels and in the values of the angles of the steering wheel must be verified.
In the case of the tricycle, it is assumed that the traction is done on the back wheel, more specifically
on the "virtual" wheel equivalent to the two wheels that will be connected by a mechanical differential.
Therefore, when we mention the velocity of the back wheel of the tricycle, we are assuming the "virtual"
wheel equivalent to an "average" of the two back wheels of the tricycle.
More particularly, the physical quantities that must be determined for each of the kinematic models
are the following:

- Differential drive -ωRandωL(right and left wheels)
- Tricycle -ωT andα(rear wheel velocity and front wheel angular position)
- Omnidirectional -ω 1 ,ω 2 andω 3 (on wheels 1, 2 and 3 – in Figure 4 the positive directions are
    indicated)
It is assumed that the robots have the same distance valueLand their respective wheels are assumed
to have the same radiusr. Therefore, for the physical parametersLandrof each robot, and for each
point of the calculated trajectory, it is necessary to obtain the values of the angular velocities of all driving
wheels and the angle of the steering wheel on the tricycle.

# 3 Student program

## 3.1 Summary

Students must create a main program that is aMatlabfunction that accepts the following parameters
(where default values are indicated if they are omitted in the call of the function):


- N - number of beacons (4)
- Dt - sensors sampling time interval (1 s)
- r - radius of the robots wheels (0.15 m)
- L - separation/distance of the wheels according to the kinematic model (1 m)
- Vn - uncertainty (sigma) in the linear velocity to be imposed on the robot (input) (0.1 m/s)
- Wn - uncertainty (sigma) in the angular velocity to be imposed on the robot (input) (0.1 m/s)
- V - desired average linear velocity along trajectory (5 m/s)
    The specific code developed by the student must be in a single main file, including any auxiliary
functions also developed by the student. This file must be namedrm1_nnnnnn.mwithnnnnnn the
student’s number. Functions extracted from the Internet, from the classes or other sources must be
provided separately and with an indication in the header of each one of the source from which they were
used (e.g., the URL of the website). All these functions must be in a separate folder called "lib", which
will then be part of theMatlabpath. If code provided by Generative AI models is used, each block
of that code should be inserted in a function whose name must have the suffix "_AI"; for example,
supposing that a block of code proposed by some LLM is to be made in a function namedmyFunction(),
that function should be renamedmyFunction_AI()so it is clearly identified as AI generated. This is only
applicable to full functions, not to fragments of few lines of code.

## 3.2 Summary of procedure

The main parts of the procedure, which correspond to the tasks to be carried out by the student’s
program, are the following:

1. Calculate all the points on the trajectory with the passed parameters and the coordinates of the
    beacons, which are obtained with a simple call to the functionB=BeaconDetection(N). The calculated
    trajectory will contain all the points where the robot passed with a certain pose:(x,y,θ), withθdefined
    as the direction angle to the next intermediate point of the trajectory.
2. Calculate the linear and angular velocities to apply to the robot at each point of the trajectory. These
    velocities should be such that, in theory, they take the robot to the next pose during the time interval
    ∆t.
3. For each point (pose) of the trajectory, apply the Kalman filter to estimate the next point (location).
    For that, it is also necessary to call theBeaconDetection()function with the appropriate parameters
    to obtain the measurements from the current point. This step is the most important and the most
    laborious, and it is the core of probabilistic localization.
4. During the previous process, save the successive poses (estimated locations) and, at the end, create
    a file with that data with one pose per line and the 3 fields separated by a comma. The file must be
    calledloc_nnnnnn.txtwherennnnnnis the student number.
5. For each of the kinematic models of the robots, calculate the angular velocities of the wheels and/or
    the direction of the tricycle wheel along the path. There should be distinct files with one entry per
    line with the fields separated by commas; or, more specifically, as shown below, where the name of
    the file to be created and the format of each line in each robot are indicated, and wherennnnnnis
    the student’s number:
       Differential drive DD_nnnnnnn.txt ωR,ωL
       Tricycle TRI_nnnnnnn.txt ωT,α
       Omnidirectional OMNI_nnnnnnn.txt ω 1 ,ω 2 ,ω 3
    In summary, the student’srm1_nnnnnn.mprogram:
       - must be aMatlabfunction
       - needs to use the provided functionBeaconDetection()
       - generates the following files during its execution:
          - loc_nnnnnn.txt
          - DD_nnnnnnn.txt
          - TRI_nnnnnnn.txt
          - OMNI_nnnnnnn.txt


# 4 Material to submit for evaluation

- Program inMatlabdeveloped by the student in function format as described earlier, and which
    is the program to execute. The file name should berm1_nnnnnn.mwherennnnnnis the student’s
    number.
- All external functions used, not developed by the student, but which are essential to the execution
    of the main program. It is recommended that these functions are in a separate folder called "lib"
    which will be integrated into theMatlabpath when executing the main program.
- A report of a maximum of 6 pages (including the cover page) written in LATEX with thedocumentlass
    ofreportor similar. This report must include a description of the methodology with the mathemat-
    ical formalisms used as well as the figures and graphs needed to illustrate the results. A conclusion
    and analysis of those results should also included. A way to enrich this analysis could be an objective
    statistical comparison of the results that would be obtained by classic triangulation/trilateration
    techniques and the probabilistic technique used in this work.

The following evaluation elements will be considered with the associated estimated weight in the
assignment final grade (variations of up to 5% in some items may take place):

- Conformity of the trajectories as requested in the assignment. (≈20%)
- Quality of localization results. (≈40%)
- Results of the calculation of the physical requirements on the robot models. (≈20%)
- The report: accuracy of language and mathematical formalisms, richness and clarity of figures,
    typographic quality (LATEX highly recommended). The conclusions and critical analysis of results
    will also be considered important. Equations, diagrams, charts, tables and figures are more welcome
    than plain text only. (≈20%)

```
The code developed by the students will be checked for plagiarism using the MOSS system.
```


