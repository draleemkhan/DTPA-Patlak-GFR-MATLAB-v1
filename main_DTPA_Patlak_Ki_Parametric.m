%% DTPA Dynamic Renal Patlak Pipeline
% Author: Muhammad Aleem Khan
%
% Outputs:
% 1. ROI-based Left Ki, Right Ki, Total Ki
% 2. Ki-based DRF
% 3. Parametric Ki map
% 4. Parametric R2 map
% 5. QC-filtered Ki map
% 6. All figures saved in repository outputs folder

clear; clc; close all;
addpath(genpath(pwd));

%% Create output folder inside repository
repoFolder = pwd;
outputFolder = fullfile(repoFolder, 'outputs');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

%% Select dynamic DICOM
[file, folder] = uigetfile({'*.dcm'}, 'Select dynamic DTPA renal DICOM');

if isequal(file,0)
    error('No DICOM file selected.');
end

dicomFile = fullfile(folder, file);

%% Load dynamic image
[img, info] = load_dynamic_dicom(dicomFile);

fprintf('Loaded image size: %d x %d x %d frames\n', size(img,1), size(img,2), size(img,3));

%% Extract frame times
t_mid = get_frame_times(info);
t_mid = t_mid(:);

nFrames = size(img,3);

if length(t_mid) ~= nFrames
    n = min(length(t_mid), nFrames);
    img = img(:,:,1:n);
    t_mid = t_mid(1:n);
    warning('Frames and timing mismatch. Data trimmed to %d frames.', n);
end

%% Reference images
sumAll   = sum(img,3);
sumEarly = sum(img(:,:,1:min(30,size(img,3))),3);

% Enhanced inverse grayscale display images
sumAll_disp = mat2gray(sumAll);
sumAll_disp = imadjust(sumAll_disp, stretchlim(sumAll_disp,[0.01 0.99]), []);

sumEarly_disp = mat2gray(sumEarly);
sumEarly_disp = imadjust(sumEarly_disp, stretchlim(sumEarly_disp,[0.01 0.99]), []);

figure;
imshow(sumAll_disp, []);
colormap(flipud(gray));
title('Inverse Grayscale Summed Dynamic Image');
saveas(gcf, fullfile(outputFolder,'01_inverse_summed_dynamic_image.png'));
savefig(gcf, fullfile(outputFolder,'01_inverse_summed_dynamic_image.fig'));

figure;
imshow(sumEarly_disp, []);
colormap(flipud(gray));
title('Inverse Grayscale Early Summed Image');
saveas(gcf, fullfile(outputFolder,'02_inverse_early_summed_image.png'));
savefig(gcf, fullfile(outputFolder,'02_inverse_early_summed_image.fig'));

%% Draw vascular ROI
disp('Draw vascular ROI on heart/aorta.');
[Cp, maskVascular] = draw_roi_get_mask_tac(img, sumEarly, 'Draw vascular ROI');

figure;
imshow(sumEarly_disp, []);
colormap(flipud(gray));
title('Vascular ROI');
hold on;
visboundaries(maskVascular, 'Color', 'y', 'LineWidth', 1.5);
saveas(gcf, fullfile(outputFolder,'03_vascular_roi.png'));
savefig(gcf, fullfile(outputFolder,'03_vascular_roi.fig'));

%% Draw kidney ROIs
disp('Draw LEFT kidney ROI.');
[Rlt, maskL] = draw_roi_get_mask_tac(img, sumAll, 'Draw LEFT kidney ROI');

disp('Draw RIGHT kidney ROI.');
[Rrt, maskR] = draw_roi_get_mask_tac(img, sumAll, 'Draw RIGHT kidney ROI');

figure;
imshow(sumAll_disp, []);
colormap(flipud(gray));
title('Left and Right Kidney ROIs');
hold on;
visboundaries(maskL, 'Color', 'b', 'LineWidth', 1.5);
visboundaries(maskR, 'Color', 'r', 'LineWidth', 1.5);
legend('Left kidney','Right kidney');
saveas(gcf, fullfile(outputFolder,'04_kidney_rois.png'));
savefig(gcf, fullfile(outputFolder,'04_kidney_rois.fig'));

