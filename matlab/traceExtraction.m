function traceArray = traceExtraction(fname,ROI_start,ROI_end)

tic

sbx = sbxread(fname,1,1);
global info;

row = info.sz(1);
col = info.sz(2);
start = (floor(ROI_start/col) * col);
ending = (ceil(ROI_end/col) * col);
beginLength = ROI_start - start;
endLength = ending - ROI_end;
width = col - beginLength - endLength;
height = (ending - start)/col;

info.fid = fopen([fname '.sbx']);
fseek(info.fid,((ROI_start*2)-2),'cof');
%fseek(info.fid,((k-1)*info.nsamples),'bof'); 

int = uint16(0);
traceArray(1:info.max_idx) = int;
frameROI(1,1:width,1:height) = int;

% Get mean value of all ROI values for all frames and store in traceArray
for j = 1:info.max_idx
    % Get frame ROI values
    for i = 1:height
        frameROI(:,:,i) = fread(info.fid,width,'uint16=>uint16');
        frameROI = intmax('uint16') - frameROI;
        fseek(info.fid,((endLength + beginLength) * 2),'cof');
    end
    traceArray(j) = mean(frameROI(:));
    fseek(info.fid,(row*col*2),'cof');
end

toc

end


        
    
    