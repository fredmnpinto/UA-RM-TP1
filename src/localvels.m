function [Vx,Vy,w]=localvels(t,r,L,w1,aw2,w3)
% Vx, Vy, w - velocities in local frame
% t  - type of robot:
%    1 - DD
%    2 - TRI
%    3 - OMNI
% r  - traction wheel radius
% L  - meaning depending on type (wheel sep-->1, wheel dist-->2, wheel dist-->3)
% w1 - angular vel of wheel 1 (Right wheel-->1, steering-->2)
% aw2- angular vel of wheel 2 (left --> 1) or alpha --> 2
% w3 - angular vel of wheel 3 (OMNI)

if nargin < 6
    w3 = 0;
end

switch t
    case 1 % DD robot
        M = [
            r/2 r/2
            0 0
            -r/L r/L
            ];

        resultM = M * [aw2;w1];

        Vx= resultM(1) ;
        Vy= resultM(2) ;
        w = resultM(3) ;

    case 2  % TRI
% ...
        Vx= w1 * cos(aw2) ;
        Vy= 0 ;
        w = (w1/L) * sin(aw2) ;

    case 3  % OMNI
% ...
        M = [
            0, r/sqrt(3), -r/sqrt(3)
            -2 * r/3, r/3, r/3
            r/(3 * L), r/(3 * L), r/(3 * L)
            ];

        resultM = M * [w1; aw2; w3];

        Vx= resultM(1) ;
        Vy= resultM(2) ;
        w = resultM(3) ;
end

