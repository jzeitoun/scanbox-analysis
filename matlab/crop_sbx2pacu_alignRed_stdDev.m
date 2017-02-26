function crop_sbx2pacu_alignRed_stdDev(fname,split,N)

z = sbxread(fname,1,1);
global info;
originalRecordsPerBuffer = info.recordsPerBuffer;

if nargin > 2
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

col = info.sz(1)-(top + bottom - 1);
row = info.sz(2)-(left + right - 1);

% If not planning to split channels, initialize array to hold interleaved data
if split == 0
    int = uint16(0);
    combinedData(1:(2*col*row*maxIDX)) = int;
end

% Determine if necessary to divide file into chunks and how many
frameSize = col * row * 2;
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
    
    % Create index of weights for mean image calculations
    weightIndex(1:numChunks) = setIDX;
    weightIndex(numChunks) = remainIDX;
else
    setIDX = maxIDX;
    numChunks = 1;
    weightIndex = setIDX;
end

% Determine brightest red frame and use it as reference image
a = 1:200;
for i = 1:200
    x = sbxread(fname,i,1);
    x = squeeze(x(2,:,:));
    x = mean(x(:));
    a(i) = x;
end

% Set red reference image
[~,refIDX] = max(a);
ref = sbxread(fname,refIDX,1);
ref = squeeze(ref(2,:,:));
ref = ref(top:end-bottom,left:end-right);

% Initialize array to hold aligned images and set starting index
int = uint16(0);
redData(1:col,1:row,1:setIDX) = int;
greenData(1:col,1:row,1:setIDX) = int;

% Initialize array to hold mean images
greenMeanCollection = zeros(col,row,numChunks);
redMeanCollection = zeros(col,row,numChunks);

% Initialize array to hold max images
greenMaxCollection(1:col,1:row,1:numChunks) = int;
%redMaxCollection(1:row,1:col,1:numChunks) = int;

for i = 1:numChunks
    % Set starting index
    k = ((i * setIDX) - setIDX)+ 1;
    
    % If on last chunk, truncate imgData array
    if numChunks > 1 && i == numChunks
        greenData = greenData(:,:,1:remainIDX);
        redData = redData(:,:,1:remainIDX);
        setIDX = remainIDX;
    end
    
    % Align frames in parallel and store in imgData matrix
    parfor j = 1:setIDX
        frame = k + j - 1;
        img = sbxread(fname,frame,1);
        greenImg = squeeze(img(1,:,:));
        redImg = squeeze(img(2,:,:));
        greenImg = greenImg(top:end-bottom,left:end-right);
        redImg = redImg(top:end-bottom,left:end-right);
        [disp,regRed] = imregdemons(redImg,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
        regGreen = imwarp(greenImg,disp);
        greenData(:,:,j) = regGreen;
        redData(:,:,j) = regRed;
    end

    % Store mean image of chunk
    greenMeanCollection(:,:,i) = mean(greenData,3);
    redMeanCollection(:,:,i) = mean(redData,3);
    
    % Store max image of chunk
    greenMaxCollection(:,:,i) = max(greenData,[],3);
    
    % Convert aligned frames back to raw sbx format
    [m,n,z] = size(greenData);
    greenData = intmax('uint16')-permute(greenData,[2 1 3]);
    redData = intmax('uint16')-permute(redData,[2 1 3]);
    greenData = reshape(greenData,[1, (m*n*z)]);
    redData = reshape(redData,[1, (m*n*z)]);
    
    % Determine whether to split channels and then write out as raw sbx binary
    if split == 1
        if i == 1
            greenFileID = fopen(['Aligned_green_' fname '.sbx'],'w');
            redFileID = fopen(['Aligned_red_' fname '.sbx'],'w');
            fwrite(greenFileID,greenData,'uint16');
            fwrite(redFileID,redData,'uint16');
            fclose(greenFileID);
            fclose(redFileID);
        else
            greenFileID = fopen(['Aligned_green_' fname '.sbx'],'a');
            redFileID = fopen(['Aligned_red_' fname '.sbx'],'a');
            fwrite(greenFileID,greenData,'uint16');
            fwrite(redFileID,redData,'uint16');
            fclose(greenFileID);
            fclose(redFileID);
        end
        
    else
        combinedData(1:2:end) = greenData;
        combinedData(2:2:end) = redData;
        if i == 1
            fileID = fopen(['Aligned_' fname '.sbx'],'w');
            fwrite(fileID,combinedData,'uint16');
            fclose(fileID);
        else
            fileID = fopen(['Aligned_' fname '.sbx'],'a');
            fwrite(fileID,combinedData,'uint16');
            fclose(fileID);
        end
    end
        
    % Reshape imgData array back to MxNxZ
    greenData = reshape(greenData,m,n,z);
    redData = reshape(redData,m,n,z);
end

% Calculate and save max projection image
greenMaxProjection = max(greenMaxCollection,[],3);
imwrite(greenMaxProjection,['MAX_green_' fname '.tif'],'tif');

% Calculate total mean image
greenWeightedMean(1:col,1:row,1:numChunks) = 0;
redWeightedMean(1:col,1:row,1:numChunks) = 0;
for i = 1:numChunks
    greenWeightedMean(:,:,i) = greenMeanCollection(:,:,i)*weightIndex(i);
    redWeightedMean(:,:,i) = redMeanCollection(:,:,i)*weightIndex(i);
end
    greenMeanImg = (sum(greenWeightedMean,3))/maxIDX;
    redMeanImg = (sum(redWeightedMean,3))/maxIDX;
    
% Write averaged red channel to file
imwrite(uint16(redMeanImg),['AVG_red_' fname '.tif'],'tif');

% Write the metadata file, modify fields for newly cropped dimensions
load([fname '.mat']);
info.originalRecordsPerBuffer = originalRecordsPerBuffer;
if info.scanmode == 0
    info.recordsPerBuffer = m/2;
else
    info.recordsPerBuffer = m;
end
info.sz = [m n];
if split == 1
    info.channels = 2;
    save(['Aligned_green_' fname '.mat'],'info');
    info.channels = 3;
    save(['Aligned_red_' fname '.mat'],'info');
else
    save(['Aligned_' fname '.mat'],'info');
end

% Calculate standard deviation for green channel and write to file
if split == 1
    for i = 1:maxIDX
        dRead = double(squeeze(sbxread(['Aligned_green_' fname],i,1)));
        img = (dRead - greenMeanImg).^2;
        if i == 1
            v = img;
        else
            v = v+img;
        end    
    end
else
    for i = 1:maxIDX
        dRead = (sbxread(['Aligned_' fname],i,1));
        dRead = double(squeeze(dRead(1,:,:)));
        img = (dRead - greenMeanImg).^2;
        if i == 1
            v = img;
        else
            v = v+img;
        end    
    end
end
    
varianceImg = v/maxIDX;
stdDevImg = sqrt(varianceImg);
stdDevImg = uint16(stdDevImg);
imwrite(stdDevImg,['STD_green_' fname '.tif'],'tif');

alignTime = toc;
fprintf('Aligned all %d frames in %d seconds.\n', maxIDX, alignTime);

fclose all;

end


