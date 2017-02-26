global sbconfig;

% User dependent settings

sbconfig.scanbox_com    = 'COM3';       % scanbox communication port
sbconfig.laser_com      = 'COM1';       % laser serial communication
sbconfig.laser_type     = '';           % laser type (CHAMELEON or '' if controlling with manufacturer's GUI) 
sbconfig.tri_knob       = 'COM5';       % serial for scanknob (empty if not present)

sbconfig.tri_com        = 'COM4';       % motor controller communication
sbconfig.tri_baud       = 57600;        % baud rate to motor controller
sbconfig.quad_com       = '';           % monitor quadrature encoder of rotating platform 
sbconfig.quad_cal       = 20*pi/1440;   % cm/count (r=10cm platform)
sbconfig.idisplay       = 2;            % take care of serial/ethernet callbacks every idisplay frames
sbconfig.deadband       = [5 5];        % size of laser deadband at margins
sbconfig.datadir        = 'Z:\Default'; % default data directory
sbconfig.autoinc        = 1;            % auto-increment experiment # field
sbconfig.freewheel      = 1;            % enable freewheeling of motors (power will be turned off upon reaching position)
sbconfig.eyetracker_2    = 1;            % enable ball tracker (0 - disabled, 1- enabled) % modified by JZ, original: balltracker
sbconfig.eyecamera_2     = 'M1280';      % model of ball camera % modified by JZ, original: ballcamera
sbconfig.eyetracker_1     = 1;            % enable eye tracker  (0 - disabled, 1- enabled) % modified by JZ, original: eyetracker
sbconfig.eyecamera_1      = '131B';       % model of eye camera % modified by JZ, original: eyecamera
sbconfig.portcamera     = 1;            % enable path camera (0 - disabled, 1- enabled)
sbconfig.pathcamera     = 'C2590';
sbconfig.pathlr         = 0;            % switch camera image lr? (Use camera hardware option if availabe!)
sbconfig.imask          = 4;            % interrupt masks (3 TTL event lines are availabe) (Original: 3)
sbconfig.pockels_lut    = uint8([]);    % your look up table (must have exactly 256 entries)
sbconfig.mmap           = 1;            % enable/disable memory mapped file stream
sbconfig.optocal = [];                  % optotune calibration or []; Default = [6.3176e-05 0.0732 1.3162]
sbconfig.slm = 0;                       % enable/disable SLM display
sbconfig.phys_cores = uint16(feature('numCores'));  % total number of physical cores
sbconfig.cores_uni = sbconfig.phys_cores;           % number of cores in unidirectional scanning 
sbconfig.cores_bi  = sbconfig.phys_cores;           % number of cores in bidirectional scanning 
sbconfig.etl = 860;                                 % default ETL value
sbconfig.resfreq = [7891 7906 7913 7918 7920 7921 7922 7923 7923 7923 7924 7924 7924]; %7931; %7930; % modified by JZ, converted to lookup table to accomodate changes in resfreq at different mags                  % resonant freq for your mirror (Original: 7930) (Measured: 7914) 
sbconfig.lasfreq = 80158000;                        % laser freq at 920nm (Original: 801580000)(Measured: 80584600)
sbconfig.knobbyreset = 1;                           % automatically reset knobby upon start up? (beta)
sbconfig.firmware = '3.4';                          % required firmware version 3.4

% PLEASE do not change these settings unless you understand what your are doing!

sbconfig.trig_level     = 160;          % trigger level
sbconfig.trig_slope     = 0;            % trigger slope (0 - positive, 1 - negative)
sbconfig.nbuffer = 16;                  % number of buffers in ring (depends on your memory)
sbconfig.bishift = [0    0    0    0    0    0   0   0   0    0   0   0   0  ]; % sub pixel shift (integer >=0)
sbconfig.stream_host = '';
sbconfig.stream_port = 7001;            % where to stream data to...
sbconfig.rtmax = 30000;                 % maximum real time data points
sbconfig.gpu_pages = 250;               % max number of gpu pages (make it zero if no GPU desired)
sbconfig.gpu_interval = 10;             % delta frames between gpu-logged frames
sbconfig.gpu_dev = 1;                   % gpu device #
sbconfig.nroi_auto = 4;                 % number of ROIs to track in auto alignment
sbconfig.nroi_auto_size = [64 68 72 76 82 86 92 96 102 108 114 122 128];  % size of ROIs for diffnt mag settingssbconfig.nroi_parallel = 0; 
sbconfig.nroi_parallel = 0;             % use parallel for alignment
sbconfig.stream_host = 'localhost';     % stream to this host name
sbconfig.stream_port = 30000;           % and port...

sbconfig.obj_length = 98000;            % objective length from center of rotation to focal point [um] 
sbconfig.qmotion        = 0;            % quadrature motion controller 
sbconfig.qmotion_com    = '';           % comm port for quad controller
sbconfig.ephys = 0;                     % enable ephys data acquisition
sbconfig.ephysRate = 32000;             % sampling rate (samples/sec)

sbconfig.hsync_sign    = 0;             % 0-normal, 1-flip horizontal axis
sbconfig.gain_override = 1;             % override default gain settings?

sbconfig.gain_galvo = [1.0 1.3 1.6 2.0 2.5 3.0 4.0 8.0 10.0 14.0 18.0 22.0 25.0]; % modified by JZ, original: logspace(log10(1),log10(8),13);  % more options now!
sbconfig.gain_resonant = sbconfig.gain_galvo;  % Original = 1.4286
sbconfig.dv_galvo      = 64;            % dv per line (64 is the maximum) -- don't touch!

sbconfig.wdelay = 50;                   % warmup delay for resonant scanner (in tens of ms)

% Bishift calibration saved
sbconfig.bishift = [-10 -9 -7 -3 -3 0 3 7 14 21 30 40 58 ];
% Bishift calibration saved
sbconfig.bishift = [-10 -9 3 -3 -3 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-10 -9 3 -3 -22 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-10 -9 3 -3 -22 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-11 -9 3 -3 -22 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-11 -9 3 -3 -3 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 -9 3 -3 -3 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 3 -3 -3 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 28 -3 -3 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 28 -3 -3 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 28 22 -3 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 28 22 7 0 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 28 22 7 -5 3 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 28 22 7 -5 -14 -41 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 28 22 7 -5 -14 -22 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 28 22 7 -5 -14 -22 14 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-9 3 28 22 7 -5 -14 -22 -32 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-13 3 28 22 7 -5 -14 -22 -32 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-13 3 28 22 7 -5 -14 -22 -28 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-13 3 28 22 7 -5 -8 -22 -28 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-13 3 28 22 7 -5 -8 -22 -28 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-13 3 28 22 7 -5 -8 -22 -28 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-13 3 28 6 7 -5 -8 -22 -28 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-6 3 28 6 7 -5 -8 -22 -28 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-7 3 28 6 7 -5 -8 -22 -28 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-7 13 28 0 7 -5 -8 -22 -28 -3 30 40 -95 ];

% Bishift calibration saved
sbconfig.bishift = [-18 13 28 0 7 -5 -8 -22 -28 -3 30 40 -197 ];

% Bishift calibration saved
sbconfig.bishift = [-17 13 16 -5 7 -5 -8 -22 -28 -3 30 40 -197 ];

% Bishift calibration saved
sbconfig.bishift = [-17 13 16 -2 7 -23 -8 -22 -28 -3 30 40 -197 ];

% Bishift calibration saved
sbconfig.bishift = [-19 13 17 3 7 -23 -8 -22 -28 -3 30 40 -197 ];

% Bishift calibration saved
sbconfig.bishift = [-19 13 17 1 7 -23 -8 -22 -28 -3 30 40 -197 ];
