function sbx2tif_gray(fname,N)
% Converts sbx raw data to grayscale tiff.
% No alignment of the data when using this function.
% If converting a 2 channel file, be sure to make the necessary changes in
% the specified sections below.

tic;

z = sbxread(fname,1,1);
global info;

if nargin > 1
    maxIDX = min(N,info.max_idx);   
else
    maxIDX = info.max_idx;
end

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

% Use for single channel files
%img = squeeze(sbxread(fname,1,1));

% Use for 2 channel files; for img(x,:,:), x = 1 to save green; x = 2 to save red
img = sbxread(fname,1,1);
img = squeeze(img(1,:,:));

tiff.write(img);

for i = 2:info.max_idx
    % Use for single channel files
    %img = squeeze(sbxread(fname,i,1));

    % Use for 2 channel files; for img(x,:,:), x = 1 to save green; x = 2 to save red
    img = sbxread(fname,i,1);
    img = squeeze(img(1,:,:));
    
    tiff.writeDirectory();
    tiff.setTag(tagstruct);
    tiff.write(img);
end

tiff.close;

toc;

end