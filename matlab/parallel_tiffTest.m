function parallel_tiffTest(fname)

tic;

z = sbxread(fname,1,1);
global info;

ref = mean(squeeze(sbxread(fname,1,200)),3);
%ref = squeeze(sbxread(fname,refidx,1));

col = info.sz(1);
row = info.sz(2);

% initialize matrix to hold aligned data
imgData = uint16(zeros(col,row));

% align frames in parallel and store in imgData matrix
parfor i = 1:info.max_idx
    img = squeeze(sbxread(fname,i,1));
    [~,imgA] = imregdemons(img,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
    imgData(:,:,i) = imgA;
end

% create tif object
tiff = Tiff([fname '.tif'],'w8');

% create tif tag structure
tagstruct.ImageLength = info.sz(1);
tagstruct.ImageWidth = info.sz(2);
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.BitsPerSample = 16;
tagstruct.Compression = Tiff.Compression.PackBits;
tagstruct.SamplesPerPixel = 1;
tagstruct.RowsPerStrip = 16;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB';

% set tif taggs
tiff.setTag(tagstruct);

% write first aligned frame to tif object
img = imgData(:,:,1);
tiff.write(img);

% write remaining aligned frame to tif object
for i = 2:info.max_idx
    img = imgData(:,:,i);
    tiff.writeDirectory();
    tiff.setTag(tagstruct);
    tiff.write(img);
end

tiff.close;

toc;

end