%% Smooth TACs
Cp_s  = smoothdata(Cp(:),  'sgolay', 7);
Rlt_s = smoothdata(Rlt(:), 'sgolay', 7);
Rrt_s = smoothdata(Rrt(:), 'sgolay', 7);

Cp_s(Cp_s <= 0) = eps;

%% Plot TACs
figure;
plot(t_mid/60, Cp_s, 'k', 'LineWidth', 2); hold on;
plot(t_mid/60, Rlt_s, 'b', 'LineWidth', 2);
plot(t_mid/60, Rrt_s, 'r', 'LineWidth', 2);
xlabel('Time (min)');
ylabel('Mean counts');
legend('Input','Left kidney','Right kidney');
title('Input and Renal Time-Activity Curves');
grid on;
saveas(gcf, fullfile(outputFolder,'05_TACs_input_left_right.png'));
savefig(gcf, fullfile(outputFolder,'05_TACs_input_left_right.fig'));

%% Patlak fitting window
% For DTPA GFR early uptake, start with 60–180 sec.
fitWindow = t_mid >= 60 & t_mid <= 180;

%% ROI-based Patlak analysis
[Ki_Lt, V0_Lt, R2_Lt, X, Ylt, yfitLt] = patlak_roi_fit(Cp_s, Rlt_s, t_mid, fitWindow);
[Ki_Rt, V0_Rt, R2_Rt, ~, Yrt, yfitRt] = patlak_roi_fit(Cp_s, Rrt_s, t_mid, fitWindow);

Ki_Total = Ki_Lt + Ki_Rt;

DRF_Lt = 100 * Ki_Lt / Ki_Total;
DRF_Rt = 100 * Ki_Rt / Ki_Total;

fprintf('\n--- ROI Patlak Results ---\n');
fprintf('Left Ki   = %.6f | V0 = %.4f | R2 = %.3f\n', Ki_Lt, V0_Lt, R2_Lt);
fprintf('Right Ki  = %.6f | V0 = %.4f | R2 = %.3f\n', Ki_Rt, V0_Rt, R2_Rt);
fprintf('Total Ki  = %.6f\n', Ki_Total);
fprintf('Left DRF  = %.1f%%\n', DRF_Lt);
fprintf('Right DRF = %.1f%%\n', DRF_Rt);

%% Plot Patlak curves
figure;

subplot(1,2,1);
plot(X(fitWindow), Ylt(fitWindow), 'bo', 'LineWidth', 1.5); hold on;
plot(X(fitWindow), yfitLt, 'r-', 'LineWidth', 2);
xlabel('\intCpdt / Cp');
ylabel('Ct / Cp');
title(sprintf('Left Patlak: Ki %.5f, R2 %.3f', Ki_Lt, R2_Lt));
grid on;

subplot(1,2,2);
plot(X(fitWindow), Yrt(fitWindow), 'bo', 'LineWidth', 1.5); hold on;
plot(X(fitWindow), yfitRt, 'r-', 'LineWidth', 2);
xlabel('\intCpdt / Cp');
ylabel('Ct / Cp');
title(sprintf('Right Patlak: Ki %.5f, R2 %.3f', Ki_Rt, R2_Rt));
grid on;

saveas(gcf, fullfile(outputFolder,'06_ROI_Patlak_plots.png'));
savefig(gcf, fullfile(outputFolder,'06_ROI_Patlak_plots.fig'));

%% Parametric Ki and R2 maps
kidneyMask = maskL | maskR;

[KiMap, R2Map] = patlak_parametric_maps(img, Cp_s, t_mid, fitWindow, kidneyMask);

%% Display kidney mask
figure;
imshow(sumAll_disp, []);
colormap(flipud(gray));
title('Kidney Mask for Parametric Analysis');
hold on;
visboundaries(kidneyMask, 'Color', 'c', 'LineWidth', 1.5);
saveas(gcf, fullfile(outputFolder,'07_kidney_mask.png'));
savefig(gcf, fullfile(outputFolder,'07_kidney_mask.fig'));

