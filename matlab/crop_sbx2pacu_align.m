function crop_sbx2pacu_align(fname,N)

z = sbxread(fname,1,1);
global info;

if nargin > 1
    maxIDX = min(N,info.max_IFD);   
else
    maxIDX = info.max_IFD;
end

tic

% Cropping margins
top = 20;
bottom = 20;
left = 130;
right = 40;

col = info.sz(1)-(top + bottom - 1);
row = info.sz(2)-(left + right - 1);

% Determine if necessary to divide file into chunks and how many
frameSize = col * row * 2;
fileSize = frameSize * maxIDX;
chunkNumFrames = floor(5000000000/frameSize); % using 5GB chunks
chunkNumFramesSize = frameSize * chunkNumFrames;
numChunks = fileSize/chunkNumFramesSize;
if numChunks > 1
    numChunks = floor(numChunks);
    setIDX = chunkNumFrames;
    remainingSize = fileSize - (numChunks*chunkNumFramesSize);
    remainIDX = remainingSize/(frameSize);
    numChunks = numChunks + 1;
else
    setIDX = maxIDX;
    numChunks = 1;
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
imgData(col,row,setIDX) = int;

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

    % Convert aligned frames back to raw sbx format
    [m,n,z] = size(imgData);
    imgData = intmax('uint16')-permute(imgData,[2 1 3]);
    imgData = reshape(imgData,[info.nchan, (m*n*z)]);

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

% Write the metadata file, modify fields for newly cropped dimensions
load([fname '.mat']);
if info.scanmode == 0
    info.recordsPerBuffer = m/2;
else
    info.recordsPerBuffer = m;
end
info.sz = [m n];
save(['Aligned_' fname '.mat'],'info');

alignTime = toc;
fprintf('Aligned all %d frames in %d seconds.\n', maxIDX, alignTime);

end


