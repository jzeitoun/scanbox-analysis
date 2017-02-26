function debugger_generator(fname)

% dimensions of movie
m = 1024;
n = 796;
z = 49568;

% frame center indices
a = round(m/3);
b = 2*a;
c = round(n/3);
d = 2*c;

% create lookup table for conditions
conditions = (1:80);
conditions = repmat(conditions,1,8);

% create file
fileID = fopen([fname '.sbx'],'w');

% initialize parameters to determine skip and starting frame
skip = 46;
fill = uint16(1);
movie(1:m,1:n,1:31) = fill;
skip46(1:m,1:n,1:46) = fill;
data46 = intmax('uint16')-permute(skip46,[2 1 3]);
data46 = reshape(data46,[1, (m*n*46)]);
skip47(1:m,1:n,1:47) = fill;
data47 = intmax('uint16')-permute(skip47,[2 1 3]);
data47 = reshape(data47,[1, (m*n*47)]);
skip80(1:m,1:n,1:maxIDX) = fill;

for i = 1:640
    movie(a:b,c:d,:) = conditions(i);
    data = intmax('uint16')-permute(movie,[2 1 3]);
    data = reshape(data,[1, (m*n*31)]);
    fwrite(fileID,data,'uint16');
    
    % alternate between 46 and 47 frames for offtime and drop 4 frames
    % after every repetition
    if count == 80
        maxIDX = skip - 4;
        
        data80 = intmax('uint16')-permute(skip80,[2 1 3]);
        data80 = reshape(data80,[1, (m*n*47)]);    
    elseif skip == 46
        fwrite(fileID,data46,'uint16');
        skip = 47;
    else
        fwrite(fileID,data47,'uint16');
        skip = 46;
    end
end
        
end