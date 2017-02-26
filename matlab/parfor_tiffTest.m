function parfor_tiffTest(fname)

tic;

z = sbxread(fname,1,1);
global info;

refidx = 10;
ref = squeeze(sbxread(fname,refidx,1));
%for i = 1:numDiv+1
%    if i == 1
%        for j = 1:599
            
%            q = squeeze(sbxread(fname,j,1));
%            [~,qA] = imregdemons(q,ref,[32 16 8 4],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',4,'DisplayWaitBar',false);
%            q = qA;
    

tiff = Tiff([fname '.tif'],'w8');

tagstruct.ImageLength = info.sz(1);
tagstruct.ImageWidth = info.sz(2);
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.BitsPerSample = 16;
tagstruct.Compression = Tiff.Compression.PackBits;
tagstruct.SamplesPerPixel = 1;
tagstruct.RowsPerStrip = 16;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB';

tiff.setTag(tagstruct);

img = squeeze(sbxread(fname,1,1));
tiff.write(img);

for i = 2:info.max_idx
    img = squeeze(sbxread(fname,i,1));
    tiff.writeDirectory();
    tiff.setTag(tagstruct);
    tiff.write(img);
end

tiff.close;

toc;

end