%% Raw Ki map
figure;
imagesc(KiMap);
axis image off;
colormap hot;
colorbar;
title('Raw Parametric Patlak Ki Map');
saveas(gcf, fullfile(outputFolder,'08_raw_Ki_map.png'));
savefig(gcf, fullfile(outputFolder,'08_raw_Ki_map.fig'));

%% R2 map
figure;
imagesc(R2Map);
axis image off;
colormap hot;
colorbar;
title('Parametric Patlak R² Map');
saveas(gcf, fullfile(outputFolder,'09_R2_map.png'));
savefig(gcf, fullfile(outputFolder,'09_R2_map.fig'));

%% QC-filtered Ki map
R2_threshold = 0.5;

KiQC = KiMap;
KiQC(R2Map < R2_threshold) = NaN;
KiQC(KiQC < 0) = NaN;

figure;
imagesc(KiQC);
axis image off;
colormap hot;
colorbar;
title(sprintf('QC-filtered Ki Map | R² > %.2f', R2_threshold));
saveas(gcf, fullfile(outputFolder,'10_QC_filtered_Ki_map.png'));
savefig(gcf, fullfile(outputFolder,'10_QC_filtered_Ki_map.fig'));

%% Summary figure: Raw Ki, R2, QC Ki
figure;
subplot(1,3,1);
imagesc(KiMap);
axis image off;
colormap hot;
colorbar;
title('Raw Ki');

subplot(1,3,2);
imagesc(R2Map);
axis image off;
colormap hot;
colorbar;
title('R² Map');

subplot(1,3,3);
imagesc(KiQC);
axis image off;
colormap hot;
colorbar;
title('QC Ki');

sgtitle('Parametric Patlak Imaging Summary');
saveas(gcf, fullfile(outputFolder,'11_parametric_summary.png'));
savefig(gcf, fullfile(outputFolder,'11_parametric_summary.fig'));

%% Results structure
results.PatientName = '';
if isfield(info,'PatientName')
    results.PatientName = info.PatientName;
end

results.PatientID = '';
if isfield(info,'PatientID')
    results.PatientID = info.PatientID;
end

results.StudyDate = '';
if isfield(info,'StudyDate')
    results.StudyDate = info.StudyDate;
end

results.Ki_Lt = Ki_Lt;
results.Ki_Rt = Ki_Rt;
results.Ki_Total = Ki_Total;
results.V0_Lt = V0_Lt;
results.V0_Rt = V0_Rt;
results.R2_Lt = R2_Lt;
results.R2_Rt = R2_Rt;
results.DRF_Lt = DRF_Lt;
results.DRF_Rt = DRF_Rt;
results.KiMap = KiMap;
results.R2Map = R2Map;
results.KiQC = KiQC;
results.t_mid = t_mid;
results.Cp = Cp_s;
results.Rlt = Rlt_s;
results.Rrt = Rrt_s;
results.maskVascular = maskVascular;
results.maskL = maskL;
results.maskR = maskR;
results.kidneyMask = kidneyMask;
results.fitWindow_sec = [60 180];
results.R2_threshold = R2_threshold;

save(fullfile(outputFolder,'DTPA_Patlak_Results.mat'), 'results');

%% Save numerical summary as CSV
summaryTable = table( ...
    Ki_Lt, Ki_Rt, Ki_Total, V0_Lt, V0_Rt, R2_Lt, R2_Rt, DRF_Lt, DRF_Rt, ...
    'VariableNames', {'Ki_Left','Ki_Right','Ki_Total','V0_Left','V0_Right','R2_Left','R2_Right','DRF_Left','DRF_Right'} );

writetable(summaryTable, fullfile(outputFolder,'DTPA_Patlak_Summary.csv'));

fprintf('\nAll outputs saved in:\n%s\n', outputFolder);
fprintf('\nPipeline completed successfully.\n');