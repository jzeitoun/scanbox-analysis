function sbx2pacu_align(fname,N)

z = sbxread(fname,1,1);
global info;

if nargin > 1
    maxIDX = min(N,info.max_idx);
else
    maxIDX = info.max_idx;
end

tic

% Get dimensions of frame
col = info.sz(1);
row = info.sz(2);

% Determine brightest frame and use it as reference image
a = 1:200;
for i = 1:200
    x = squeeze(sbxread(fname,i,1));
    x = mean(x(:));
    a(i) = x;
end

% Crop and set reference image
[~,refIDX] = max(a);
ref = squeeze(sbxread(fname,refIDX,1));
ref = ref(top:end-bottom,left:end-right);

% Initialize array to hold aligned images
z = uint16(0);
imgData(col,row) = z;
imgData = repmat(imgData,1,1,maxIDX);

% Align frames in parallel and store in imgData matrix
parfor i = 1:maxIDX
    img = squeeze(sbxread(fname,i,1));
    [~,imgA] = imregdemons(img,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
    imgData(:,:,i) = imgA;
end

% Convert aligned frames back to raw sbx format
[~,~,z] = size(imgData);
imgData = intmax('uint16')-permute(imgData,[2 1 3]);
imgData = reshape(imgData,[info.nchan, (info.sz(2)*info.recordsPerBuffer*z)]);

% Write file back out as raw sbx bindary
fileID = fopen(['Aligned_' fname '.sbx'],'w');
fwrite(fileID,imgData,'uint16');
fclose(fileID);

% Copy the metadata file
load([fname '.mat']);
save(['Aligned_' fname '.mat'],'info');

alignTime = toc;
fprintf('Aligned all %d frames in %d seconds.\n', maxIDX, alignTime);

end


