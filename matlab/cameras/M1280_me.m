
function M1280_me(x)

% Set exposure to a fraction of the maximum

global dalsa_src;

dalsa_src.ExposureTimeAbs = 66000 * x;