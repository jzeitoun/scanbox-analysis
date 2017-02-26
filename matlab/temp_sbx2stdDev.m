function temp_sbx2stdDev(fname,N)

z = sbxread(fname,1,1);
global info;

if nargin > 1
    maxIDX = min(N,info.max_idx);   
else
    maxIDX = info.max_idx;
end

tic


col = info.sz(1);
row = info.sz(2);

% Determine if necessary to divide file into chunks and how many
frameSize = col * row * 2;
fileSize = frameSize * maxIDX;
chunkNumFrames = floor(100000000/frameSize); % using 5GB chunks
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

% Initialize array to hold aligned images and set starting index
int = uint16(0);
imgData(1:col,1:row,1:setIDX) = int;

% Initialize array to hold mean images
meanCollection = zeros(col,row,numChunks);
maxCollection(1:col,1:row,1:numChunks) = int;

for i = 1:numChunks
    % Set starting index
    k = ((i * setIDX) - setIDX)+ 1;
    
    % If on last chunk, truncate imgData array
    if numChunks > 1 && i == numChunks
        imgData = imgData(:,:,1:remainIDX);
        setIDX = remainIDX;
    end
    
    % Read frames in parallel and store in imgData matrix
    parfor j = 1:setIDX
        frame = k + j - 1;
        img = squeeze(sbxread(fname,frame,1));
        imgData(:,:,j) = img;
    end

    % Store mean image of chunk
    meanCollection(:,:,i) = mean(imgData,3);
    maxCollection(:,:,i) = max(imgData,[],3);
    
end

% Calculate total mean image 
weightedMean(1:col,1:row,1:numChunks) = 0;

% Max
maxImage = max(maxCollection,[],3);
imwrite(maxImage,['MAX_' fname '.tif'],'tif');

for i = 1:numChunks
    weightedMean(:,:,i) = meanCollection(:,:,i)*weightIndex(i);
end

meanImg = (sum(weightedMean,3))/maxIDX;

% Calculate standard deviation and write to file
for i = 1:maxIDX
    dRead = double(squeeze(sbxread(fname,i,1)));
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


