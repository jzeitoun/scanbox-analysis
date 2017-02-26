function sbx_eye2tif(fname)

load([fname '.mat']);
data = squeeze(data);
data = uint16((double(data)/255)*65535);
[m n z] = size(data);

tiff = Tiff([fname '.tif'],'w8');

tagstruct.ImageLength = m;
tagstruct.ImageWidth = n;
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.BitsPerSample = 16;
tagstruct.Compression = Tiff.Compression.PackBits;
tagstruct.SamplesPerPixel = 1;
tagstruct.RowsPerStrip = 16;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB';

tiff.setTag(tagstruct);

first_frame = data(:,:,1);

tiff.write(first_frame);

for i = 2:z
    
    frame = data(:,:,i);
        
    tiff.writeDirectory();
    tiff.setTag(tagstruct);
    tiff.write(frame);
end

tiff.close;