function crop_sbx2pacu_align_stdDev(fname,N)

z = sbxread(fname,1,1);
global info;
originalRecordsPerBuffer = info.recordsPerBuffer;

if nargin > 1
    maxIDX = min(N,info.max_idx);   
else
    maxIDX = info.max_idx;
end

tic

% Cropping margins
top = 1;
bottom = 1;
left = 1;
right = 1;

row = info.sz(1)-(top + bottom - 1);
col = info.sz(2)-(left + right - 1);

% Determine if necessary to divide file into chunks and how many
frameSize = row * col * 2;
fileSize = frameSize * maxIDX;
chunkNumFrames = floor(1000000000/frameSize); % using 1GB chunks
chunkNumFramesSize = frameSize * chunkNumFrames;
numChunks = fileSize/chunkNumFramesSize;

if numChunks > 1
    numChunks = floor(numChunks);
    setIDX = chunkNumFrames;
    remainingSize = fileSize - (numChunks*chunkNumFramesSize);
    remainIDX = remainingSize/(frameSize);
    numChunks = numChunks + 1;
    if remainIDX == 0
        numChunks = numChunks - 1;
        remainIDX = setIDX;
    end
    % Create index of weights for mean image calculations
    weightIndex(1:numChunks) = setIDX;
    weightIndex(numChunks) = remainIDX;
else
    setIDX = maxIDX;
    numChunks = 1;
    weightIndex = setIDX;
end

% Determine brightest frame and use it as reference image
a = 1:200;
for i = 1:200
    x = squeeze(sbxread(fname,i,1));
    x = mean(x(:));
    a(i) = x;
end

% Set reference image
[~,refIDX] = max(a);
ref = squeeze(sbxread(fname,refIDX,1));
ref = ref(top:end-bottom,left:end-right);

% Initialize array to hold aligned images and set starting index
int = uint16(0);
imgData(1:row,1:col,1:setIDX) = int;

% Initialize array to hold mean images
meanCollection = zeros(row,col,numChunks);

% Initialize array to hold max images
maxCollection(1:row,1:col,1:numChunks) = int;

for i = 1:numChunks
    % Set starting index
    k = ((i * setIDX) - setIDX)+ 1;
    
    % If on last chunk, truncate imgData array
    if numChunks > 1 && i == numChunks
        imgData = imgData(:,:,1:remainIDX);
        setIDX = remainIDX;
    end
    
    % Align frames in parallel and store in imgData matrix
    parfor j = 1:setIDX
        frame = k + j - 1;
        img = squeeze(sbxread(fname,frame,1));
        img = img(top:end-bottom,left:end-right);
        [~,imgA] = imregdemons(img,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
        imgData(:,:,j) = imgA;
    end

    % Store mean image of chunk
    meanCollection(:,:,i) = mean(imgData,3);
    
    % Store max image of chunk
    maxCollection(:,:,i) = max(imgData,[],3);
    
    % Convert aligned frames back to raw sbx format
    [m,n,z] = size(imgData);
    imgData = intmax('uint16')-permute(imgData,[2 1 3]);
    imgData = reshape(imgData,[1, (m*n*z)]);
    
    % Write file back out as raw sbx binary
    if i == 1
        fileID = fopen(['Aligned_' fname '.sbx'],'w');
        fwrite(fileID,imgData,'uint16');
        fclose(fileID);
    else
        fileID = fopen(['Aligned_' fname '.sbx'],'a');
        fwrite(fileID,imgData,'uint16');
        fclose(fileID);
    end
    
    % Reshape imgData array back to MxNxZ
    imgData = reshape(imgData,m,n,z);
end

% Calculate and save max projection image
maxProjection = max(maxCollection,[],3);
imwrite(maxProjection,['MAX_' fname '.tif'],'tif');

% Calculate total mean image 
weightedMean(1:row,1:col,1:numChunks) = 0;

for i = 1:numChunks
    weightedMean(:,:,i) = meanCollection(:,:,i)*weightIndex(i);
end

meanImg = (sum(weightedMean,3))/maxIDX;

% Write the metadata file, modify fields for newly cropped dimensions
load([fname '.mat']);
info.originalRecordsPerBuffer = originalRecordsPerBuffer;
if info.scanmode == 0
    info.recordsPerBuffer = m/2;
else
    info.recordsPerBuffer = m;
end
info.sz = [m n];
save(['Aligned_' fname '.mat'],'info');

% Calculate standard deviation and write to file
for i = 1:maxIDX
    dRead = double(squeeze(sbxread(['Aligned_' fname],i,1)));
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
imwrite(stdDevImg,['STD_' fname '.tif'],'tif');

alignTime = toc;
fprintf('Aligned all %d frames in %d seconds.\n', maxIDX, alignTime);

fclose all;

end


