function [TAC, mask] = draw_roi_get_mask_tac(img, refImg, plotTitle)

% Enhanced inverse grayscale display
refDisp = mat2gray(refImg);
refDisp = imadjust(refDisp, stretchlim(refDisp,[0.01 0.99]), []);

figure;
imshow(refDisp, []);
colormap(flipud(gray));
title(plotTitle);

roi = drawfreehand('Color','y','LineWidth',2);
mask = createMask(roi);

nFrames = size(img,3);
TAC = zeros(nFrames,1);

for k = 1:nFrames
    frame = img(:,:,k);
    TAC(k) = mean(frame(mask),'omitnan');
end

end