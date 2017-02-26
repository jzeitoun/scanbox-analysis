function alignTIF()
% alignTif 
% Converts all sbx files within a directory using
% parallel processing. 
% If aligned = 0, no alignment will occur. If aligned = 1, frames will be aligned. 
% The next argument is optional and will determine the number of frames to convert,
% starting with the first one.
% Example: pbatch_sbx2tif(1,100) will align the first 100 frames of all sbx
% files in the directory and convert them to tiff stacks.

d = dir('*.tif');

% determine brightest frame and use it as reference image
a = 1:length(d);
for i = 1:length(d)
    x = imread(d(i).name);
    x = mean(x(:));
    a(i) = x;
end
%fn = d(2).name;
[~,refIDX] = max(a);
ref = imread(d(refIDX).name);

for i = 1:length(d)
        fn = strtok(d(i).name);
        img = imread(fn);
        [~,imgA] = imregdemons(img,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
        imwrite(imgA,[fn '_aligned.tif']);
end

end
    