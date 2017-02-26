function sbx_splitChannels(fname,N)

z = sbxread(fname,1,1);
global info;
originalRecordsPerBuffer = info.recordsPerBuffer;
row = info.sz(1);
col = info.sz(2);

if nargin > 1
    maxIDX = min(N,info.max_idx);   
else
    maxIDX = info.max_idx;
end

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
else
    setIDX = maxIDX;
    numChunks = 1;
end

% Initialize array to hold aligned images and set starting index
int = uint16(0);
greenData(1:row,1:col,1:setIDX) = int;
redData(1:row,1:col,1:setIDX) = int;

tic;

for i = 1:numChunks
    % Set starting index
    k = ((i * setIDX) - setIDX)+ 1;
    
    % If on last chunk, truncate imgData array
    if numChunks > 1 && i == numChunks
        greenData = greenData(:,:,1:remainIDX);
        redData = redData(:,:,1:remainIDX);
        setIDX = remainIDX;
    end
    
    % Deinterleave frames in parallel and store in imgData matrix
    parfor j = 1:setIDX
        frame = k + j - 1;
        img = sbxread(fname,frame,1);
        greenImg = squeeze(img(1,:,:));
        redImg = squeeze(img(2,:,:));
        greenData(:,:,j) = greenImg;
        redData(:,:,j) = redImg;
    end

    % Convert aligned frames back to raw sbx format
    [m,n,z] = size(greenData);
    greenData = intmax('uint16')-permute(greenData,[2 1 3]);
    greenData = reshape(greenData,[1, (m*n*z)]);
    redData = intmax('uint16')-permute(redData,[2 1 3]);
    redData = reshape(redData,[1, (m*n*z)]);
    
    % Write file back out as raw sbx binary
    if i == 1
        greenFileID = fopen(['Green_' fname '.sbx'],'w');
        redFileID = fopen(['Red_' fname '.sbx'],'w');
        fwrite(greenFileID,greenData,'uint16');
        fwrite(redFileID,redData,'uint16');
        fclose(greenFileID);
        fclose(redFileID);
    else
        greenFileID = fopen(['Green_' fname '.sbx'],'a');
        redFileID = fopen(['Red_' fname '.sbx'],'a');
        fwrite(greenFileID,greenData,'uint16');
        fwrite(redFileID,redData,'uint16');
        fclose(greenFileID);
        fclose(redFileID);
    end
    
    % Reshape imgData array back to MxNxZ
    greenData = reshape(greenData,m,n,z);
    redData = reshape(redData,m,n,z);
end

toc;

% Write the metadata file, modify fields for newly cropped dimensions
load([fname '.mat']);
info.channels = 2;
save(['Green_' fname '.mat'],'info');
info.channels = 3;
save(['Red_' fname '.mat'],'info');