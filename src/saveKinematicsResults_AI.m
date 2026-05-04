function saveKinematicsResults_AI(DD, TRI, OMNI, student_number)
%SAVEKINEMATICSRESULTS Save wheel velocities to output files
%
% Inputs:
%   DD            - Mx2 matrix [wR, wL] for differential drive
%   TRI           - Mx2 matrix [wT, alpha] for tricycle
%   OMNI          - Mx3 matrix [w1, w2, w3] for omnidirectional
%   student_number - string with student number (e.g., '129466')

    % ============ SAVE DD_######.txt ============
    filename = ['DD_' student_number '.txt'];
    fileID = fopen(filename, 'w');
    for i = 1:size(DD, 1)
        fprintf(fileID, '%.6f, %.6f\n', DD(i,1), DD(i,2));
    end
    fclose(fileID);
    fprintf('  Saved %s\n', filename);

    % ============ SAVE TRI_######.txt ============
    filename = ['TRI_' student_number '.txt'];
    fileID = fopen(filename, 'w');
    for i = 1:size(TRI, 1)
        fprintf(fileID, '%.6f, %.6f\n', TRI(i,1), TRI(i,2));
    end
    fclose(fileID);
    fprintf('  Saved %s\n', filename);

    % ============ SAVE OMNI_######.txt ============
    filename = ['OMNI_' student_number '.txt'];
    fileID = fopen(filename, 'w');
    for i = 1:size(OMNI, 1)
        fprintf(fileID, '%.6f, %.6f, %.6f\n', OMNI(i,1), OMNI(i,2), OMNI(i,3));
    end
    fclose(fileID);
    fprintf('  Saved %s\n', filename);
end
