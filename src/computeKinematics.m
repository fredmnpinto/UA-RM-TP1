function [DD, TRI, OMNI] = computeKinematics(trajectory, r, L, Dt)
%COMPUTEKINEMATICS Compute wheel velocities for 3 robot models
%
% Inputs:
%   trajectory - Mx3 matrix [x, y, theta]
%   r          - wheel radius (m)
%   L          - wheel separation/distance (m)
%   Dt         - sampling time interval (s)
%
% Outputs:
%   DD   - Mx2 matrix [wR, wL] for differential drive
%   TRI  - Mx2 matrix [wT, alpha] for tricycle
%   OMNI - Mx3 matrix [w1, w2, w3] for omnidirectional

    M = size(trajectory, 1);
    DD = zeros(M, 2);
    TRI = zeros(M, 2);
    OMNI = zeros(M, 3);
    
    for i = 1:M-1
        % ============ COMPUTE v AND omega ============
        dx = trajectory(i+1, 1) - trajectory(i, 1);
        dy = trajectory(i+1, 2) - trajectory(i, 2);
        d = sqrt(dx^2 + dy^2);
        v = d / Dt;
        
        dtheta = wrapToPi(trajectory(i+1, 3) - trajectory(i, 3));
        omega = dtheta / Dt;
        
        % ============ 1. DIFFERENTIAL DRIVE ============
        % Inverse kinematics: wR = (v + omega*L/2)/r, wL = (v - omega*L/2)/r
        wR = (v + omega * L / 2) / r;
        wL = (v - omega * L / 2) / r;
        DD(i, :) = [wR, wL];
        
        % ============ 2. TRICYCLE (Rear-wheel drive) ============
        % Rear wheel: wT = v/r
        % Steering angle: alpha = atan2(omega*L, v)
        wT = v / r;
        alpha = atan2(omega * L, v);
        TRI(i, :) = [wT, alpha];
        
        % ============ 3. OMNIDIRECTIONAL (Class configuration) ============
        % M matrix from localvels.m (case 3)
        M_jac = [0,          r/sqrt(3),    -r/sqrt(3);
                 -2*r/3,     r/3,          r/3;
                 r/(3*L),    r/(3*L),     r/(3*L)];
        M_inv = inv(M_jac);
        
        % Robot frame: Vx = v, Vy = 0, w = omega
        wheels = M_inv * [v; 0; omega];
        OMNI(i, :) = wheels';
    end
    
    % ============ LAST POINT: SET TO 0 (ROBOT STOPS) ============
    DD(M, :) = [0, 0];
    TRI(M, :) = [0, 0];
    OMNI(M, :) = [0, 0, 0];
end

function angle = wrapToPi(angle)
    % Wrap angle to [-pi, pi]
    angle = atan2(sin(angle), cos(angle));
end
