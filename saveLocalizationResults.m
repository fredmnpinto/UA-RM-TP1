function saveLocalizationResults(estimated_trajectory, filename)
%SAVELOCALIZATIONRESULTS Save EKF results to file
%
% Input:
%   estimated_trajectory - M×3 matrix [x_est, y_est, θ_est]
%   filename             - output filename (e.g., 'loc_129466.txt')

    fid = fopen(filename, 'w');
    
    M = size(estimated_trajectory, 1);
    
    for i = 1:M
        fprintf(fid, '%.6f, %.6f, %.6f\n', ...
            estimated_trajectory(i, 1), ...
            estimated_trajectory(i, 2), ...
            estimated_trajectory(i, 3));
    end
    
    fclose(fid);
    fprintf('Saved localization results to %s\n', filename);
end
