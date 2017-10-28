%   This script computes the mean reprojection error (in terms of euclidean distance)
%   introduced by the homography estimation when projecting from etg to
%   garmin

clear; close all; clc;

% Add packages to path
addpath(genpath('homography_utils'));
addpath(genpath('vlfeat-0.9.20'));

% Parameters
dreyeve_data_root = '/majinbu/public/DREYEVE/DATA';
all_sequences = 1:74;
n_sequences = numel(all_sequences);

% For each sequence, we store mean (col 1) and variance (col 2) of error
error_means_and_vars = zeros(n_sequences, 2);

% Loop over sequences
for s=1:n_sequences
    
    seq = all_sequences(s);
    
    % Root for this sequence
    seq_root = fullfile(dreyeve_data_root, sprintf('%02d', seq));
    
    % List etg and garmin sift files
    sift_etg_li = dir(fullfile(seq_root, 'etg', 'sift', '*.mat'));
    sift_gar_li = dir(fullfile(seq_root, 'sift', '*.mat'));
    n_frames = numel(sift_etg_li);
    
    % rows are frames, cols are (mean error, number of matches)
    sequence_frame_sum_error = zeros(n_frames, 2);
    
    % Initialize counters
    m = 0;  % running mean
    v = 0;  % running variance
    n = 0;  % number of total matches
    
    % Loop over list
    for f=1:100:n_frames
        
        fprintf(1, sprintf('Sequence %02d, frame %06d of %06d...\n', seq, f, n_frames));
        
        % Load sift files for both etg and garmin
        load(fullfile(seq_root, 'etg', 'sift', sift_etg_li(f).name));
        load(fullfile(seq_root, 'sift', sift_gar_li(f).name));
        
        % Compute matches
        [matches, scores] = vl_ubcmatch(sift_etg.d1,sift_gar.d1);
        
        %numMatches = size(matches,2) ;
        
        % Prepare data in homogeneous coordinates for RANSAC
        X1 = sift_etg.f1(1:2, matches(1,:)); X1(3,:) = 1; X1([1 2], :) = X1([1 2], :)*2;
        X2 = sift_gar.f1(1:2, matches(2,:)); X2(3,:) = 1; X2([1 2], :) = X2([1 2], :)*2;
        
        try
            % Fit ransac and find homography
            [H, ok] = ransacfithomography(X1, X2, 0.05);
            if size(ok, 2) >= 8
                
                % Extract only matches that homography considers inliers
                X1 = X1(:, ok);
                X2 = X2(:, ok);
                
                % Project
                X1_proj = H * X1;
                X1_proj = X1_proj ./ repmat(X1_proj(3, :), 3, 1);
                
                % Compute error
                errors = sqrt(sum((X1_proj - X2).^2, 1));
                errors(isnan(errors)) = [];
                for e=1:size(errors, 2)
                    % update mean and variance
                    n = n+1;
                    delta = errors(1, e) - m;
                    m = m + delta / n;
                    delta2 = errors(1, e) - m;
                    v = v + delta * delta2;
                end
            end
        catch ME
            warning('Catched exception, skipping some frames');
        end
    end
    
    % Set mean and var for this sequence
    error_means_and_vars(s, 1) = m;
    error_means_and_vars(s, 2) = v;
end

save('error_means_and_vars_etg_to_gar', 'error_means_and_vars');