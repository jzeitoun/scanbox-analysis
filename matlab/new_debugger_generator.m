function new_debugger_generator(fname)
% creates debugger movie assuming 2 on 3 off

fileID = fopen([fname '.sbx'],'a');

% desired framerate; desired repetitions; desired length in seconds
frameRate = 15.49;
%setFrameRate = round(frameRate,1);
length = 3205.87;
numReps = 8;

% dimensions of movie
m = 1024;
n = 796;
totalFrames = round(frameRate * (length+3));
%z = totalFrames/numReps;
%repLength = length/numReps;

% frame center indices
a = round(m/3);
b = 2*a;
c = round(n/3);
d = 2*c;

% create conditions lookup table
numConditions = 80;
multiplier = round(intmax('uint16')/numConditions);
conditions = uint16(2:numConditions+1) * multiplier;
conditions = repmat(conditions,1,8);

% determine on/off start/end indices for 1 repetition
%onTimes = (0:5:repLength-1);
loaded = load([fname '_onTimes.mat']);
onTimes = loaded.on_times(:,2);
%offTimes = (2:5:repLength);
onStartIndices = round(onTimes*frameRate);
onStartIndices(1) = 1;
onEndIndices = round((onTimes+2)*frameRate);
offStartIndices = onEndIndices + 1;
offEndIndices = onStartIndices(2:end) - 1;
offEndIndices(640) = totalFrames;

% create fill
%fill = multiplier;

% create each trial and write to file
for i = 1:640
    % on phase
    z_on = offStartIndices(i) - onStartIndices(i);
    trial_on(1:m,1:n,1:z_on) = multiplier;
    trial_on(a:b,c:d,:) = conditions(i);
    data_on = intmax('uint16')-permute(trial_on,[2 1 3]);
    data_on = reshape(data_on,[1, (m*n*z_on)]);
    fwrite(fileID,data_on,'uint16');
    
    % off phase
    z_off = offEndIndices(i) - onEndIndices(i);
    trial_off(1:m,1:n,1:z_off) = multiplier;
    data_off = intmax('uint16')-permute(trial_off,[2 1 3]);
    data_off = reshape(data_off,[1, (m*n*z_off)]);
    fwrite(fileID,data_off,'uint16');
    
    % clear trials
    clear trial_off;
    clear trial_on;
    
end

% convert movie to sbx format
%data = intmax('uint16')-permute(movie,[2 1 3]);
%data = reshape(data,[1, (m*n*z)]);

% write to file
%for k = 1:numReps
%    fwrite(fileID,data,'uint16');
%end

end
    