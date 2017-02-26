function parallel_2_sbx2tif_stdDev(fname,N)

z = sbxread(fname,1,1);
global info;

if nargin > 1
    maxIDX = min(N,info.max_idx);
else
    maxIDX = info.max_idx;
end

tic

% cropping margins
top = 20;
bottom = 20;
left = 130;
right = 40;

col = info.sz(1)-(top + bottom - 1);
row = info.sz(2)-(left + right - 1);

% determine brightest frame and use it as reference image
a = 1:200;
for i = 1:200
    x = squeeze(sbxread(fname,i,1));
    x = mean(x(:));
    a(i) = x;
end

% set reference image
[~,refIDX] = max(a);
ref = squeeze(sbxread(fname,refIDX,1));
ref = ref(top:end-bottom,left:end-right);

% initialize array to hold aligned images
z = uint16(0);
imgData(col,row) = z;
imgData = repmat(imgData,1,1,maxIDX);

% align frames in parallel and store in imgData matrix
parfor i = 1:maxIDX
    img = squeeze(sbxread(fname,i,1));
    img = img(top:end-bottom,left:end-right);
    [~,imgA] = imregdemons(img,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
    imgData(:,:,i) = imgA;
end

alignTime = toc;
fprintf('Aligned all %d frames in %d seconds.\n', maxIDX, alignTime);

meanImg = mean(imgData,3);
meanTime = toc - alignTime;
fprintf('Calculated mean image in %d seconds.\n', meanTime);

for i = 1:maxIDX
    dRead = double(imgData(:,:,i));
    img = (dRead - meanImg).^2;
    if i == 1
        v = img;
    else
        v = v+img;
    end
end

varianceImg = v/maxIDX;
stdDevImg = sqrt(varianceImg);
stdDevImg = uint16(stdDevImg);
imwrite(stdDevImg,sprintf('STD_%s.tif',fname),'tif');

endTime = toc;
fprintf('Completed in %d seconds.\n',endTime);

end


