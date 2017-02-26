function varargout = scanbox(varargin)
% SCANBOX MATLAB code for scanbox.fig
%      SCANBOX, by itself, creates a new SCANBOX or raises the existing
%      singleton*.
%
%      H = SCANBOX returns the handle to a new SCANBOX or the handle to
%      the existing singleton*.
%
%      SCANBOX('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SCANBOX.M with the given input arguments.
%
%      SCANBOX('Property','Value',...) creates a new SCANBOX or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before scanbox_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to scanbox_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help scanbox

% Last Modified by GUIDE v2.5 02-Dec-2016 14:01:21

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @scanbox_OpeningFcn, ...
    'gui_OutputFcn',  @scanbox_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before scanbox is made visible.
function scanbox_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to scanbox (see VARARGIN)

% Choose default command line output for scanbox
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% check min release
mver = ver('Matlab');
myr = strsplit(mver.Date,'-');
if(str2double(myr{end})<2015)
    if(isempty(strfind(mver.Release,'R2015')))
        error('This version of Scanbox requires R2015a or later');
    end
end

% Set high priority

q = priority('sh');

% Make sure ethernet connection to outside world is disabled...

[~, ~] = system('netsh interface set interface World DISABLED');

% Configuration options and startup

istep = 1;
cprintf('\n');
cprintf('*blue','Scanbox Yeti (v3.4) - by Dario Ringach (darioringach@me.com)\n');
cprintf('blue','Visit the blog at: ')
cprintf('hyperlink','https://wordpress.org/\n')
cprintf('\n');
pause(2);


cprintf('*comment','[%02d] Reading configuration file\n',istep); istep=istep+1;
scanbox_config;     % configuration file

% check if optocal LUT needs to be computed

if(~isempty(sbconfig.optocal))
    sbconfig.optolut = uint16(polyval(sbconfig.optocal,0:1760));
end

% gray out optional boxes...

cprintf('*comment','[%02d] Setting up control panels\n',istep); istep=istep+1;

% analog out

% global ao;
% daqreset;
% ao = daq.createSession('ni')
% addAnalogOutputChannel(ao,'Dev1',1,'Voltage');


% ephys and/or slm


if(sbconfig.ephys)
    cprintf('*comment','[%02d] Setting up ephys device\n',istep); istep=istep+1;
    daqreset;
    global ephys;
    ephys = daq.createSession('ni');
    ephys.Rate = sbconfig.ephysRate;
    ephys.IsContinuous = true;
    addCounterInputChannel(ephys,'Dev1','ctr1','EdgeCount');
    addAnalogInputChannel(ephys,'Dev1',1,'Voltage');
    addlistener(ephys,'DataAvailable', @ephysdata);
end

if(sbconfig.slm)
    cprintf('*comment','[%02d] Setting up SLM device\n',istep); istep=istep+1;
    daqreset;
    global slms;
    slms = daq.createSession('ni');
    slms.Rate = 1000;
    addAnalogOutputChannel(slms,sbconfig.slmdev,'ao1','Voltage');
end


% network stream

if(isempty(sbconfig.stream_host))
    set(handles.networkstream,'Enable','off');
    cprintf('*comment','[%02d] Network stream is OFF\n',istep); istep=istep+1;
else
    cprintf('*comment','[%02d] Network stream is ON\n',istep); istep=istep+1;

    global stream_udp;
    
    if(~isempty(stream_udp))
        fclose(stream_udp);
        stream_udp = [];
    end
end


if(sbconfig.eyetracker_2 == 0) % modified by JZ, original: balltracker
    ch = get(handles.ballpanel,'children');
    for(i=1:length(ch))
        try
            set(ch(i),'Enable','off');
        catch
        end
    end
end


if(sbconfig.eyetracker_1 == 0) % modified by JZ, original: eyetracker
    ch = get(handles.eyepanel,'children');
    for(i=1:length(ch))
        try
            set(ch(i),'Enable','off');
        catch
        end
    end
end

if(isempty(sbconfig.laser_type))
    ch = get(handles.uipanel11,'children');
    for(i=1:length(ch))
        try
            set(ch(i),'Enable','off');
        catch
        end
    end
    set(handles.lstatus,'String','Use the laser''s native GUI for control');
    handles.pockval.Enable = 'on';
    handles.powertxt.Enable = 'on';
end


% position by knobby? disable panel

% position panel is now gone

% if(~isempty(sbconfig.tri_knob))
%     c = get(handles.uipanel9,'Children');
%     set(c,'Enable','off');
% end


% default directory

global datadir
handles.dirname.String = sbconfig.datadir;
datadir = sbconfig.datadir;

% delete any hanging communication objects

cprintf('*comment','[%02d] Initializing instruments\n',istep); istep=istep+1;

delete(instrfindall);
pause(0.2);

global sb tri laser optotune sb_server

sb = [];
tri = [];
laser = [];
optotune = [];
sb_server = [];

% Open communication lines


cprintf('*comment','[%02d] Opening Scanbox\n',istep); istep=istep+1;

try
    sb_open;
catch
    % delete(10);
    uiwait(errordlg('Cannot communicate with scanbox. Please fix! Matlab will close.','scanbox','modal'));
    exit;
end

if isfield(sbconfig,'firmware') && ~isempty(sbconfig.firmware)
        if strcmp(sbconfig.firmware,sb_version)
            cprintf('*comment','[%02d] Matching firmware version\n',istep); istep=istep+1;
        else
            uiwait(errordlg('Firmware version mismatch! Please fix! Matlab will close.','scanbox','modal'));
            exit;
        end
end

sb_optotune_active(0);      % make sure optotune is not active
sb_current_power_active(0); % nor is the link between optotune and power


cprintf('*comment','[%02d] Interrupt mask = %d\n',istep,sbconfig.imask); istep=istep+1;
sb_imask(sbconfig.imask);

if(sbconfig.gain_override>0)
    cprintf('*comment','[%02d] Set custom x,y gains\n',istep); istep=istep+1;
    sb_galvo_dv(sbconfig.dv_galvo);
    for k=1:length(sbconfig.gain_resonant)
        sb_set_mag_x_i(k-1,sbconfig.gain_resonant(k));
        sb_set_mag_y_i(k-1,sbconfig.gain_galvo(k));
    end
end

if(length(sbconfig.pockels_lut)==256)
    cprintf('*comment','[%02d] Loading Pockels LUT\n',istep); istep=istep+1;
    for(i=1:256)
        sb_pockels_lut(i,sbconfig.pockels_lut(i));
    end
end

cprintf('*comment','[%02d] Set HSYNC sign\n',istep); istep=istep+1;

sb_hsync_sign(sbconfig.hsync_sign);

cprintf('*comment','[%02d] Default to normal resonant mode\n',istep); istep=istep+1;
sb_continuous_resonant(0);

cprintf('*comment','[%02d] Default warm up time\n',istep); istep=istep+1;
sb_warmup_delay(sbconfig.wdelay);

% cprintf('*comment','[%02d] Reset optotune\n',istep); istep=istep+1;
% sb_current(0);
% 
% if(isempty(sbconfig.optocal))
%     handles.ot_txt.String = '0000';
% else
%     handles.ot_txt.String = '0 um';
%     handles.optomax.String = '100';
% end

% Set optotune

cprintf('*comment','[%02d] Set Default ETL value\n',istep);istep=istep+1;
handles.optoslider.Value = sbconfig.etl;
optoslider_Callback(handles.optoslider, [], handles);

cprintf('*comment','[%02d] Opening motor controller\n',istep); istep=istep+1;
tri_open;

cprintf('*comment','[%02d] Opening laser communication\n',istep); istep=istep+1;


try
    laser_open;
    if( strcmp(sbconfig.laser_type,'DISCOVERY') )

        handles.gddslider.Enable = 'on';

        r = laser_send('?GDDMIN');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Min = val;
        
        r = laser_send('?GDDMAX');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Max= val;
        
        r = laser_send('?GDD');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Value= val;
        handles.gddtxt.String = r{end};
        
        handles.gddtxt.Enable = 'on';
        handles.fshutter.Enable = 'on';

    end
catch
    %delete(10)
    error('Scanbox:LaserComm', ...
        '\nCannot communicate with laser!\nPlease check:\n -Serial cable\n -COM port in scanbox_config\n\n');
end

% open quad

if(~isempty(sbconfig.quad_com))
    cprintf('*comment','[%02d] Opening quadrature encoder\n',istep); istep=istep+1;
    quad_open;
end

% open 3d mouse if knobby not present....

if(isempty(sbconfig.tri_knob))
    cprintf('*comment','[%02d] Setting up 3dmouse driver\n',istep); istep=istep+1;
    import mouse3D.*
    global mouseDrv;
    mouseDrv = mouse3Ddrv; %instantiate driver object
    addlistener(mouseDrv,'SenState',@mousedrv_cb);
end

cprintf('*comment','[%02d] Opening UDP communications\n',istep); istep=istep+1;

udp_open;

cprintf('*comment','[%02d] Moving port camera mirror into place\n',istep); istep=istep+1;

sb_mirror(1);       % move mirror out of the way...

warning('off');

%
global opto2pow

opto2pow = [];

% ttlonline

global ttlonline;
ttlonline=0;

global zstack_running;
zstack_running = 0;

% motor variables init...

global axis_sel origin motor_gain mstep dmpos motormode mpos motorstate;

motormode = 1; % normal

motor_gain = [(2000/400/32)/2  ((.02*25400)/400/64)  ((.02*25400)/400/64) (0.0225/64)];  % z x y th

motorstate = [0 0 0 0];

axis_sel = 2; % select x axis to begin with

%mstep = [500 2000 2000 500];  % initialize with step sizes for coarse...

mstep = [400 1575 1575 400];

% set velocity and acceleration for motor 4 to control laser power

r = tri_send('SAP',4,4,10);        %% set max vel and acc for platform
r = tri_send('SAP',5,4,10);

try
    for(i=0:3)
        r = tri_send('GAP',1,i,0);       %% zero and set origin - was MVP
        origin(i+1) = r.value;
        switch i
            
            case {0,3}
                r = tri_send('SAP',4,i,400);    %% max vel accel - was 2000
                r = tri_send('SAP',5,i,400);
                
            case {1,2}
                
                r = tri_send('SAP',4,i,800);    %% max vel accel - was 2000
                r = tri_send('SAP',5,i,400);     %% was 1600
        end
        
        r = tri_send('SAP',140,i,6);     %% 64 microsteps (changed default in 610 board)
        r = tri_send('SAP',204,i,sbconfig.freewheel);     %% keep the power up...
        
    end
catch
    %delete(10)
    error('Scanbox:MotorComm', ...
        '\nCannot communicate with motor controller!\nPlease check:\n -Serial cable\n -COM port in scanbox_config\n -Power cycle controller\n\n');
end


dmpos = origin;                      %% desired motor position is the same as the origin

mpos = cell(1,4);                      %% reset memory
for(i=1:4)
    mpos{i} = dmpos;
end


% set(handles.xpos,'String','0.00')
% set(handles.ypos,'String','0.00')
% set(handles.zpos,'String','0.00')
% set(handles.thpos,'String','0.00')

% z-stack

global z_top z_bottom z_steps z_size z_vals;

z_top = 0;
z_bottom = 0;
z_steps = 0;
z_vals = 0;

% Pockels levels...

cprintf('*comment','[%02d] Default Pockels levels\n',istep); istep=istep+1;
sb_pockels(0,0);
cprintf('*comment','[%02d] Default Deadband\n',istep); istep=istep+1;

sb_deadband_period(round(24e6/sbconfig.resfreq(get(handles.magnification,'Value'))/2)); % modified by JZ, original: sbconfig.resfreq
sb_deadband(sbconfig.deadband(1),sbconfig.deadband(2));

handles.deadleft.Value = sbconfig.deadband(1);
handles.deadright.Value = sbconfig.deadband(2);


global scanmode;
cprintf('*comment','[%02d] Default Unidirectional mode\n',istep); istep=istep+1;

sb_unidirectional;
scanmode = 1;   % default is unidirectional

% ball tracker initialization % modified by JZ: eye tracker 2
% initialization
%

cprintf('*comment','[%02d] Initializing image acquisition\n',istep); istep=istep+1;

cprintf('comment','[%02d] Setting Line2 tiggger source in all DALSA cameras (please wait)\n',istep); istep=istep+1;

imaqreset;

q = gigecamlist;
if ~isempty(q)  % maybe there are no cameras at all
    idx = find(strcmp('DALSA',q.Manufacturer));
    for i = idx'
        g = gigecam(q.SerialNumber{i});
        g.TriggerMode = 'on';
        g.TriggerSource = 'Line2';
        g.TriggerMode = 'off';
        delete(g);
    end
end

cprintf('*comment','[%02d] Configuring image aquisition\n',istep); istep=istep+1;

if(sbconfig.eyetracker_2 + sbconfig.eyetracker_1 + sbconfig.portcamera > 0) % modified by JZ, original: (sbconfig.balltracker + sbconfig.eyetracker + sbconfig.portcamera > 0)
    cprintf('*comment','[%02d] Getting camera information\n',istep); istep=istep+1;
    q = imaqhwinfo('gige');
end

if(sbconfig.eyetracker_2) % modified by JZ, original: balltracker
    cprintf('*comment','[%02d] Configuring eye camera 2\n',istep); istep=istep+1; % modified by JZ, original: '[%02d] Configuring ball camera\n'

    global wcam wcam_src wcam_roi;
    
    for(i=1:length(q.DeviceInfo))  % find ball camera % modified by JZ: finding eye camera 2
        if(~isempty(strfind(q.DeviceInfo(i).DeviceName,sbconfig.eyecamera_2)))  %% search for 1410 genie camera % modified by JZ, original: ballcamera
            q.DeviceInfo(i).DeviceName = '';        %% in case there  are two cameras with same number
            break;
        end
    end
    
    wcam = videoinput('gige', i, 'Mono8');
    wcam_src = getselectedsource(wcam);
    wcam_src.ReverseX = 'False';
    wcam_src.BinningHorizontal = 1; % modified by JZ, original: 2
    wcam_src.BinningVertical = 1; % modified by JZ, original: 2
    wcam_src.ExposureTimeAbs = 7000; % modified by JZ, original: 7000
    wcam_src.AcquisitionFrameRateAbs = 20.0;
    wcam.FramesPerTrigger = inf;
    wcam.ReturnedColorspace = 'grayscale';
    wcam_roi = [0 0 wcam.VideoResolution];
    
    
end

% dalsa (or other port camera) config

if(sbconfig.portcamera)
    global dalsa dalsa_src;
    cprintf('*comment','[%02d] Configuring camera path\n',istep); istep=istep+1;

    for(i=1:length(q.DeviceInfo))
        if(~isempty(strfind(q.DeviceInfo(i).DeviceName,sbconfig.pathcamera)))  %% search for imperx B2020M camera
            q.DeviceInfo(i).DeviceName = '';
            break;
        end
    end
    
    dalsa = videoinput('gige', i, 'BayerRG8'); % Modified by JZ, original: 'Mono8'
    dalsa.FramesPerTrigger = inf;
    
    eval(sprintf('%s_init',sbconfig.pathcamera));   % init camera 
    
    if(sbconfig.pathlr)
        global img0_h;
        setappdata(img0_h,'UpdatePreviewWindowFcn',@flipDalsaImg);
    end
    
end

% eye tracker 1...

if(sbconfig.eyetracker_1)
    cprintf('*comment','[%02d] Configuring eye camera 1\n',istep); istep=istep+1; % modified by JZ, original: '[%02d] Configuring eyetracker\n'

    global eyecam eye_src eye_roi;
    
    for(i=1:length(q.DeviceInfo)) % find camera...
        if(~isempty(strfind(q.DeviceInfo(i).DeviceName,sbconfig.eyecamera_1))) % modified by JZ, original: eyecamera
            q.DeviceInfo(i).DeviceName = '';
            break;
        end
    end
    
    eyecam = videoinput('gige', i, 'Mono8');
    eye_src = getselectedsource(eyecam);
    % eye_src.TriggerMode = 'Off'; % added in case it was left On...

    eye_src.ReverseX = 'False';
    eye_src.BinningHorizontal = 1; % modified by JZ, original = 2
    eye_src.BinningVertical = 1; % modified by JZ, original = 2
    eye_src.ExposureTimeAbs = 7000;
    eye_src.AcquisitionFrameRateAbs = 20.0;
    eyecam.FramesPerTrigger = inf;
    eyecam.ReturnedColorspace = 'grayscale';
    eye_roi = [0 0 eyecam.VideoResolution];
    
    
    % vid.TriggerRepeat = # frames to be collected...  or inf...
    % triggerconfig(vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
    % src.FrameStartTriggerMode = 'On'
    % src.FrameStartTriggerSource = 'Line2'
    % vid.FramesPerTrigger = 1;
    
    % To go back...
    %     triggerconfig(vid, 'immediate', 'none', 'none');
    %     vid.FramesPerTrigger = inf;
    %     vid.TriggerRepeat = 1;
    %     src.FrameStartTriggerMode = 'Off'
    
end

cprintf('*comment','[%02d] Setting up digitizer\n',istep); istep=istep+1;

% dummy fig 1
% figure(1);
% set(1,'visible','off');

figure('visible','off');

% Digitizer initialization

AlazarDefs;

% Load driver library
if ~alazarLoadLibrary()
    warndlg(sprintf('Error: ATSApi.dll not loaded\n'),'scanbox');
    return
end

systemId = int32(1);
boardId = int32(1);

global boardHandle

% Get a handle to the board
boardHandle = calllib('ATSApi', 'AlazarGetBoardBySystemID', systemId, boardId);
setdatatype(boardHandle, 'voidPtr', 1, 1);
if boardHandle.Value == 0
    warndlg(sprintf('Error: Unable to open board system ID %u board ID %u\n', systemId, boardId),'scanbox');
    return
end

% % Configure the board...
% %
% Set capture clock to external...

retCode = ...
    calllib('ATSApi', 'AlazarSetCaptureClock', ...
    boardHandle,		 ...	% HANDLE -- board handle
    FAST_EXTERNAL_CLOCK, ...	% U32 -- clock source id
    SAMPLE_RATE_USER_DEF, ...	% U32 -- IGNORED when clock is external!
    CLOCK_EDGE_RISING,	...	% U32 -- clock edge id
    0					...	% U32 -- clock decimation by 4 (3 is one less)
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetCaptureClock failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end


% % set external clock level if needed...
% % Not supported in 9440...!!!!

retCode = ...
    calllib('ATSApi', 'AlazarSetExternalClockLevel', ...
    boardHandle,		 ...	% HANDLE -- board handle
    single(65.0)	     ...	% U32 --level in percent
    );
if retCode ~= ApiSuccess
    fprintf('Error: AlazarSetExternalClockLevel failed -- %s\n', errorToText(retCode));
    return
end


% Set CHA input parameters

retCode = ...
    calllib('ATSApi', 'AlazarInputControl', ...
    boardHandle,		...	% HANDLE -- board handle
    CHANNEL_A,			...	% U8 -- input channel
    DC_COUPLING,		...	% U32 -- input coupling id
    INPUT_RANGE_PM_200_MV, ...	% U32 -- input range id
    IMPEDANCE_50_OHM	...	% U32 -- input impedance id
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarInputControl failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% CHB params...

retCode = ...
    calllib('ATSApi', 'AlazarInputControl', ...
    boardHandle,		...	% HANDLE -- board handle
    CHANNEL_B,			...	% U8 -- channel identifier
    DC_COUPLING,		...	% U32 -- input coupling id
    INPUT_RANGE_PM_200_MV,	...	% U32 -- input range id
    IMPEDANCE_50_OHM	...	% U32 -- input impedance id
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarInputControl failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end


% Select trigger inputs...

retCode = ...
    calllib('ATSApi', 'AlazarSetTriggerOperation', ...
    boardHandle,		...	% HANDLE -- board handle
    TRIG_ENGINE_OP_J,	...	% U32 -- trigger operation
    TRIG_ENGINE_J,		...	% U32 -- trigger engine id
    TRIG_EXTERNAL,		...	% U32 -- trigger with TRIGOUT
    TRIGGER_SLOPE_POSITIVE+sbconfig.trig_slope,	... % U32 -- THE HSYNC is flipped on the PSoC board...
    sbconfig.trig_level, ...	% U32 -- trigger level from 0 (-range) to 255 (+range)
    TRIG_ENGINE_K,		...	% U32 -- trigger engine id
    TRIG_DISABLE,		...	% U32 -- trigger source id for engine K
    TRIGGER_SLOPE_POSITIVE, ...	% U32 -- trigger slope id
    128					...	% U32 -- trigger level from 0 (-range) to 255 (+range)
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetTriggerOperation failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% External trigger params...
retCode = ...
    calllib('ATSApi', 'AlazarSetExternalTrigger', ...
    boardHandle,		...	% HANDLE -- board handle
    uint32(DC_COUPLING),		...	% U32 -- external trigger coupling id
    uint32(ETR_1V)				...	% U32 -- external trigger range id
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetExternalTrigger failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% Delays...

triggerDelay_samples = uint32(0);
retCode = calllib('ATSApi', 'AlazarSetTriggerDelay', boardHandle, triggerDelay_samples);
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetTriggerDelay failed -- %s\n', errorToText(retCode)),'scanbox');
    return;
end

% Trigger timeout...

retCode = ...
    calllib('ATSApi', 'AlazarSetTriggerTimeOut', ...
    boardHandle,            ...	% HANDLE -- board handle
    uint32(0)	... % U32 -- timeout_sec / 10.e-6 (0 == wait forever)
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetTriggerTimeOut failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% Configure AUX I/O

% Config TTL as inputs into two LSBs of stream...

cprintf('*comment','[%02d] Configuring TTLs\n',istep); istep=istep+1;

configureLsb9440(boardHandle,0,3);   %%

if(sbconfig.nroi_parallel)
    cprintf('*comment','[%02d] Starting parallel pool\n',istep); istep=istep+1;
    parpool(sbconfig.nroi_auto);
end

if(sbconfig.gpu_pages>0)
    cprintf('*comment','[%02d] Reset GPU\n',istep); istep=istep+1;
    gpuDevice(sbconfig.gpu_dev);   %% was 2,3 
end

% setup memory mapped file if necessary

if(sbconfig.mmap>0)     % make sure file exists...
    cprintf('*comment','[%02d] Setting up memory mapped files\n',istep); istep=istep+1;
    fnmm = which('scanbox');
    fnmm = strsplit(fnmm,'\');
    fnmm{end-1} = 'mmap';
    fnmm{end} = 'scanbox.mmap';
    sbconfig.fnmm = strjoin(fnmm,'\');    % name of memory mapped file

    if(~exist(sbconfig.fnmm,'file'))
        fidmm = fopen(sbconfig.fnmm,'w');
        fwrite(fidmm,zeros(1,16+1024*976*2*2,'int16'),'uint16'); % 16 words of header + max frame size
        fclose(fidmm);
    end
    
end

% update laser status

% set(handles.lstatus,'String',laser_status);

global ltimer;  % laser timer

if(~isempty(sbconfig.laser_type))
    ltimer = timer('ExecutionMode','FixedRate','Period',5,'TimerFcn',@laser_cb);
    start(ltimer);
end

global ptimer;
if(~isempty(sbconfig.tri_knob))
    ptimer = timer('ExecutionMode','FixedRate','Period',.1,'TimerFcn',@pos_cb);
    start(ptimer);
end


if(sbconfig.qmotion==1)
    global qserial;
    qserial = serial(sbconfig.qmotion_com,'baud',38400,'terminator','','bytesavailablefcnmode','byte','bytesavailablefcncount',1,'bytesavailablefcn',@qmotion_cb);
    fopen(qserial);
end

%real time ROIs

global ncell cellpoly;

ncell = 0;
cellpoly = {};

% Done with daq configuration .... !!!!

global scanbox_h

%scanbox_h.Position = [150 150 1632 834];  % force position/size Matlab bug with large monitors % Modified by JZ, commented out
 
cprintf('\n');
drawnow;
pause(.5);
cprintf('*Comment','Scanbox initialization complete!\n\n',istep); istep=istep+1;
pause(1);


% UIWAIT makes scanbox wait for user response (see UIRESUME)
% uiwait(handles.scanboxfig);


% --- Outputs from this function are returned to the command line.
function varargout = scanbox_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in magnification.
function magnification_Callback(hObject, eventdata, handles)
% hObject    handle to magnification (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns magnification contents as cell array
%        contents{get(hObject,'Value')} returns selected item from magnification

global sbconfig scanmode;

sb_setmag(get(hObject,'Value')-1);
set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');


% --- Executes during object creation, after setting all properties.
function magnification_CreateFcn(hObject, eventdata, handles)
% hObject    handle to magnification (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global sbconfig;
list = sprintf('%.1f\n',sbconfig.gain_galvo);
list = list(1:end-1); % drop last \n
hObject.String = list;

function lines_Callback(hObject, eventdata, handles)
% hObject    handle to lines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of lines as text
%        str2double(get(hObject,'String')) returns contents of lines as a double

global img0_h nlines sbconfig scanmode;

nlines = str2num(get(hObject,'String'));
if(isempty(nlines))
    nlines = 512;
    set(hObject,'String','512');
    warndlg('The number of lines must be a number! Resetting to default value (512).');
elseif (mod(nlines,2))
    nlines = ceil(nlines/2);
    set(hObject,'String',num2str(nlines));
    warndlg('The number of lines must be even!  Rounding...');
end

sb_setline(nlines);
frame_rate = sbconfig.resfreq(get(handles.magnification,'Value'))/nlines*(2-scanmode); %% use actual resonant freq... % modified by JZ, original: sbconfig.resfreq
set(handles.frate,'String',sprintf('%2.2f',frame_rate));



% --- Executes during object creation, after setting all properties.
function lines_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function frames_Callback(hObject, eventdata, handles)
% hObject    handle to frames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of frames as text
%        str2double(get(hObject,'String')) returns contents of frames as a double

n = str2num(hObject.String);
if(isempty(n))
    set(hObject,'String','0');
    warndlg('Total frames must be a number! Resetting to default value (0 = forever).');
    sb_setframe(0);
else
    sb_setframe(n);
end

% --- Executes during object creation, after setting all properties.
function frames_CreateFcn(hObject, eventdata, handles)
% hObject    handle to frames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double


% --- Executes during object creation, after setting all properties.
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox1.
function checkbox1_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox1


% --- Executes on button press in laserbutton.
function laserbutton_Callback(hObject, eventdata, handles)
% hObject    handle to laserbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of laserbutton

global sbconfig;

switch sbconfig.laser_type
    case 'CHAMELEON'
        laser_send(sprintf('LASER=%d',get(hObject,'Value')));
    case 'DISCOVERY'
        laser_send(sprintf('LASER=%d',get(hObject,'Value')));
        
        % now ask for max/min GDD and set values...
        
        r = laser_send('?GDDMIN');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Min = val;
        
        r = laser_send('?GDDMAX');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Max= val;
        
        r = laser_send('?GDD');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Value= val;
        handles.gddtxt.String = r{end};
        
        
    case 'MAITAI'
        if(get(hObject,'Value'))
            r = laser_send('READ:PCTWARMEDUP?');
            if(~isempty(strfind(r,'100')))
                laser_send(sprintf('ON'));
            else
                set(hObject,'Value',0);
            end
        else
            laser_send(sprintf('OFF'));
        end
end

if(get(hObject,'Value'))
    set(hObject,'String','Laser is on','FontWeight','bold','Value',1);
else
    set(hObject,'String','Laser is off','FontWeight','normal','Value',0);
end



% --- Executes on button press in shutterbutton.
function shutterbutton_Callback(hObject, eventdata, handles)
% hObject    handle to shutterbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of shutterbutton

global sbconfig;

switch sbconfig.laser_type
    case 'CHAMELEON'
        laser_send(sprintf('SHUTTER=%d',get(hObject,'Value')));
    case 'DISCOVERY'
        laser_send(sprintf('SHUTTER=%d',get(hObject,'Value')));
    case 'MAITAI'
        laser_send(sprintf('SHUTTER %d',get(hObject,'Value')));
end

if(get(hObject,'Value'))
    set(hObject,'String','Shutter open','FontWeight','bold','Value',1);
else
    set(hObject,'String','Shutter closed','FontWeight','normal','Value',0);
end


function wavelength_Callback(hObject, eventdata, handles)
% hObject    handle to wavelength (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of wavelength as text
%        str2double(get(hObject,'String')) returns contents of wavelength as a double

global sbconfig;

val = str2num(get(hObject,'String'));

if(isempty(val))
    set(hObject,'String','920');
    warndlg('Wavelength must a number! Resetting to 920nm');
elseif (val>1040 || val<700)
    set(hObject,'String','920');
    warndlg('Wavelength must a number between 700-1040nm.  Resetting to 920nm');
end

switch sbconfig.laser_type
    
    case 'CHAMELEON'
        laser_send(sprintf('WAVELENGTH=%s',get(hObject,'String')));
        
    case 'DISCOVERY'
        laser_send(sprintf('WAVELENGTH=%s',get(hObject,'String')));
        
        r = laser_send('?GDDMIN');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Min = val;
        
        r = laser_send(['?GDDMAX:' get(hObject,'String')]);
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Max= val;
        
        r = laser_send('?GDD');
        [r,~] = strsplit(r,' ');
        val = str2double(r{3});
        handles.gddslider.Value= val;
        handles.gddtxt.String = r{end};
        
    case 'MAITAI'
        laser_send(sprintf('WAVELENGTH %s',get(hObject,'String')));
end




% --- Executes during object creation, after setting all properties.
function wavelength_CreateFcn(hObject, eventdata, handles)
% hObject    handle to wavelength (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global wave_h;

wave_h = hObject;

%laser_send(sprintf('WAVELENGTH=%s',get(hObject,'String')));


% --- Executes on selection change in popupmenu2.
function popupmenu2_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu2


% --- Executes during object creation, after setting all properties.
function popupmenu2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit5_Callback(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit5 as text
%        str2double(get(hObject,'String')) returns contents of edit5 as a double


% --- Executes during object creation, after setting all properties.
function edit5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit6_Callback(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit6 as text
%        str2double(get(hObject,'String')) returns contents of edit6 as a double


% --- Executes during object creation, after setting all properties.
function edit6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit7_Callback(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit7 as text
%        str2double(get(hObject,'String')) returns contents of edit7 as a double


% --- Executes during object creation, after setting all properties.
function edit7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox4.
function checkbox4_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox4


% --- Executes on selection change in popupmenu3.
function popupmenu3_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu3 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu3

global mstep;

switch(hObject.Value)
    case 1
        mstep = [400 1575 1575 400];
    case 2
        mstep = [80 315 315 80];
    case 3
        mstep = [16 63 63 16];
end


% --- Executes during object creation, after setting all properties.
function popupmenu3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton7.
function pushbutton7_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in motorlock.
function motorlock_Callback(hObject, eventdata, handles)
% hObject    handle to motorlock (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of motorlock

% set(hObject,'enable','off');
% drawnow;
% set(hObject,'enable','on');
%WindowAPI(handles.scanboxfig,'setfocus')
% set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');



function xpos_Callback(hObject, eventdata, handles)
% hObject    handle to xpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of xpos as text
%        str2double(get(hObject,'String')) returns contents of xpos as a double

eventdata.EventName = 2;
scanboxfig_WindowKeyPressFcn(hObject, eventdata, handles);


% --- Executes during object creation, after setting all properties.
function xpos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global xpos_h

xpos_h = hObject;
hObject.BackgroundColor = [0.941 0.941 0.941];




% --- Executes on button press in pushbutton8.
function pushbutton8_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton9.
function pushbutton9_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function ypos_Callback(hObject, eventdata, handles)
% hObject    handle to ypos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ypos as text
%        str2double(get(hObject,'String')) returns contents of ypos as a double


% --- Executes during object creation, after setting all properties.
function ypos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ypos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global ypos_h

ypos_h = hObject;
hObject.BackgroundColor = [0.941 0.941 0.941];


% --- Executes on button press in pushbutton10.
function pushbutton10_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton11.
function pushbutton11_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function zpos_Callback(hObject, eventdata, handles)
% hObject    handle to zpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of zpos as text
%        str2double(get(hObject,'String')) returns contents of zpos as a double


% --- Executes during object creation, after setting all properties.
function zpos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global zpos_h

zpos_h = hObject;
hObject.BackgroundColor = [0.941 0.941 0.941];



% --- Executes on button press in pushbutton12.
function pushbutton12_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton12 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton13.
function pushbutton13_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function thpos_Callback(hObject, eventdata, handles)
% hObject    handle to thpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of thpos as text
%        str2double(get(hObject,'String')) returns contents of thpos as a double


% --- Executes during object creation, after setting all properties.
function thpos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to thpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global thpos_h

thpos_h = hObject;
hObject.BackgroundColor = [0.941 0.941 0.941];


% --- Executes on button press in pushbutton14.
function pushbutton14_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton15.
function pushbutton15_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton16.
function pushbutton16_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton16 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global datadir

datadir = uigetdir('Data directory');
set(handles.dirname,'String',datadir);


% --- Executes on button press in grabb.
function grabb_Callback(hObject, eventdata, handles)
% hObject    handle to grabb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global animal experiment trial savesel seg img0_h captureDone;
global scanbox_h buffersPerAcquisition;
global pmtdisp_h segment_h;
global wcam eyecam sbconfig dgain dbias;
global scanmode;
global ephys efid;

% Some basic checking...

wf=0;
swrn = 'Correct the following before imaging:';

if(~isempty(sbconfig.laser_type))
    
    if(get(handles.laserbutton,'Value')==0)
        wf = wf + 1;
        swrn = sprintf('%s\n%s',swrn,'Turn the laser on and wait for modelock');
    end
    
    if(get(handles.shutterbutton,'Value')==0)
        wf = wf + 1;
        swrn = sprintf('%s\n%s',swrn,'Open the laser shutter');
    end
    
end

if(get(handles.camerabox,'Value')==1)
    wf = wf + 1;
    swrn = sprintf('%s\n%s',swrn,'Camara pathway is activated.');
end

if(get(segment_h,'Value')==1)
    wf = wf + 1;
    swrn = sprintf('%s\n%s',swrn,'Cannot acquire while segmenting.');
end

% if(get(handles.pmtenable,'Value')==0)
%     wf = wf + 1;
%     swrn = sprintf('%s\n%s',swrn,'Turn PMTs on and set their gains.');
% end

global z_vals;

if(wf>0)
    warndlg(swrn);
    return;
end


% turn zoom off

zoom(scanbox_h,'off');
pan(scanbox_h,'off');

AlazarDefs; % board constants

global shutter_h histbox_h;
global boardHandle saveData fid stim_on buffersCompleted messages;
global abort_bit;

stim_on = 0;

switch(get(hObject,'String'))
    case 'Focus'
        abort_bit = 0;
        set(hObject,'String','Abort');
        set(handles.grabb,'Enable','off'); % make this invisible
        frames = 0;
        saveData = false;           % if data are being saved or not...
        set(messages,'String',{});  % clear messages...
        set(messages,'ListBoxTop',1);
        set(messages,'Value',1);
        drawnow;
    case 'Grab'
        abort_bit = 0;
        set(hObject,'String','Abort');
        set(handles.focusb,'Enable','off'); % make this invisible
        frames = str2num(get(handles.frames,'String'));
        saveData = true;            % if data are being saved or not...
        set(messages,'String',{});  % clear messages...
        set(messages,'ListBoxTop',1);
        set(messages,'Value',1);
        drawnow;
    case 'Abort'
        abort_bit = 1;
        sb_abort;

        % make pmts zero...
        
        pause(0.2);
        
        sb_gain0(0);
        handles.pmt0txt.String = sprintf('%1.2f',handles.pmt0.Value);
        
        sb_gain1(0);
        handles.pmt1txt.String = sprintf('%1.2f',handles.pmt1.Value);
        
        handles.pmt0.Enable = 'off';
        handles.pmt1.Enable = 'off';
        
        global mm_flag mmfile;
        if(mm_flag) % signal end of aquisition
            mmfile.Data.header(1) = -2;
            pause(.15);
            mmfile.Data.header(1) = -1;
        end
        
        if(sbconfig.ephys)
            try
                stop(ephys);
                fclose(efid);
            catch
            end
        end
        retCode = calllib('ATSApi', 'AlazarAbortAsyncRead', boardHandle);
        if retCode ~= ApiSuccess
            warndlg(sprintf('Error: AlazarAbortCapture failed-- %s\n', errorToText(retCode)),'scanbox');
        end
        set(handles.grabb,'String','Grab','Enable','on'); % make this invisible
        set(handles.focusb,'String','Focus','Enable','on'); % make this invisible
        captureDone = 1;
        
        return;
end


if frames==0
    frames = hex2dec('7fffffff'); % Inf for Alazar card
end

% set lines/mag/frames

lines  = str2num(get(handles.lines,'String'));
global nlines;
nlines = lines;
mag = get(handles.magnification,'Value')-1;
sb_setparam(lines,frames,mag);

if(scanmode)
    recordsPerBuffer = lines;       % records per buffer
else
    recordsPerBuffer = lines/2;       % records per buffer
end

buffersPerAcquisition = frames; % Total  number of frames to capture

% Capture both channels
channelMask = CHANNEL_A + CHANNEL_B;

% Buffer time out....
bufferTimeout_ms = 2000;

% No of channels to sample
channelCount = 2;

% Get the sample and memory size
[retCode, boardHandle, maxSamplesPerRecord, bitsPerSample] = calllib('ATSApi', 'AlazarGetChannelInfo', boardHandle, 0, 0);
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarGetChannelInfo failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% Calculate sizes

global scanmode;

if(scanmode)
    postTriggerSamples = 5000;                % just one line...
    samplesPerRecord =   postTriggerSamples;  % 10000/4 (1 sample every laser clock) samples per scan (back and forth)
else
    postTriggerSamples = 9000;                % bidirectional
    samplesPerRecord =   postTriggerSamples;  % 10000/4 (1 sample every laser clock) samples per scan (back and forth)
end

% scanmode luts for non-uniform compensation

if(scanmode)                % unidirectional 
    %S = pixel_lut;
    % ncol = length(S);
    S = pixel_lut_2(get(handles.magnification,'Value')); % modified by JZ, original: S = pixel_lut_2
    ncol = length(S)/4;
else
%     if(isnan(sbconfig.ncolbi(handles.magnification.Value)))
%         warndlg('Bidirectional scanning has not been calibrated for this magnification.  Aborting!');
%         set(handles.grabb,'String','Grab','Enable','on'); % make this invisible
%         set(handles.focusb,'String','Focus','Enable','on'); % make this invisible
%         abort_bit = 1;
% 
%         % just in case...
%         
%         pause(0.2);
%         
%         sb_gain0(0);
%         handles.pmt0txt.String = sprintf('%1.2f',handles.pmt0.Value);
%         
%         sb_gain1(0);
%         handles.pmt1txt.String = sprintf('%1.2f',handles.pmt1.Value);
%         
%         handles.pmt0.Enable = 'off';
%         handles.pmt1.Enable = 'off';
%         
%         return;
%     else
       % [S,postIdx,postIdxA,cdIdx,ncol] = pixel_lut_bi(nlines,sbconfig.ncolbi(handles.magnification.Value));
         [S,postIdx,postIdxA,cdIdx,ncol] = pixel_lut_bi_2(nlines); % modified by JZ, original: [S,postIdx,postIdxA,cdIdx,ncol] = pixel_lut_bi_2(nlines) 
   % end
end

bytesPerSample = 2;
samplesPerBuffer = samplesPerRecord * recordsPerBuffer * channelCount ;
bytesPerBuffer   = samplesPerBuffer * bytesPerSample;

global sbconfig;

% Prepare DMA buffers...

bufferCount = uint32(sbconfig.nbuffer); % Pre allocate buffers to store the data...

% buffers = cell(1,bufferCount);
% for j = 1 : bufferCount
%     buffers{j} = libpointer('uint16Ptr', 1:samplesPerBuffer) ;
% end

buffers = cell(1, bufferCount);
for j = 1 : bufferCount
    pbuffer = calllib('ATSApi', 'AlazarAllocBufferU16', boardHandle, samplesPerBuffer);
    if pbuffer == 0
        fprintf('Error: AlazarAllocBufferU16 %u samples failed\n', samplesPerBuffer);
        return
    end
    buffers(1, j) = { pbuffer };
end



% Create a data file if required

fid = -1;
if saveData
    global datadir animal experiment unit
    
    fn = [datadir filesep animal filesep sprintf('%s_%03d',animal,unit) '_'  sprintf('%03d',experiment) '.sbx'];
    if(exist(fn,'file'))
        warndlg('Data file exists!  Cannot overwrite! Aborting!');
        set(handles.grabb,'String','Grab','Enable','on'); % make this invisible
        set(handles.focusb,'String','Focus','Enable','on'); % make this invisible
        abort_bit = 1;
        
        pause(0.2);
        
        sb_gain0(0);
        handles.pmt0txt.String = sprintf('%1.2f',handles.pmt0.Value);
        
        sb_gain1(0);
        handles.pmt1txt.String = sprintf('%1.2f',handles.pmt1.Value);
        
        handles.pmt0.Enable = 'off';
        handles.pmt1.Enable = 'off';
        
        return;
    end
    
    fid = fopen(fn,'w');
    if fid == -1
        warndlg(sprintf('Error: Unable to create data file\n'),'scanbox');
        
        % Restore buttons
        set(handles.grabb,'String','Grab','Enable','on'); % make this invisible
        set(handles.focusb,'String','Focus','Enable','on'); % make this invisible
        
        clear buffers;
        
        return;
    end
    
    if(sbconfig.ephys)
        global efid
        fn = [datadir filesep animal filesep sprintf('%s_%03d',animal,unit) '_'  sprintf('%03d',experiment) '.ephys'];
        efid = fopen(fn,'w');
    end
    
end

% Set the record size
retCode = calllib('ATSApi', 'AlazarSetRecordSize', boardHandle, uint32(0), uint32(postTriggerSamples));
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarBeforeAsyncRead failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% TODO: Select AutoDMA flags as required
% ADMA_NPT - Acquire multiple records with no-pretrigger samples
% ADMA_EXTERNAL_STARTCAPTURE - call AlazarStartCapture to begin the acquisition
% ADMA_INTERLEAVE_SAMPLES - interleave samples for highest throughput

admaFlags = ADMA_EXTERNAL_STARTCAPTURE + ADMA_NPT + ADMA_INTERLEAVE_SAMPLES;

% Configure the board to make an AutoDMA acquisition
recordsPerAcquisition = recordsPerBuffer * buffersPerAcquisition;
retCode = calllib('ATSApi', 'AlazarBeforeAsyncRead', boardHandle, uint32(channelMask), uint64(0), uint32(samplesPerRecord), uint32(recordsPerBuffer),uint32(recordsPerAcquisition), uint32(admaFlags));
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarBeforeAsyncRead failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% Post the buffers to the board
for bufferIndex = 1 : bufferCount
    pbuffer = buffers{1, bufferIndex};
    retCode = calllib('ATSApi', 'AlazarPostAsyncBuffer', boardHandle, pbuffer, uint32(bytesPerBuffer));
    if retCode ~= ApiSuccess
        warndlg(sprintf('Error: AlazarPostAsyncBuffer failed -- %s\n', errorToText(retCode)),'scanbox');
        sb_abort;
        return
    end
end


% Prepare image axis

global chA chB acc accB accd accdB tfilter_h scanbox_h img0_h img0_axis;

%set(get(img0_h,'Parent'),'xlim',[0 samplesPerRecord/4-1],'ylim',[0 recordsPerBuffer-1]);

if(get(handles.camerabox,'Value')==0)
    set(get(img0_h,'Parent'),'xlim',[0.5 ncol+0.5],'ylim',[0.5 lines+0.5]);
    set(img0_h,'CData',ones([lines ncol 3],'uint8'));
    set(img0_h,'erasemode','none');
    axis off;
end

% loop vars...

buffersCompleted = 0;
captureDone = false;
success = false;
acc=[];
accB = [];

nacc=0;
trial_acc={};
trial_n=[];
ttlflag = 0;

global sb_server sb sbconfig;

sb_server.BytesAvailableFcn = ''; % we are going to poll...

global wcam wcam_src eyecam eye_src ballpos ballarrow ballmotion;
global datadir experiment animal unit;
global wcamlog eyecamlog;
global wcam_roi eye_roi;
global sbconfig;
global ttlonline;
global trace_idx trace_period cellpoly roi_traces_h;
global ref_img;
global gtime gData nlines;
global stream_udp;
global nroi;
global ref_img_fft xref yref
global roipix
global otwave otparam otwave_um opto2pow
global tri_pos dmpos origin xpos_h ypos_h zpos_h thpos_h motor_gain
global ephys


if fid ~= -1
    if(get(handles.wc,'Value'))
        
        triggerconfig(wcam, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
        wcam.TriggerRepeat = inf;
        try
            wcam_src.FrameStartTriggerMode = 'On';
        catch
            wcam_src.TriggerMode = 'On';
        end
        wcam.FramesPerTrigger = 1;
        wcam.ROIPosition = wcam_roi;
        start(wcam);
        
    end
    
    if(get(handles.eyet,'Value'))
        
        triggerconfig(eyecam, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
        eyecam.TriggerRepeat = inf;
        try
            eye_src.FrameStartTriggerMode = 'On';
        catch
            eye_src.TriggerMode = 'On';
        end
        eyecam.FramesPerTrigger = 1;
        eyecam.ROIPosition = eye_roi;
        
        start(eyecam);
    end
end


global ltimer;

if(~isempty(sbconfig.laser_type))
    stop(ltimer);
end

global ptimer;
if(~isempty(sbconfig.tri_knob))
    stop(ptimer);
end

delete(get(roi_traces_h,'Children')); % remove children...
nroi = length(get(handles.blist,'String'));
ydata = NaN*zeros(trace_period+1,nroi);
Xtrace = repmat([1:trace_period NaN],[nroi 1])';
Xtrace = Xtrace(:);

%disable poly view

cellfun(@(x) set(x,'Parent',[]),cellpoly);


if(nroi>0)
    stream_data = zeros(1,nroi+3,'int16');
    roiidx = cellfun(@str2num,get(handles.blist,'String'));
    roipix = cell(1,length(roiidx));
    hold(roi_traces_h,'on');
    
    theline = plot(roi_traces_h,[1 1],[-4 nroi*4],'color',[.75 0 0],'linewidth',1);
    set(roi_traces_h,'Ylim',[-4 nroi*4],'Xlim',[1 trace_period]); % 4 std apart...
    trace_idx = 1;
    
    thetrace = animatedline('MaximumNumPoints',(trace_period+1)*50,'linewidth',.5,'color',[0 0 0.5],'tag','thetrace','Parent',roi_traces_h);
    thetrace.addpoints(Xtrace,ydata(:));
    hold(roi_traces_h,'off');
    for(i=1:length(roiidx))
        %roipix{i} = find(createMask(cellpoly{roiidx(i)}));
        roipix{i}=find(poly2mask(get(cellpoly{roiidx(i)},'XData'),get(cellpoly{roiidx(i)},'YData'),nlines,ncol));
        th = text(8,4*(i-1),sprintf('%02d',roiidx(i)),'parent',roi_traces_h,'fontsize',10,'color','r','BackgroundColor','w','edgecolor','k','fontname','CourierNew');
        uistack(th,'top');
    end
    
    
    %     ch = get(roi_traces_h,'Children');
    %     vch = ch(end);
    rmean = zeros(1,nroi);  %mean and variance (recursive)
    rvar = zeros(1,nroi);
    rtdata = zeros(sbconfig.rtmax,nroi);
    ttl_log = zeros(sbconfig.rtmax,1,'uint8');
end

% Allocate for encoder data
if(~isempty(sbconfig.quad_com) && (handles.quadcheck.Value>0))
    quad_data = zeros(1,sbconfig.rtmax,'int32');
    quad_zero;  % zero counter
    quad_flag = 1;
else
    quad_flag = 0;
end


% allocate for online alignment

global T preIdx;
Talign = zeros(sbconfig.rtmax,2*sbconfig.nroi_auto);


% Prepare for alignment...

u = zeros(1,sbconfig.nroi_auto);
v = zeros(1,sbconfig.nroi_auto);
N = sbconfig.nroi_auto_size(handles.magnification.Value);

global L I;
L = []; % list of patches and indices for roi stim patch visualization
I = [];

if(sbconfig.gpu_pages>0)
    % allocate memory...
    global nlines;
    if(nlines~=size(gData,2) || sbconfig.gpu_pages~=size(gData,1) || ncol~=size(gData,3))
        gData = zeros([sbconfig.gpu_pages nlines ncol ],'single','gpuArray');
    end
    gtime = 1;          % next page to be filled
    tmp  = rand(100);   % gpu warm up...
    gtmp = gpuArray(tmp);
    gtmp = gtmp*gtmp;
    tmp = gather(gtmp);
end

% network streaming 

stream_flag = get(handles.networkstream,'Value');
stim_flag = get(handles.stimmark,'Value');

% prealocate stuff...

chAB = zeros([2 ncol lines],'uint16');
chA  = zeros([ncol lines],'uint16');
chB  = zeros([ncol lines],'uint16');

ttlflagnew = uint16(0);

if(scanmode)    % unidirectional
    
%     preIdx = reshape(0:prod([2 4 1250 lines])-1,[2 4 1250 lines]);
%     preIdx = preIdx(:,:,S,:);
%     preIdx = uint32(preIdx);

    % new version does not merely sample on 4 sample boundaries...
    
    preIdx = reshape(0:prod([2 4 1250 lines])-1,[2 4*1250 lines]);
    preIdx = preIdx(:,S,:);
    preIdx = reshape(preIdx,2,4,[],lines);
    preIdx = uint32(preIdx);

else            % bidirectional
    
%     preIdx = reshape(0:prod([2 4 2250 lines/2])-1,[2 4 2250 lines/2]);
%     preIdx = preIdx(:,:,S,:);
%     preIdx = uint32(preIdx);
%     preIdx = preIdx+sbconfig.bishift(handles.magnification.Value)*2;

    preIdx = reshape(0:prod([2 4 2250 lines/2])-1,[2 4*2250 lines/2]);
    preIdx = preIdx(:,S,:);
    preIdx = reshape(preIdx,2,4,[],lines/2);
    preIdx = uint32(preIdx);
    preIdx = preIdx+sbconfig.bishift(handles.magnification.Value)*2;
end

outCData = zeros([3 ncol lines],'uint8');
newCData = zeros([lines ncol lines 3],'uint8');

% make sure previews are closed

closepreview;

% memory mapped file?
 
global mm_flag;
mm_flag = handles.mmap.Value;
if(mm_flag)
    try
        clear mmfile;
    catch
    end
    global mmfile;
    mmfile = memmapfile(sbconfig.fnmm,'Writable',true,'Format', ...
        { 'int16' [1 16] 'header' ; 'uint16' [nlines ncol] 'chA'} , 'Repeat', 1);
    mmfile.Data.header(1) = -1;                 % semaphore or frame #
    mmfile.Data.header(2) = int16(nlines);      % number of lines
    mmfile.Data.header(3) = int16(ncol);        % number of columns
    mmfile.Data.header(4) = 0;                  % TTL for stimulus
    mmfile.Data.header(5) = int16(handles.volscan.Value);   % volumetric scanning flag
    mmfile.Data.header(6) = int16(str2double(handles.optoperiod.String));   % period of volumetric wave
end

% acquiring ephys?  Start background collection

if(sbconfig.ephys)
    startBackground(ephys);
end

% Arm the board system to wait for triggers

retCode = calllib('ATSApi', 'AlazarStartCapture', boardHandle);
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarStartCapture failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% turn PMTs on

sb_gain0(uint8(255*handles.pmt0.Value));
handles.pmt0txt.String = sprintf('%1.2f',handles.pmt0.Value);

sb_gain1(uint8(255*handles.pmt1.Value));
handles.pmt1txt.String = sprintf('%1.2f',handles.pmt1.Value);

handles.pmt0.Enable = 'on';
handles.pmt1.Enable = 'on';

pause(.2);

sb_deadband(sbconfig.deadband(1),sbconfig.deadband(2));

sb_scan;   % start scanning!

while ~captureDone
    
    % poll quadrature encoder
    
    if(quad_flag)  
        quad_poll;
    end
    
    % which buffer to read
    bufferIndex = mod(buffersCompleted, bufferCount) + 1;
    pbuffer = buffers{1,bufferIndex};
    
    % Wait for the first available buffer to be filled by the board
    [retCode, boardHandle, bufferOut] = ...
        calllib('ATSApi', 'AlazarWaitAsyncBufferComplete', boardHandle, pbuffer, uint32(bufferTimeout_ms));
    if retCode == ApiSuccess
        % This buffer is full
        bufferFull = true;
        captureDone = false;
    elseif retCode == ApiWaitTimeout
        % The wait timeout expired before this buffer was filled.
        % The board may not be triggering, or the timeout period may be too short.
        
        warndlg(sprintf('Warning: AlazarWaitAsyncBufferComplete timeout -- Verify trigger!\n'),'scanbox');
        
        bufferFull = false;
        captureDone = true;
    else
        % The acquisition failed
        warndlg(sprintf('Error: AlazarWaitAsyncBufferComplete failed -- %s\n', errorToText(retCode)),'scanbox');
        bufferFull = false;
        captureDone = true;
    end
            
    if bufferFull
        
        setdatatype(bufferOut, 'uint16Ptr', 1, samplesPerBuffer);  %% keep bytes separate
        
        if(scanmode)
            alazarReshapeCData2_openmp(bufferOut.Value,preIdx,chAB,chA,chB,outCData,uint16(lines),uint16(pmtdisp_h.Value),sbconfig.cores_uni);
        else
           % alazarReshapeCData2bi_openmp(bufferOut.Value,preIdx,postIdx,postIdxA,cdIdx,chAB,chA,chB,outCData,uint16(lines),uint16(pmtdisp_h.Value),uint16(length(S)),sbconfig.cores_bi);
           alazarReshapeCData2bi_openmp(bufferOut.Value,preIdx,postIdx,postIdxA,cdIdx,chAB,chA,chB,outCData,uint16(lines),uint16(pmtdisp_h.Value),uint16(length(S)/4),sbconfig.cores_bi);
        end
           
        ttlflagnew = bitget(bufferOut.Value(1),2,'uint16');
        ttl_log(buffersCompleted+1) = ttlflagnew;
        
        % Save the buffer to file
        
        if fid ~= -1
            switch(savesel)
                case 1
                    fwrite(fid,chAB,'uint16');
                case 2
                    fwrite(fid,chA,'uint16');
                case 3
                    fwrite(fid,chB,'uint16');
            end
        end
        
        if (handles.dispenable.Value == 1)
            
            % arrange image
            
            newCData = permute(outCData,[3 2 1]);
            
            % visualization gain/bias
            
            newCData = dgain.Value*(newCData+dbias.Value); % gain!!!!
            
            % stabilize
            
            if(handles.stabilize.Value)
                
                A = chA'; % do we need double()?
                
                for(ka=1:sbconfig.nroi_auto)
                    C = fftshift(real(ifft2(fft2(A(yref(ka,:),xref(ka,:))).*ref_img_fft{ka})));
                    [~,ia] = max(C(:));
                    [iia jja] = ind2sub(size(C),ia);
                    u(ka) = N/2-iia;
                    v(ka) = N/2-jja;
                end
                
                um = round(median(u));
                vm = round(median(v));
                img0_h.CData = circshift(newCData,[um vm 0]);
                chA = circshift(chA,[vm um]);
                chB = circshift(chB,[vm um]);
                Talign(buffersCompleted+1,:) = [u v];
                
            else
                img0_h.CData = newCData;
            end
        end
        
        % log chA to gpu page
        
        if(sbconfig.gpu_pages>0)
            if(gtime<=sbconfig.gpu_pages)
                if(mod(buffersCompleted+1,sbconfig.gpu_interval)==0)
                    gData(gtime,:,:) = chA';
                    gtime = gtime+1;
                end
            end
        end
        
        % log to memory map file...
        
        if(mm_flag)                       
            if(mmfile.Data.header(1)<0)    % data was consumed?  If not, move on...  
                mmfile.Data.header(4) = ttlflagnew;
                mmfile.Data.chA = chA';
                mmfile.Data.header(1)=buffersCompleted;
            end
        end
        
        % accumulator mode?
        
        if(handles.camerabox.Value==0)
            
            switch get(tfilter_h,'Value')
                
                case 1
                    
                case 2
                    
                    if(isempty(acc))
                        acc = chA;
                        accB = chB;
                    else
                        acc = min(acc,chA);
                        accB = min(accB,chB);
                    end
                    
                case 3                          %% accumulate and keep value in global var acc
                    if(isempty(acc))
                        acc = uint32(chA);
                        accB = uint32(chB);
                        nacc = 1;
                    else
                        acc = acc + uint32(chA);
                        accB = accB + uint32(chB);
                        nacc = nacc+1;
                    end
            end
        end
        
        % stimulus present in this frame?
        
        if(fid~=-1 && ttlonline)
            
            switch(ttlflag==0)
                case true
                    if(ttlflagnew~=0)
                        if(~isempty(acc))
                            acc = [];
                            accB = [];
                            nacc = 0;
                        end
                    end
                    
                case false
                    if(ttlflagnew==0)
                        if(~isempty(acc))
                            trial_acc{end+1} = {acc accB};
                            trial_n(end+1) = nacc;
                            acc = [];
                            accB = [];
                            nacc = 0;
                        end
                    end
            end
        end
        
        % trace processing
        
        if(nroi>0)
            
            % check if we need to remove/adjust anything...
            idxdel = [];
            for (jj=1:length(L))
                if(I(jj,1)<=trace_idx && I(jj,2)>=trace_idx && isempty(get(L(jj),'userdata')))
                    I(jj,1) = trace_idx;
                    if(I(jj,1) == I(jj,2))
                        idxdel(end+1) = jj;
                    else
                        set(L(jj),'xdata',[I(jj,1) I(jj,1) I(jj,2) I(jj,2)]);
                    end
                end
                % Not needed any more... (I think).
                %                 if(I(jj,1)>I(jj,2)) % defense
                %                     idxdel(end+1) = jj;
                %                     '**'
                %                 end
            end
            
            if(~isempty(idxdel))
                delete(L(idxdel));
                I(idxdel,:) = [];
                L(idxdel) = [];
            end
            
            % check if we need to add a new stim patch...
            
            if(stim_flag)
                
                if(ttlflag == 0 && ttlflagnew ~= 0) % new stim
                    
                    L(end+1) = patch([trace_idx trace_idx trace_idx trace_idx],[-4 nroi*4 nroi*4 -4],[1 .75 1],'edgecolor',0.941*[1 1 1],'parent',roi_traces_h,'FaceLighting','none','userdata',1);
                    uistack(L(end),'bottom');
                    I(end+1,:) = [trace_idx trace_idx];
                    
                elseif (ttlflag ~= 0 && ttlflagnew ~= 0) % during stim
                    
                    if(trace_idx>=trace_period) % reached the end
                        
                        I(end,2) = trace_idx;
                        set(L(end),'xdata',[I(end,1) I(end,1) I(end,2) I(end,2)],'userdata',[]);
                        
                    elseif (trace_idx == 1)     % we wrapped around during the stimulus
                        L(end+1) = patch([1 1 1 1],[-4 nroi*4 nroi*4 -4],[1 0.75 1],'edgecolor',0.941*[1 1 1],'parent',roi_traces_h,'userdata',1);
                        uistack(L(end),'bottom');
                        I(end+1,:) = [1 1];
                    else                        % during a stimulus in the middle...
                        I(end,2) = trace_idx;
                        set(L(end),'xdata',[I(end,1) I(end,1) I(end,2) I(end,2)]);
                    end
                    
                elseif (ttlflag ~= 0 && ttlflagnew == 0) % end stim
                    
                    if(~isempty(get(L(end),'userdata')))
                        I(end,2) = trace_idx;
                        set(L(end),'xdata',[I(end,1) I(end,1) I(end,2) I(end,2)],'userdata',[]);
                    end
                    
                end
                
                
                %                 if(ttlflag == 0)
                %                     if(ttlflagnew ~= 0)
                %                         % new stim
                %                         L(end+1) = patch([trace_idx trace_idx trace_idx trace_idx],[-4 nroi*4 nroi*4 -4],[1 .75 1],'edgecolor',0.941*[1 1 1],'parent',roi_traces_h,'FaceLighting','none');
                %                         uistack(L(end),'bottom');
                %                         I(end+1,:) = [trace_idx trace_idx];
                %                     end
                %                 else % or extend it...
                %                     if(trace_idx>=trace_period)
                %                         I(end,2) = trace_idx;
                %                         set(L(end),'xdata',[I(end,1) I(end,1) I(end,2) I(end,2)]);
                %                         L(end+1) = patch([1 1 1 1],[-4 nroi*4 nroi*4 -4],[1 0.75 1],'edgecolor',0.941*[1 1 1],'parent',roi_traces_h,'userdata',1);
                %                         uistack(L(end),'bottom');
                %                         I(end+1,:) = [1 1];
                %                     elseif (trace_idx == 1)
                %                         L(end+1) = patch([1 1 1 1],[-4 nroi*4 nroi*4 -4],[1 0.75 1],'edgecolor',0.941*[1 1 1],'parent',roi_traces_h,'userdata',1);
                %                         uistack(L(end),'bottom');
                %                         I(end+1,:) = [1 1];
                %                     else
                %                         I(end,2) = trace_idx;
                %                         set(L(end),'xdata',[I(end,1) I(end,1) I(end,2) I(end,2)]);
                %                     end
                %                 end
                
            end
            
            tchA = chA';
            t = buffersCompleted+1;
            
            for(k=1:nroi)
                roiv = mean(tchA(roipix{k}));
                rtdata(t,k) = roiv;
                if(t==1)
                    rmean(k) = roiv;
                    ydata(trace_idx,k) =  4*(k-1);
                else
                    rmean(k) = ((t-1)*rmean(k) + roiv)/t;
                    rvar(k)  =  (t-1)/t * rvar(k) + (roiv-rmean(k))^2 / (t-1);
                    tmp = (roiv-rmean(k))/sqrt(rvar(k));
                    ydata(trace_idx,k) = 4*(k-1) + tmp;
                    stream_data(k+2) = int16(tmp*1000);
%                     %here
%                     if(k==1)
%                         zz = -(roiv-rmean(k))/sqrt(rvar(k));
%                         if(abs(zz)>10) 
%                             zz = 10*sign(zz);
%                         end
%                         ao.outputSingleScan(zz);
%                     end
                end
            end
            thetrace.clearpoints;
            thetrace.addpoints(Xtrace,ydata(:));
            trace_idx = mod(trace_idx,trace_period)+1;
            theline.XData = [trace_idx trace_idx];
        end
        
        
        % This is preferred in 2015a and higher...
        
        drawnow limitrate
        
        % drawing completed
        
        %         if(mod(buffersCompleted,sbconfig.idisplay))
        %             drawnow expose;
        %         else
        %             drawnow;
        %         end
        
        ttlflag = ttlflagnew;           % update flag status
        
        if(nroi>0 && stream_flag)
            stream_data(1)= buffersCompleted;
            stream_data(2) = nroi;
            stream_data(end) = ttlflag;
            fwrite(stream_udp,stream_data,'int16');
        end
        
        % Make the buffer available to be filled again by the board
        retCode = calllib('ATSApi', 'AlazarPostAsyncBuffer', boardHandle, pbuffer, uint32(bytesPerBuffer));
        if retCode ~= ApiSuccess
            if(retCode ~= 520)
                warndlg(sprintf('Error: AlazarPostAsyncBuffer failed -- %s\n', errorToText(retCode)),'scanbox');
            end
            captureDone = true;
        end
        
        % quad update needed?
        
        if(quad_flag)
            quad_data(buffersCompleted+1) = quad_get; % read counter
            if(buffersCompleted>0)
                handles.quadtxt.String = sprintf('%+05d',quad_data(buffersCompleted+1));
            end
        end
        
        if (sb_server.BytesAvailable>0)
            udp_cb(sb_server,[]);
        end
        
        sb_callback;
        
        % Update progress
        
        buffersCompleted = buffersCompleted + 1;
        
        if buffersCompleted >= buffersPerAcquisition;
            captureDone = true;
            success = true;
        end
        
    end % if bufferFull
    
    % update counter/timer
    
    set(handles.etime,'String',sprintf('%05d - %s',buffersCompleted, datestr(datenum(0,0,0,0,0,toc),'MM:SS')));
    set(handles.etime2,'String',sprintf('%04d - %04d', gtime-1,size(T,1)));
    
end % while ~captureDone

sb_abort; % stop scanning

% Turn PMTs off

pause(0.2);

sb_gain0(0);
handles.pmt0txt.String = sprintf('%1.2f',handles.pmt0.Value);

sb_gain1(0);
handles.pmt1txt.String = sprintf('%1.2f',handles.pmt1.Value);

handles.pmt0.Enable = 'off';
handles.pmt1.Enable = 'off';

% mem map

if(mm_flag) % signal end of acuisition
    mmfile.Data.header(1) = -2; 
    pause(.15);
    mmfile.Data.header(1) = -1; 
end

if(sbconfig.ephys)
    pause(0.15);
    try
    stop(ephys);
    fclose(efid);
    catch
    end
end

if(sbconfig.gpu_pages>0)
    gtime = gtime-1;            % last index
end

cellfun(@(x) set(x,'Parent',img0_h.Parent),cellpoly);

%
if ~isempty(acc)
    accd =  double(acc);
    accdB = double(accB);
    
    %fill in bidi mode
    
    if(scanmode==0) % remove bands
%         accd(1:sbconfig.margin,:) = NaN;
%         accd(end-sbconfig.margin:end,:) = NaN;
%         accdB(1:sbconfig.margin,:) = NaN;
%         accdB(end-sbconfig.margin:end,:) = NaN;
          jj = find(accd(:,2)==0);
          accd(jj,2:2:end) = accd(jj,1:2:end);
          accdB(jj,2:2:end) = accdB(jj,1:2:end);
    end
    
    M = max(accd(:));
    m = min(accd(:));
    accd = ((accd-m)/(M-m));
%     if(scanmode==0) % remove bands
%         accd(1:sbconfig.margin,:) = 1;
%         accd(end-sbconfig.margin:end,:) = 1;
%     end
    
    M = max(accdB(:));
    m = min(accdB(:));
    accdB = ((accdB-m)/(M-m));
%     if(scanmode==0) % remove bands
%         accdB(1:sbconfig.margin,:) = 1;
%         accdB(end-sbconfig.margin:end,:) = 1;
%     end
    
    switch(handles.pmtdisp.Value)
        case 1
            
            img0_h.CData(:,:,1) = 0;
            img0_h.CData(:,:,2) =  uint8(255-uint8(255*accd'));
            img0_h.CData(:,:,3) = 0;
            
        case 2
            
            img0_h.CData(:,:,1) = uint8(255-uint8(255*accdB'));
            img0_h.CData(:,:,2) = 0;
            img0_h.CData(:,:,3) = 0;
            
        case 3
            
            img0_h.CData(:,:,1) = uint8(255-uint8(255*accdB'));
            img0_h.CData(:,:,2) = uint8(255-uint8(255*accd'));
            img0_h.CData(:,:,3) = 0;
            
    end
    
end

if(fid ~= -1)
    if(ttlonline && ~isempty(trial_acc))
        fn = sprintf('%s\\%s\\%s_%03d_%03d_trials.mat',datadir,animal,animal,unit,experiment);
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving trial data...','ForegroundColor',[1 0 0]);
        drawnow;
        save(fn,'trial_acc','trial_n');
        clear trial_acc trial_n;
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
end


% save real time  data....

if(fid ~= -1)
    if(nroi>0)
        fn = sprintf('%s\\%s\\%s_%03d_%03d_realtime.mat',datadir,animal,animal,unit,experiment);
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving realtime signals','ForegroundColor',[1 0 0]);
        drawnow;
        rtdata = rtdata(1:buffersCompleted,:);
        ttl_log = ttl_log(1:buffersCompleted);
        save(fn,'rtdata','ttl_log','roipix');
        clear rtdata;
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
end


% save real time alignment....

if(fid ~= -1)
    if(get(handles.stabilize,'Value'))
        fn = sprintf('%s\\%s\\%s_%03d_%03d_align.mat',datadir,animal,animal,unit,experiment);
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving alignment','ForegroundColor',[1 0 0]);
        drawnow;
        Talign = Talign(1:buffersCompleted,:);
        global xref yref;
        save(fn,'Talign','ref_img','xref','yref');
        clear T;
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
end

if(fid ~= -1)
    if(quad_flag)
        fn = sprintf('%s\\%s\\%s_%03d_%03d_quadrature.mat',datadir,animal,animal,unit,experiment);
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving Encoder','ForegroundColor',[1 0 0]);
        drawnow;
        quad_data = quad_data(1:buffersCompleted);
        save(fn,'quad_data');
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
end

if(fid ~= -1)
    
    if(get(handles.wc,'Value'))
        stop(wcam); % stop web cam...
        try
            wcam_src.FrameStartTriggerMode = 'Off';
        catch
            wcam_src.TriggerMode = 'Off';
        end
        triggerconfig(wcam, 'immediate', 'none', 'none');
        wcam.FramesPerTrigger = inf;
        wcam.TriggerRepeat = 1;
        wcam.ROIPosition = wcam_roi;
    end
    
    if(get(handles.eyet,'Value'))
        stop(eyecam); % stop eye cam...
        try
            eye_src.FrameStartTriggerMode = 'Off';
        catch
            eye_src.TriggerMode = 'Off';
        end
        
        triggerconfig(eyecam, 'immediate', 'none', 'none');
        eyecam.FramesPerTrigger = inf;
        eyecam.TriggerRepeat = 1;        
        eyecam.ROIPosition = eye_roi;
    end
    
    if(get(handles.wc,'Value') || get(handles.eyet,'Value'))
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving tracking data','ForegroundColor',[1 0 0]);
        drawnow;
        
        if(get(handles.wc,'Value')) % write wcam data...
            [data,time,abstime] = getdata(wcam);
            fn = sprintf('%s\\%s\\%s_%03d_%03d_eye2.mat',datadir,animal,animal,unit,experiment); % modified by JZ, original: '%s\\%s\\%s_%03d_%03d_ball.mat'
            flushdata(wcam);
            
            save(fn,'-v7.3','data','time','abstime'); % modified by JZ; added '-v7.3' for compatibility with large arrays (>2GB)
            clear data time abstime;
        end
        
        if(get(handles.eyet,'Value')) % write eyet data...
            [data,time,abstime] = getdata(eyecam);
            fn = sprintf('%s\\%s\\%s_%03d_%03d_eye1.mat',datadir,animal,animal,unit,experiment); % modified by JZ, original: '%s\\%s\\%s_%03d_%03d_eye.mat'
            flushdata(eyecam);
            save(fn,'-v7.3','data','time','abstime'); % modified by JZ; added '-v7.3' for compatibility with large arrays (>2GB)
            clear data time abstime;
        end
        
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
end

sb_server.BytesAvailableFcn = @udp_cb;  % restore...

% Stop scanning just in case...

sb_abort;

if(mm_flag) % signal end of acuisition
    mmfile.Data.header(1) = -2; 
    pause(.15);
    mmfile.Data.header(1) = -1; 
end

if(sbconfig.ephys)
    try
        global efid;
        stop(ephys);
        fclose(efid);
    catch
    end
end

global ltimer;
if(~isempty(sbconfig.laser_type))
    start(ltimer);
end

if(~isempty(sbconfig.tri_knob))
    start(ptimer);
end

% Terminate the acquisition
retCode = calllib('ATSApi', 'AlazarAbortAsyncRead', boardHandle);
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarAbortAsyncRead failed -- %s\n', errorToText(retCode)),'scanbox');
end

% Restore buttons
set(handles.grabb,'String','Grab','Enable','on'); % make this invisible
set(handles.focusb,'String','Focus','Enable','on'); % make this invisible

% Release the buffers
for bufferIndex = 1:bufferCount
    pbuffer = buffers{1, bufferIndex};
    retCode = calllib('ATSApi', 'AlazarFreeBufferU16', boardHandle, pbuffer);
    if retCode ~= ApiSuccess
        fprintf('Error: AlazarFreeBufferU16 failed -- %s\n', errorToText(retCode));
    end
    clear pbuffer;
end

%WindowAPI(handles.scanboxfig,'setfocus');

sb_callback; % any time stamps left?

% Close the data file
if fid ~= -1
    fclose(fid);
    fid = -1;
    fn = [datadir filesep animal filesep sprintf('%s_%03d',animal,unit) '_'  sprintf('%03d',experiment) '.mat'];
    info = sb_timestamps;   % get time stamps and image size...
    info.resfreq = sbconfig.resfreq(mag+1);    % resonant frequency in Hz..., % modified by JZ, now uses lookup table for resfreq depending on magnification
    info.postTriggerSamples = postTriggerSamples;
    info.recordsPerBuffer = recordsPerBuffer;
    info.bytesPerBuffer = bytesPerBuffer;
    info.channels = get(handles.savesel,'Value');
    info.ballmotion = ballmotion;
    info.abort_bit = abort_bit;
    info.scanbox_version = 2;
    info.scanmode = scanmode;
    info.config = scanbox_getconfig;
    info.sz = size(chA');
    info.otwave = otwave;
    info.otwave_um = otwave_um;
    info.otparam = otparam;
    info.otwavestyle = handles.optowavestyle.Value;
    info.volscan = handles.volscan.Value;
    info.power_depth_link = handles.linkcheck.Value;
    info.opto2pow = opto2pow;
    info.area_line = strcmp('Area', handles.arealine.String);   % area vs line
        
    % save any messages too...
    
    global messages;
    
    info.messages = get(messages,'String');
    
    set(messages,'String',{});  % clear messages after saving...
    set(messages,'ListBoxTop',1);
    set(messages,'Value',1);
    
    % and the notes
    
    info.usernotes = handles.notestxt.String;
    handles.notestxt.String = '';
    
    save(fn,'info');
    
    if(sbconfig.autoinc);
        global experiment
        experiment = str2double(handles.expt.String)+1;
        handles.expt.String = sprintf('%03d',experiment);
    end
    
end

function edit15_Callback(hObject, eventdata, handles)
% hObject    handle to edit15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit15 as text
%        str2double(get(hObject,'String')) returns contents of edit15 as a double


% --- Executes during object creation, after setting all properties.
function edit15_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox6.
function checkbox6_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox6


% --- Executes on button press in checkbox7.
function checkbox7_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox7


% --- Executes on key press with focus on scanboxfig and none of its controls.
function scanboxfig_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to scanboxfig (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in zerobutton.
function zerobutton_Callback(hObject, eventdata, handles)
% hObject    handle to zerobutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global origin dmpos

choice = questdlg('Warning! This action will bring the objective to its vertical position. Make sure there is space around for it to move. Do you want to proceed?', ...
    'scanbox', ...
    'Yes','No','No');
% Handle response
switch choice
    case 'Yes'
        set(hObject,'ForegroundColor',[1 0 0]);
        drawnow;
        
        r = tri_send('RUN',1,0,1);
        r = tri_send('GAS',0,0,0);      % wait for application to stop
        r = bitand(uint32(r.value),hex2dec('ff000000'));
        while(r ~= 0)% bug in TMC 610 return codes!
            r = tri_send('GAS',0,0,0);
            r = bitand(uint32(r.value),hex2dec('ff000000'));
        end
        
        for(i=0:3)
            r = tri_send('GAP',1,i,0);
            origin(i+1) = r.value;
        end
        
        dmpos = origin;
        
        set(handles.xpos,'String','0.00');
        set(handles.ypos,'String','0.00');
        set(handles.zpos,'String','0.00');
        set(handles.thpos,'String','0.00');
        
        set(hObject,'ForegroundColor',[0 0 0]);
        drawnow;
        
    case 'No'
end





% --- Executes on button press in originbutton.
function originbutton_Callback(hObject, eventdata, handles)
% hObject    handle to originbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if(hObject.Value)
    for(i=0:2)
        tri_send('SAP',204,0,1);
    end
else
    for(i=0:2)
        tri_send('SAP',204,0,0);
    end
end



% --- Executes on selection change in pmtdisp.
function pmtdisp_Callback(hObject, eventdata, handles)
% hObject    handle to pmtdisp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmtdisp contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmtdisp

% reset accumulator automatically...

global accd accdB img0_h captureDone;

if(captureDone)
    if(~isempty(accd))
        switch(hObject.Value)
            case 1
                img0_h.CData(:,:,1) = 0;
                img0_h.CData(:,:,2) =  uint8(255-uint8(255*accd'));
                img0_h.CData(:,:,3) = 0;
                
            case 2
                
                img0_h.CData(:,:,1) = uint8(255-uint8(255*accdB'));
                img0_h.CData(:,:,2) = 0;
                img0_h.CData(:,:,3) = 0;
                
            case 3
                
                img0_h.CData(:,:,1) = uint8(255-uint8(255*accdB'));
                img0_h.CData(:,:,2) = uint8(255-uint8(255*accd'));
                img0_h.CData(:,:,3) = 0;
        end
    end
else
    switch(hObject.Value)
        case 1
            img0_h.CData(:,:,[1 3])=0;
            
        case 2
            img0_h.CData(:,:,[2 3])=0;
            
        case 3
            
    end
end


% --- Executes during object creation, after setting all properties.
function pmtdisp_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmtdisp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global pmtdisp_h;

pmtdisp_h = hObject;

% --- Executes during object creation, after setting all properties.
function image0_CreateFcn(hObject, eventdata, handles)
% hObject    handle to image0 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate image0

global img0_h img0_axis cm;

% colormaps

global cm;

axis(hObject);
cm = gray(256);
cm(end,:) = [1 0 0]; % saturation signal
cm = flipud(cm);
colormap(cm);
img0_h = imshow(ones([512 796 3],'uint8'));
axis off image


% --- Executes on slider movement.
function slider3_Callback(hObject, eventdata, handles)
% hObject    handle to slider3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function pix_histo_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pix_histo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate pix_histo

global histo_h;

histo_h = hObject;

% % --- Executes on button press in camerabox.
function camerabox_Callback(hObject, eventdata, handles)
% hObject    handle to camerabox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of camerabox

global vid img0_h cm dalsa sbconfig dalsa_src cellpoly nlines;

sb_mirror(get(hObject,'Value')-1);

if(sbconfig.portcamera==1)
    
    if(get(hObject,'Value'))
        hObject.UserData = img0_h.CData;
        dimensions = dalsa.VideoResolution; % modified by JZ, added
        img0_h.XData = [1 dimensions(1)]; % modified by JZ, added
        img0_h.YData = [1 dimensions(2)]; % modified by JZ, added
        set(img0_h.Parent,'XLim',[0 dimensions(1)],'YLim',[0 dimensions(2)]); % modified by JZ, added
        %set(img0_h.Parent,'xlim',[0 dalsa_src.CUR_HRZ_SZE-1],'ylim',[0 dalsa_src.CUR_VER_SZE-1]);
        % dalsa_src.ExposureTimeRaw = dalsa_src.MaxExposure;
        %eval(sprintf('%s_me(%f)',sbconfig.pathcamera,1.0));   % maxexposure camera % modified by JZ, commented out
        cellfun(@(x) set(x,'Visible','off'),cellpoly);
        preview(dalsa,img0_h);
        set(handles.dalsa_exposure,'Value',1.0);
    else
        closepreview(dalsa);
        img0_h.CData = hObject.UserData;
        cellfun(@(x) set(x,'Visible','on'),cellpoly);
        img0_h.XData = [1 796]; % modified by JZ, added
        img0_h.YData = [1 nlines]; % modified by JZ, added
        set(img0_h.Parent,'XLim',[0 796],'YLim',[0 nlines]); % modified by JZ, added
        %set(img0_h,'xlim',[0.5 795.5],'ylim',[0.5 511.5]);
    end
end


% --- Executes during object creation, after setting all properties.
function shutterbutton_CreateFcn(hObject, eventdata, handles)
% hObject    handle to shutterbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global shutter_h;

shutter_h = hObject;

% laser_send(sprintf('SHUTTER=%d',get(hObject,'Value')));


% --- Executes when user attempts to close scanboxfig.
function scanboxfig_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to scanboxfig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure

global scanbox_h ltimer ptimer sbconfig;


istep = 1;
cprintf('\n');
cprintf('*blue','Scanbox Yeti (v3.3) - by Dario Ringach (darioringach@me.com)\n');
cprintf('blue','Visit the blog at: ')
cprintf('hyperlink','https://scanbox.org/\n')
cprintf('\n');
beep;
pause(2);

[~, ~] = system('netsh interface set interface "The World" ENABLED');

cprintf('*comment','[%02d] Deleting timer objects\n',istep); istep=istep+1;

delete(ltimer);
delete(ptimer);
delete(hObject);

cprintf('*comment','[%02d] Making PMT gains zero\n',istep); istep=istep+1;

sb_gain1(0); % make sure pmt gains are zero on exit...
sb_gain0(0);

cprintf('*comment','[%02d] Moving mirror into default position\n',istep); istep=istep+1;

sb_mirror(0); % make sure camera path enabled upon shutdown

cprintf('*comment','[%02d] Enforce normal resonant mode\n',istep); istep=istep+1;
sb_continuous_resonant(0);

cprintf('*comment','[%02d] Closing Scanbox communication \n',istep); istep=istep+1;

sb_close();
cprintf('*comment','[%02d] Closing motor controller communication \n',istep); istep=istep+1;

tri_close();
cprintf('*comment','[%02d] Closing laser communication \n',istep); istep=istep+1;

laser_close();
cprintf('*comment','[%02d] Closing quadrature encoder communication \n',istep); istep=istep+1;

quad_close();
cprintf('*comment','[%02d] Closing UDP communication \n',istep); istep=istep+1;

udp_close();

if(sbconfig.nroi_parallel)
    cprintf('*comment','[%02d] Closing parallel pool\n',istep); istep=istep+1;

    delete(gcp); % shutdown parallel pool
end

if(sbconfig.gpu_pages>0)
    cprintf('*comment','[%02d] Resetting GPU\n',istep); istep=istep+1;
    gpuDevice(sbconfig.gpu_dev);
end

cprintf('*comment','[%02d] Unload digitizer library\n',istep); istep=istep+1;
unloadlibrary('ATSApi')

cprintf('*comment','[%02d] Reset image acquisition\n',istep); istep=istep+1;
imaqreset

cprintf('*comment','[%02d] Clear Matlab workplace\n\n',istep); istep=istep+1;

clear all;      % clear all vars just in case... shutdown

cprintf('*comment','Scanbox shutdown successfully. Good bye!\n');

% --- Executes during object creation, after setting all properties.
function scanboxfig_CreateFcn(hObject, eventdata, handles)
% hObject    handle to scanboxfig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global scanbox_h seg;

scanbox_h = hObject;
p = get(0,'screensize');
q = get(hObject,'Position');
q(1:2) = p(3:4)/2 - q(3:4)/2;
set(hObject,'Position',q)
seg = [];
scanbox_config;

% --- Executes on button press in timebin.
function timebin_Callback(hObject, eventdata, handles)
% hObject    handle to timebin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of timebin


% --- Executes on selection change in tfilter.
function tfilter_Callback(hObject, eventdata, handles)
% hObject    handle to tfilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns tfilter contents as cell array
%        contents{get(hObject,'Value')} returns selected item from tfilter


% --- Executes during object creation, after setting all properties.
function tfilter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tfilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global tfilter_h;

tfilter_h = hObject;


% --- Executes on button press in pix_histo.
function histbox_Callback(hObject, eventdata, handles)
% hObject    handle to pix_histo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of pix_histo


% --- Executes during object creation, after setting all properties.
function histbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pix_histo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global histbox_h;

histbox_h = hObject;


% --- Executes during object deletion, before destroying properties.
function scanboxfig_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to scanboxfig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in sfilter.
function sfilter_Callback(hObject, eventdata, handles)
% hObject    handle to sfilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns sfilter contents as cell array
%        contents{get(hObject,'Value')} returns selected item from sfilter


% --- Executes during object creation, after setting all properties.
function sfilter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sfilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in text14.
function text14_Callback(hObject, eventdata, handles)
% hObject    handle to text14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

zoom(scanbox_h,'off');      % make sure the zoom is off...
pan(scanbox_h,'off');
scanboxfig_WindowKeyPressFcn(hObject, '@', handles);

%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')



% --- Executes on button press in text15.
function text15_Callback(hObject, eventdata, handles)
% hObject    handle to text15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

zoom(scanbox_h,'off');      % make sure the zoom is off...
pan(scanbox_h,'off');
scanboxfig_WindowKeyPressFcn(hObject, '#', handles);
%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')


% --- Executes on button press in text16.
function text16_Callback(hObject, eventdata, handles)
% hObject    handle to text16 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

zoom(scanbox_h,'off');      % make sure the zoom is off...
pan(scanbox_h,'off');
scanboxfig_WindowKeyPressFcn(hObject, '$', handles);

%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')


% --- Executes on button press in text17.
function text17_Callback(hObject, eventdata, handles)
% hObject    handle to text17 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

zoom(scanbox_h,'off');      % make sure the zoom is off...
pan(scanbox_h,'off');
scanboxfig_WindowKeyPressFcn(hObject, '%', handles);
%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')


% --- Executes on button press in focusb.
function focusb_Callback(hObject, eventdata, handles)
% hObject    handle to focusb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


grabb_Callback(hObject, eventdata, handles); % Call the grab button... with my own info


% --- Executes on button press in pushbutton23.
function pushbutton23_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton23 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton24.
function pushbutton24_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton24 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global acc gtime;
acc = [];
gtime = 1;

%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');


% --- Executes on button press in pushbutton25.
function pushbutton25_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton25 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h img0_axis p1 p2 seg scanbox_h;

N = 25; % size of cell neighborhood....

z = img0_h.CData;   % keep original image

if(isempty(seg))
    seg.ncell = 0;
    seg.boundary = {};
    seg.pixels = {};
    seg.img = zeros(size(z)); % segmentation image
    i = 1;
else
    i = seg.ncell + 1;  % append cells...
end


axis(img0_axis);
x=round(ginput_c(1));
while(~isempty(x))
    hold on;
    plot(x(1),x(2),'r.','Tag','ctr','markersize',15);
    q = z((x(2)-N):(x(2)+N),(x(1)-N):(x(1)+N));
    m = cellseg(-double(q),p1,p2);
    if(~sum(m.mask(:))==0)
        seg.img((x(2)-N+1):(x(2)+N-1),(x(1)-N+1):(x(1)+N)-1) = m.mask*i;
        seg.pixels{i} = find(seg.img == i);
        i = i+1;
    end
    x = round(ginput_c(1));
end
hold off;
set(scanbox_h,'pointer','arrow');


seg.ncell = (i-1);

% delete centers and draw boundaries...

%  h = get(get(img0_h,'Parent'),'Children');
%  delete(h(1:end-1));

%%%drawnow;

h = get(get(img0_h,'Parent'),'Children');
delete(findobj(h,'tag','ctr'));

axis(img0_axis);
hold on;
for(i=1:seg.ncell)
    B{i} = bwboundaries(seg.img==i);
    b = B{i};
    for(j=1:length(b))
        bb = b{j};
        plot(bb(:,2),bb(:,1),'-','tag','bound','UserData',i,'color',[1 0.7 0]);
    end
end

if(seg.ncell>0)
    seg.boundary = B;
    cstr = {};
    m=1;
    for(k=1:seg.ncell)
        if(~isempty(seg.boundary{k}))
            cstr{m} = num2str(k);
            m = m+1;
        end
    end
    set(handles.alist,'String',cstr,'Value',1);
else
    set(handles.alist,'String','','Value',1);
end

set(handles.cell_d,'String','','Value',1);




function edit17_Callback(hObject, eventdata, handles)
% hObject    handle to edit17 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit17 as text
%        str2double(get(hObject,'String')) returns contents of edit17 as a double


% --- Executes during object creation, after setting all properties.
function edit17_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit17 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit18_Callback(hObject, eventdata, handles)
% hObject    handle to edit18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit18 as text
%        str2double(get(hObject,'String')) returns contents of edit18 as a double


% --- Executes during object creation, after setting all properties.
function edit18_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in alist.
function alist_Callback(hObject, eventdata, handles)
% hObject    handle to alist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns alist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from alist

global seg img0_h lastsel;

h = get(get(img0_h,'Parent'),'Children');
h = findobj(h,'tag','bound');
sel = get(hObject,'Value');
str = get(hObject,'String');
if(~isempty(str))
    sel = str2num(str{sel});
    lastsel = sel;
    for(i=1:length(h))
        if(get(h(i),'UserData')==sel)
            set(h(i),'linewidth',3);
        else
            set(h(i),'linewidth',1);
        end
    end
end








% --- Executes during object creation, after setting all properties.
function alist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to alist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'String',{},'Value',0);

global alist_h
alist_h = hObject;


% --- Executes on selection change in cell_d.
function cell_d_Callback(hObject, eventdata, handles)
% hObject    handle to cell_d (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns cell_d contents as cell array
%        contents{get(hObject,'Value')} returns selected item from cell_d

global seg img0_h lastsel;

h = get(get(img0_h,'Parent'),'Children');
h = findobj(h,'tag','bound');
sel = get(hObject,'Value');
str = get(hObject,'String');
if(~isempty(str))
    sel = str2num(str{sel});
    lastsel = sel;
    for(i=1:length(h))
        if(get(h(i),'UserData')==sel)
            set(h(i),'linewidth',3);
        else
            set(h(i),'linewidth',1);
        end
    end
end


% --- Executes during object creation, after setting all properties.
function cell_d_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cell_d (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton26.
function pushbutton26_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton26 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% remove selection from first list

cella = handles.alist;
idx = get(cella,'value');
l = get(cella,'String');
v = l{idx};
l(idx) = [];
set(cella,'String',l,'Value',1)

%add it to the second one...

celld = handles.cell_d;
l = get(celld,'String');
l{end+1} = v;
set(celld,'String',l,'Value',1);


% --- Executes on button press in pushbutton27.
function pushbutton27_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton27 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



celld = handles.cell_d;
idx = get(celld,'value');
l = get(celld,'String');
v = l{idx};
l(idx) = [];
set(celld,'String',l,'Value',1)

%add it to the second one...

cella = handles.alist;
l = get(cella,'String');
l{end+1} = v;
set(cella,'String',l,'Value',1);




% --- Executes on button press in pushbutton28.
function pushbutton28_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton28 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

cella = handles.alist;
la = get(cella,'String');
set(cella,'String',{},'Value',1)

%add it to the second one...

celld = handles.cell_d;
set(celld,'String',la,'Value',1);



% --- Executes on button press in pushbutton29.
function pushbutton29_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton29 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

celld = handles.cell_d;
ld = get(celld,'String');
set(celld,'String',{},'Value',1);

%add it to the second one...

cella = handles.alist;
set(cella,'String',ld,'Value',1);


% --- Executes during object creation, after setting all properties.
function roi_traces_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roi_traces (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate roi_traces

global roi_traces_h trace_idx trace_period;

axis(hObject);
delete(get(hObject,'children'));
roi_traces_h = hObject;
trace_idx = 1;
trace_period = 300; % how many points in the trace....
xlim(hObject,[1 trace_period]);
axis(hObject,'normal','off');


% trace_img = imshow(254*ones(300,796,'uint8'));
% axis(hObject,'off','image');


function animal_Callback(hObject, eventdata, handles)
% hObject    handle to animal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of animal as text
%        str2double(get(hObject,'String')) returns contents of animal as a double

global animal datadir;

animal = get(hObject,'String');

if(~exist([datadir filesep animal],'dir'))
    r = questdlg('Directory does not exist. Do you want to create it?','Question','Yes','No','Yes');
    switch(r)
        case 'Yes'
            mkdir([datadir filesep animal]);
    end
end

% --- Executes during object creation, after setting all properties.
function animal_CreateFcn(hObject, eventdata, handles)
% hObject    handle to animal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global animal;
animal ='xx0';


function expt_Callback(hObject, eventdata, handles)
% hObject    handle to expt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of expt as text
%        str2double(get(hObject,'String')) returns contents of expt as a double

global experiment;

experiment = str2double(hObject.String);

% --- Executes during object creation, after setting all properties.
function expt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to expt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global experiment;
experiment = 0;


function edit21_Callback(hObject, eventdata, handles)
% hObject    handle to edit21 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit21 as text
%        str2double(get(hObject,'String')) returns contents of edit21 as a double


% --- Executes during object creation, after setting all properties.
function edit21_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit21 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in savesel.
function savesel_Callback(hObject, eventdata, handles)
% hObject    handle to savesel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns savesel contents as cell array
%        contents{get(hObject,'Value')} returns selected item from savesel

global savesel;

savesel= get(hObject,'Value');



% --- Executes during object creation, after setting all properties.
function savesel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to savesel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global savesel;
savesel = 2;


% --- Executes during object creation, after setting all properties.
function dirname_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dirname (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global datadir animal expt trial

datadir = 'c:\2pdata';
animal = 'xx0';
expt = 0;
trial = 0;


% --- Executes during object creation, after setting all properties.
function laserbutton_CreateFcn(hObject, eventdata, handles)
% hObject    handle to laserbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% laser_send(sprintf('LASER=%d',get(hObject,'Value')));

global laser_h;

laser_h = hObject;


% --- Executes on slider movement.
function low_Callback(hObject, eventdata, handles)
% hObject    handle to low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
end




% --- Executes during object creation, after setting all properties.
function low_CreateFcn(hObject, eventdata, handles)
% hObject    handle to low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function high_Callback(hObject, eventdata, handles)
% hObject    handle to high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider



global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
end


% --- Executes during object creation, after setting all properties.
function high_CreateFcn(hObject, eventdata, handles)
% hObject    handle to high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function gamma_Callback(hObject, eventdata, handles)
% hObject    handle to gamma (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
end


% --- Executes during object creation, after setting all properties.
function gamma_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gamma (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function grabb_CreateFcn(hObject, eventdata, handles)
% hObject    handle to grabb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global grabb_h;

grabb_h = hObject;


function gencm(low,high,gamma)

global cm scanbox_h;

x = (1:256)';
low = round(low*length(x));
high = round(high*length(x));

y(1:low*length(x)) = 0;
y(high+1:end) = 1;

y = (x-low).^gamma /(high-low)^gamma;
y(1:low) = 0;
y(high:end) = 1;

cm = repmat(y,[1 3]);
cm(end,2:3) = 0;  % red

cm = flipud(cm);

colormap(scanbox_h,cm); % set colormap


function appendcm(low,high,gamma)

global cm scanbox_h;

x = (1:256)';
low = round(low*length(x));
high = round(high*length(x));

y(1:low*length(x)) = 0;
y(high+1:end) = 1;

y = (x-low).^gamma /(high-low)^gamma;
y(1:low) = 0;
y(high:end) = 1;

cmold = cm;

cm = repmat(y,[1 3]);
cm(end,2:3) = 0;  % red

cm = flipud(cm);

cm = [cmold(2:2:end,:) ; cm(2:2:end,:)];

colormap(scanbox_h,cm); % set colormap



function unit_Callback(hObject, eventdata, handles)
% hObject    handle to unit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of unit as text
%        str2double(get(hObject,'String')) returns contents of unit as a double

global unit;
unit = str2num(get(hObject,'String'));


% --- Executes during object creation, after setting all properties.
function unit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to unit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


global unit;
unit = 0;


% --- Executes on button press in pushbutton30.
function pushbutton30_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton30 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% just get the laser status and print it...

set(handles.lstatus,'String',laser_status);


function laser_cb(obj,~)
global lstatus;
set(lstatus,'String',laser_status);


function pos_cb(obj,~)
global tri_pos dmpos origin xpos_h ypos_h zpos_h thpos_h motor_gain

if(tri_pos.Data(1))
    if(tri_pos.Data(1)==1)
        dmpos = double(tri_pos.Data(2:end))';
    else
        origin = double(tri_pos.Data(2:end))';
    end
    v = motor_gain .* (dmpos - origin);
    zpos_h.String=sprintf('%.2f',v(1));
    ypos_h.String=sprintf('%.2f',v(2));
    xpos_h.String=sprintf('%.2f',v(3));
    thpos_h.String=sprintf('%.2f',v(4));
    tri_pos.Data(1)=0;
    drawnow;
end

function qmotion_cb(obj,~)
global qserial axis_sel scanbox_h;

if(qserial.bytesavailable>0)
    cmd = fread(qserial,qserial.bytesavailable);
    h = guidata(scanbox_h);
    for(i=1:length(cmd))
        switch cmd(i)
            case 64 % x-
                if(axis_sel ~= 2)
                    eventdata.EventName = '@';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = '!';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            case 65 % x+
                
                if(axis_sel ~= 2)
                    eventdata.EventName = '@';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = ')';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
                
            case 32 % z-
                if(axis_sel ~= 0)
                    eventdata.EventName = '$';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = '!';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            case 33 % z+
                
                if(axis_sel ~= 0)
                    eventdata.EventName = '$';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = ')';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            case 16 % y-
                
                if(axis_sel ~= 1)
                    eventdata.EventName = '#';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = ')';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            case 17 % y+
                if(axis_sel ~= 1)
                    eventdata.EventName = '#';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = '!';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            otherwise
                
                sw = dec2bin(cmd(i)-240,4);
                
                if(sw(1)=='0' &&  sw(2)=='0')
                    set(h.popupmenu3,'Value',3);
                end
                if(sw(1)=='1' &&  sw(2)=='0')
                    set(h.popupmenu3,'Value',3);
                end
                if(sw(1)=='0' &&  sw(2)=='1')
                    set(h.popupmenu3,'Value',2);
                end
                if(sw(1)=='1' &&  sw(2)=='1')
                    set(h.popupmenu3,'Value',1);
                end
                
                popupmenu3_Callback(h.popupmenu3, [], h);
                
                if(sw(3)=='0' &&  sw(4)=='0')
                    set(h.rotated,'Value',3);
                end
                if(sw(3)=='1' &&  sw(4)=='0')
                    set(h.rotated,'Value',3);
                end
                if(sw(3)=='0' &&  sw(4)=='1')
                    set(h.rotated,'Value',2);
                end
                if(sw(3)=='1' &&  sw(4)=='1')
                    set(h.rotated,'Value',1);
                end
                
        end
    end
end



% --- Executes on button press in pushbutton32.
function pushbutton32_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton32 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h animal experiment unit;

img = img0_h.CData;% get current image

save('img.mat','img');
[FileName,PathName] = uiputfile('*.mat');
if(~isempty(FileName))
    save([PathName FileName],'img');
end

% --- Executes on button press in pushbutton35.
function pushbutton35_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton35 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;
zoom(scanbox_h,'toggle');


% --- Executes on button press in pushbutton36.
function pushbutton36_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton36 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global scanbox_h;

pan(scanbox_h,'toggle');


% --- Executes on button press in pushbutton37.
function pushbutton37_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton37 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h img0_h;

zoom(scanbox_h,'off');
pan(scanbox_h,'off');

%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')


% --- Executes on button press in pushbutton38.
function pushbutton38_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton38 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global cm scanbox_h img0_h;

cm = flipud(gray(256));
newcm = histeq(img0_h.Cdata,cm);
cm(end,:) = [1 0.5 0];

colormap(scanbox_h,cm); % set colormap
drawnow;


% --- Executes on selection change in popupmenu10.
function popupmenu10_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu10 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu10


% --- Executes during object creation, after setting all properties.
function popupmenu10_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function slider13_Callback(hObject, eventdata, handles)
% hObject    handle to slider13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider13_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider14_Callback(hObject, eventdata, handles)
% hObject    handle to slider14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider14_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in rotated.
function rotated_Callback(hObject, eventdata, handles)
% hObject    handle to rotated (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rotated

global motormode

motormode = get(hObject,'Value');


% --- Executes on button press in pushbutton42.
function pushbutton42_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton42 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h seg;

h = get(get(img0_h,'Parent'),'Children');
delete(findobj(h,'tag','bound'));
h = get(get(img0_h,'Parent'),'Children');
delete(findobj(h,'tag','pt'));

seg =[];
set(handles.alist,'String',[]);
set(handles.cell_d,'String',[]);




% --- Executes on button press in pushbutton43.
function pushbutton43_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton43 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h


[FileName,PathName] = uigetfile('*.mat');
load([PathName FileName],'img','-mat');
img0_h.CData = img;


function p1_Callback(hObject, eventdata, handles)
% hObject    handle to p1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of p1 as text
%        str2double(get(hObject,'String')) returns contents of p1 as a double

global p1;

p1 = str2num(get(hObject,'String'));



% --- Executes during object creation, after setting all properties.
function p1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to p1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global p1;
p1 = 0.6;




function p2_Callback(hObject, eventdata, handles)
% hObject    handle to p2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of p2 as text
%        str2double(get(hObject,'String')) returns contents of p2 as a double
global p2;

p2 = str2num(get(hObject,'String'));

% --- Executes during object creation, after setting all properties.
function p2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to p2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global p2;
p2 = 30;


% --- Executes on button press in pushbutton44.
function pushbutton44_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton44 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h lastsel seg;

h = get(get(img0_h,'Parent'),'Children');
h = findobj(h,'tag','bound');

seg.boundary{lastsel} = {};
seg.pixels{lastsel} = {};
for(i=1:length(h))
    if(get(h(i),'UserData')==lastsel)
        delete(h(i));
        seg.img(seg.img==lastsel)=0;
    end
end


str = get(handles.alist,'String');
idx = find(strcmp(num2str(lastsel),str));
if(~isempty(idx))
    str(idx) = [];
    set(handles.alist,'String',str,'Value',1);
end


str = get(handles.cell_d,'String');
idx = find(strcmp(num2str(lastsel),str));
if(~isempty(idx))
    str(idx) = [];
    set(handles.cell_d,'String',str,'Value',1);
end



function restore_seg

global seg img0_h img0_axis;


if(~isempty(seg))
    
    axis(get(img0_h,'Parent'));
    hold on;
    for(i=1:seg.ncell)
        b = seg.boundary{i};
        if(~isempty(b))
            for(j=1:length(b))
                bb = b{j};
                plot(bb(:,2),bb(:,1),'-','tag','bound','UserData',i,'color',[1 0.7 0]);
            end
        end
    end
    hold off;
    
end


% --- Executes on slider movement.
function tracegain_Callback(hObject, eventdata, handles)
% hObject    handle to tracegain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global trace_gain;

trace_gain = get(hObject,'Value');

% --- Executes during object creation, after setting all properties.
function tracegain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tracegain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

global trace_gain;

trace_gain = 1;

% --- Executes on button press in traceon.
function traceon_Callback(hObject, eventdata, handles)
% hObject    handle to traceon (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of traceon



function p3_Callback(hObject, eventdata, handles)
% hObject    handle to p3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of p3 as text
%        str2double(get(hObject,'String')) returns contents of p3 as a double


% --- Executes during object creation, after setting all properties.
function p3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to p3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function p4_Callback(hObject, eventdata, handles)
% hObject    handle to p4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of p4 as text
%        str2double(get(hObject,'String')) returns contents of p4 as a double


% --- Executes during object creation, after setting all properties.
function p4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to p4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function tpos_Callback(hObject, eventdata, handles)
% hObject    handle to tpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function tpos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function messages_CreateFcn(hObject, eventdata, handles)
% hObject    handle to messages (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global messages;

messages = hObject;



% --- Executes on button press in autostab.
function autostab_Callback(hObject, eventdata, handles)
% hObject    handle to autostab (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of autostab

global autostab img0_axis img0_h refs refctr Ns;

if(autostab)
    set(hObject,'String','Image Stabilization Off')
    autostab = 0;
    refs = [];
    refctr = [];
    delete(findobj(get(get(img0_h,'parent'),'children'),'tag','abox'));
else
    set(hObject,'String','Image Stabilization On')
    autostab = 1;
    axis(img0_axis);
    x=round(ginput_c(1));
    img = img0_h.CData;
    refs = double(img(x(2)-Ns:x(2)+Ns,x(1)-Ns:x(1)+Ns));
    refs = refs - mean(refs(:));
    hold on
    plot([x(1)-Ns x(1)+Ns x(1)+Ns x(1)-Ns x(1)-Ns],[x(2)-Ns x(2)-Ns x(2)+Ns x(2)+Ns x(2)-Ns],'r:','tag','abox','linewidth',2)
    hold off;
    refctr = x;
end

% set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
%
% drawnow;
% WindowAPI(handles.scanboxfig,'setfocus')




% --- Executes during object creation, after setting all properties.
function autostab_CreateFcn(hObject, eventdata, handles)
% hObject    handle to autostab (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global autostab Ns;

autostab=0;
Ns = 30;


function msg = laser_status

global laser_h shutter_h wave_h sbconfig;

msg = {};

switch sbconfig.laser_type
    
    case 'CHAMELEON'
        
        r = laser_send('PRINT LASER');
        
        switch(r(end))
            case '0'
                %msg = [msg 'Laser is in standby'];
                set(laser_h,'String','Laser is off','FontWeight','Normal','Value',0);
            case '1'
                %msg = [msg 'Laser in on'];
                set(laser_h,'String','Laser is on','FontWeight','Bold','Value',1);
            case '2'
                msg{end+1} = 'Laser of due to fault!';
        end
        
        
        r = laser_send('PRINT KEYSWITCH');
        switch(r(end))
            case '0'
                msg{end+1} = 'Key is off';
            case '1'
                msg{end+1} = 'Key is on';
        end
        
        r = laser_send('PRINT SHUTTER');
        switch(r(end))
            case '0'
                %msg = [msg sprintf('\n') 'Shutter is closed'];
                set(shutter_h,'String','Shutter closed','FontWeight','Normal','Value',0);
                
            case '1'
                %msg = [msg sprintf('\n') 'Shutter is open'];
                set(shutter_h,'String','Shutter open','FontWeight','Bold','Value',1);
        end
        
        r = laser_send('PRINT TUNING STATUS');
        switch(r(end))
            case '0'
                msg{end+1} = 'Tuning is ready';
            case '1'
                msg{end+1} = 'Tuning in progress';
            case '2'
                msg{end+1} = 'Search for modelock in progress';
            case '3'
                msg{end+1} = 'Recovery in progress';
        end
        
        
        r = laser_send('PRINT MODELOCKED');
        switch(r(end))
            case '0'
                msg{end+1} = 'Standby...';
            case '1'
                msg{end+1} = 'Modelocked!';
            case '2'
                msg{end+1} = 'CW';
        end
        
        
        case 'DISCOVERY'
        
        r = laser_send('PRINT LASER');
        
        switch(r(end))
            case '0'
                %msg = [msg 'Laser is in standby'];
                set(laser_h,'String','Laser is off','FontWeight','Normal','Value',0);
            case '1'
                %msg = [msg 'Laser in on'];
                set(laser_h,'String','Laser is on','FontWeight','Bold','Value',1);
            case '2'
                msg{end+1} = 'Laser of due to fault!';
        end
        
        
        r = laser_send('PRINT KEYSWITCH');
        switch(r(end))
            case '0'
                msg{end+1} = 'Key is off';
            case '1'
                msg{end+1} = 'Key is on';
        end
        
        r = laser_send('PRINT SHUTTER');
        switch(r(end))
            case '0'
                %msg = [msg sprintf('\n') 'Shutter is closed'];
                set(shutter_h,'String','Shutter closed','FontWeight','Normal','Value',0);
                
            case '1'
                %msg = [msg sprintf('\n') 'Shutter is open'];
                set(shutter_h,'String','Shutter open','FontWeight','Bold','Value',1);
        end
        
        
        r = laser_send('PRINT TUNING STATUS');
        switch(r(end))
            case '0'
                msg{end+1} = 'Tuning is ready';
            case '1'
                msg{end+1} = 'Tuning in progress';
            case '2'
                msg{end+1} = 'Search for modelock in progress';
            case '3'
                msg{end+1} = 'Recovery in progress';
        end
        
        
        r = laser_send('PRINT MODELOCKED');
        r = r(1:end-1);
        switch(r(end))
            case '0'
                msg{end+1} = 'Standby...';
            case '1'
                msg{end+1} = 'Modelocked!';
            case '2'
                msg{end+1} = 'CW';
        end
        
    case 'MAITAI'
        
        r = laser_send('SHUTTER?');
        switch(r(end))
            case '0'
                set(shutter_h,'String','Shutter closed','FontWeight','Normal','Value',0);
                
            case '1'
                set(shutter_h,'String','Shutter open','FontWeight','Bold','Value',1);
        end
        
        r = laser_send('READ:PCTWARMEDUP?');
        msg = r;
        
        r = laser_send('READ:WAVELENGTH?');
        msg = [msg sprintf('\n') r];
        
end




% --- Executes on button press in pushbutton46.
function pushbutton46_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton46 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Removed!
% switch(questdlg('Do you really want to retract the objective?'))
%     case 'Yes'
%         r = tri_send('SAP',4,0,1000);   % change velocity/acceleration for 'z'
%         r = tri_send('SAP',5,0,1000);
%         r = tri_send('MVP',1,0,128041);
%
%         pause(6);
%
%         popupmenu3_Callback(handles.popupmenu3,[],handles); % restore velocity
%         eventdata.EventName = '2';                          % select 'x' and update position...
%         scanboxfig_WindowKeyPressFcn(hObject, eventdata, handles);
% end


% --- Executes on slider movement.
function slider18_Callback(hObject, eventdata, handles)
% hObject    handle to slider18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global boardHandle;

retCode = ...
    calllib('ATSApi', 'AlazarSetExternalClockLevel', ...
    boardHandle,		 ...	% HANDLE -- board handle
    double(get(hObject,'Value'))			 ...	% U32 --level in percent
    )



% --- Executes during object creation, after setting all properties.
function slider18_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


function udp_open

global sb_server;

if(~isempty(sb_server))
    udp_close;
end
sb_server=udp('localhost', 'LocalPort', 7000,'BytesAvailableFcn',@udp_cb);

fopen(sb_server);


function udp_close

global sb_server;

try
    fclose(sb_server);
    delete(sb_server);
catch
    sb_server = [];
end


function udp_cb(a,b)

global scanbox_h messages captureDone frames;

s = fgetl(a);   % read the message

switch(s(1))
    
    case 'A'                % set animal name
        an = s(2:end);
        h = findobj(scanbox_h,'Tag','animal');
        set(h,'String',an);
        f = get(h,'Callback');
        f(h,guidata(h));
        
    case 'E'                % set experiment number
        e = s(2:end);
        h = findobj(scanbox_h,'Tag','expt');
        set(h,'String',e);
        f = get(h,'Callback');
        f(h,guidata(h));
        
    case 'U'                % set unit number (imaging field numnber)
        u = s(2:end);
        h = findobj(scanbox_h,'Tag','unit');
        set(h,'String',u);
        f = get(h,'Callback');
        f(h,guidata(h));
        
    case 'L'                % programatically turn laser ON/OFF
        global org_pock
        if(s(2)~='0')
            sb_pockels(org_pock(1),org_pock(2))
        else
            sb_pockels(0,0)
        end
        
    case 'T'                % programmatically change optotune slider
        
        val = s(2:end);
        h = findobj(scanbox_h,'Tag','optoslider');
        set(h,'Value',str2double(val));
        f = get(h,'Callback');
        f(h,guidata(h));
        
    case 'M'                % add message...
        mssg = s(2:end);
        oldmssg = get(messages,'String');
        if(length(oldmssg)==0)
            set(messages,'String',{mssg});
        else
            oldmssg{end+1} = mssg;
            set(messages,'String',oldmssg,'ListBoxTop',length(oldmssg),'Value',length(oldmssg));
        end
        
    case 'C'                % clear message....
        set(messages,'String',{});
        set(messages,'ListBoxTop',1);
        set(messages,'Value',1);
        
    case 'Z'                % press the zero button in the motor position box...
        
        h = findobj(scanbox_h,'Tag','zerobutton');
        f = get(h,'Callback');
        f(h,guidata(h));  % press the zero button....
        
    case 'P'               % move axis by um relative to current position
        
        global motor_gain origin scanbox_h
        
        r = [];
        
        mssg = s(2:end);
        ax = mssg(1);
        val = str2num(mssg(2:end));
        
        switch(ax)      %% relative position command....
            case 'x'
                val = val/motor_gain(3);
                r=tri_send('MVP',1,2,val);
                s = 'xpos';
                v =  motor_gain(3) * double(r.value-origin(3));
                
            case 'y'
                val = val/motor_gain(2);
                r=tri_send('MVP',1,1,val);
                s = 'ypos';
                v =  motor_gain(2)* double(r.value-origin(2));
                
            case 'z'
                val = val/motor_gain(1);
                r=tri_send('MVP',1,0,val);
                s = 'zpos';
                v =  motor_gain(1) * double(r.value-origin(1));
        end
        
        h = findobj(scanbox_h,'Tag',s);
        set(h,'String',sprintf('%.2f',v));
        
        drawnow;
        
    case 'O'        % go to origin
        
        h = findobj(scanbox_h,'Tag','originbutton');
        f = get(h,'Callback');
        f(h,guidata(h));  % press the origin button....
        
    case 'G'        % Go ... start scanning
        h = findobj(scanbox_h,'Tag','frames');
        h.String = '0';
        drawnow;
        sb_setframe(0);
        h = findobj(scanbox_h,'Tag','grabb');
        f = get(h,'Callback');
        f(h,guidata(h));  % press the grab button....
        
    case 'S'        % Stop scanning
        
        global captureDone;
        captureDone = 1;
        
              
    case 'D'        % Set base directory...
        newdir = s(2:end);
        h = findobj(scanbox_h,'Tag','dirname');
        set(h,'String',newdir);
        
    case 'm'
        val = s(2:end);
        h = findobj(scanbox_h,'Tag','camerabox');
        set(h,'Value',str2double(val));
        f = get(h,'Callback');
        f(h,guidata(h));
        
end

% WindowAPI(handles.scanbox_fig,'setfocus');


% --- Executes on key press with focus on scanboxfig or any of its controls.
function scanboxfig_WindowKeyPressFcn(hObject, eventdata, handles)
% hObject    handle to scanboxfig (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)

% global motormode;
% 
% if(ischar(eventdata))
%     sel = eventdata;
% else
%     sel = eventdata.Character;
% end
% 
% switch sel
%     case 'a'
%         handles.rotated.Value = 3-handles.rotated.Value;
%         motormode = handles.rotated.Value;
%     case 'b'
%         handles.popupmenu3.Value = 1+ mod(handles.popupmenu3.Value,3);
%         popupmenu3_Callback(handles.popupmenu3,[],handles);
%     otherwise
% end
% 
% drawnow;


function frate_Callback(hObject, eventdata, handles)
% hObject    handle to frate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of frate as text
%        str2double(get(hObject,'String')) returns contents of frate as a double


global nlines sbconfig scanmode img0_h;

frate = str2num(get(hObject,'String'));

if(isempty(frate))
    warndlg('Frame rate must be a number.  Resetting to 10fps');
    frate = 10;
    set(hObject,'String','10.0');
end

nlines = round(sbconfig.resfreq(get(handles.magnification,'Value'))/frate)*(2-scanmode); % modified by JZ, original: sbconfig.resfreq
sb_setline(nlines);
set(handles.lines,'String',num2str(nlines));
frame_rate = sbconfig.resfreq(get(handles.magnification,'Value'))/nlines; % modified by JZ, original: sbconfig.resfreq
set(handles.frate,'String',sprintf('%2.2f',frame_rate));



% --- Executes during object creation, after setting all properties.
function frate_CreateFcn(hObject, eventdata, handles)
% hObject    handle to frate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function low1_Callback(hObject, eventdata, handles)
% hObject    handle to low1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    gencm(low,high,gamma);
end


% --- Executes during object creation, after setting all properties.
function low1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to low1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function high1_Callback(hObject, eventdata, handles)
% hObject    handle to high1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    gencm(low,high,gamma);
end

% --- Executes during object creation, after setting all properties.
function high1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to high1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function gamma1_Callback(hObject, eventdata, handles)
% hObject    handle to gamma1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    gencm(low,high,gamma);
end



% --- Executes during object creation, after setting all properties.
function gamma1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gamma1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function messages_Callback(hObject, eventdata, handles)
% hObject    handle to messages (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of messages as text
%        str2double(get(hObject,'String')) returns contents of messages as a double


% --- Executes during object creation, after setting all properties.
function edit28_CreateFcn(hObject, eventdata, handles)
% hObject    handle to messages (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function pmt1_Callback(hObject, eventdata, handles)
% hObject    handle to pmt1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

sb_gain1(uint8(255*get(hObject,'Value')));
set(handles.pmt1txt,'String',sprintf('%1.2f',get(hObject,'Value')));

% --- Executes during object creation, after setting all properties.
function pmt1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmt1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function pmt0_Callback(hObject, eventdata, handles)
% hObject    handle to pmt0 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

sb_gain0(uint8(255*get(hObject,'Value')));
set(handles.pmt0txt,'String',sprintf('%1.2f',get(hObject,'Value')));


% --- Executes during object creation, after setting all properties.
function pmt0_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmt0 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function edit29_Callback(hObject, eventdata, handles)
% hObject    handle to pmt0txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pmt0txt as text
%        str2double(get(hObject,'String')) returns contents of pmt0txt as a double


% --- Executes during object creation, after setting all properties.
function pmt0txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmt0txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit30_Callback(hObject, eventdata, handles)
% hObject    handle to pmt1txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pmt1txt as text
%        str2double(get(hObject,'String')) returns contents of pmt1txt as a double


% --- Executes during object creation, after setting all properties.
function pmt1txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmt1txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pmtenable.
function pmtenable_Callback(hObject, eventdata, handles)
% hObject    handle to pmtenable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of pmtenable

if(get(hObject,'Value'))
    set(handles.pmt0,'Enable','on');
    set(handles.pmt1,'Enable','on');
    pmt0_Callback(handles.pmt0, [], handles);
    pmt1_Callback(handles.pmt1, [], handles);
else
    set(handles.pmt0,'Enable','off');
    set(handles.pmt1,'Enable','off');
    sb_gain0(0);
    sb_gain1(0);
end


% --- Executes on button press in wc.
function wc_Callback(hObject, eventdata, handles)
% hObject    handle to wc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of wc


% configureLSB

function Configure_TTL


%
%     // Select output for LSB[0]
%     // REG_29[13..12] = 0 ==> LSB[0] = '0'  (default)
%     // REG_29[13..12] = 1 ==> LSB[0] = EXT TRIG input
%     // REG_29[13..12] = 2 ==> LSB[0] = AUX_IN[0] input
%     // REG_29[13..12] = 3 ==> LSB[0] = AUX_IN[1] input
%  
%     // select output for LSB[1]:
%     // REG_29[15..14] = 0 ==> LSB[1] = '0'  (default)
%     // REG_29[15..14] = 1 ==> LSB[1] = EXT TRIG input
%     // REG_29[15..14] = 2 ==> LSB[1] = AUX_IN[0] input
%     // REG_29[15..14] = 3 ==> LSB[1] = AUX_IN[1] input


global boardHandle;

v = libpointer('uint32Ptr',1); % value of register
newv = uint(32);               % new value...

retCode =  calllib('ATSApi', 'AlazarReadRegister', boardHandle, uint32(29), v, uint32(hex2dec('32145876')));

if (retCode ~= ApiSuccess)
    error('In AlazarReadRegister()');
end

newv = uint32(bin2dec(['1110' dec2bin(v.Value,14)]));       % write 11 10 means 3 2 -> LSB[1]= AUX_IN[1] and LSB[0] = AUX_IN[0]

retCode =  calllib('ATSApi', 'AlazarWriteRegister', boardHandle, uint32(29), newv, uint32(hex2dec('32145876')));

if (retCode ~= ApiSuccess)
    error('In AlazarWriteRegister()');
end


% --- Executes on slider movement.
function slider27_Callback(hObject, eventdata, handles)
% hObject    handle to slider27 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider27_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider27 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider28_Callback(hObject, eventdata, handles)
% hObject    handle to slider28 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider28_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider28 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on selection change in popupmenu13.
function popupmenu13_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu13 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu13


% --- Executes during object creation, after setting all properties.
function popupmenu13_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit31_Callback(hObject, eventdata, handles)
% hObject    handle to edit31 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit31 as text
%        str2double(get(hObject,'String')) returns contents of edit31 as a double




% --- Executes during object creation, after setting all properties.
function edit31_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit31 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit32_Callback(hObject, eventdata, handles)
% hObject    handle to edit32 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit32 as text
%        str2double(get(hObject,'String')) returns contents of edit32 as a double



% --- Executes during object creation, after setting all properties.
function edit32_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit32 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function edit33_Callback(hObject, eventdata, handles)
% hObject    handle to edit33 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit33 as text
%        str2double(get(hObject,'String')) returns contents of edit33 as a double



% --- Executes during object creation, after setting all properties.
function edit33_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit33 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function ot_slider_Callback(hObject, eventdata, handles)
% hObject    handle to ot_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function ot_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ot_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in pushbutton51.
function pushbutton51_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton51 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global wcam wcam_roi;
wcam.ROIPosition = wcam_roi;
preview(wcam);


% --- Executes on key press with focus on expt and none of its controls.
function expt_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to expt (see GCBO)
% eventdata  structure with the following fields (see UICONTROL)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on slider movement.
function dalsa_exposure_Callback(hObject, eventdata, handles)
% hObject    handle to dalsa_exposure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global dalsa_src sbconfig;  % can only be called is dalsa is in preview mode...

% dalsa_src.ExposureTimeRaw = dalsa_src.MaxExposure * hObject.Value;

eval(sprintf('%s_me(%f)',sbconfig.pathcamera,hObject.Value));   % max exposure camera



% --- Executes during object creation, after setting all properties.
function dalsa_exposure_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dalsa_exposure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function dalsa_gain_Callback(hObject, eventdata, handles)
% hObject    handle to dalsa_gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

% global dalsa dalsa_src img0_h;  % can only be called is dalsa is in preview mode...
%
% closepreview(dalsa);
% %dalsa_src.GainRaw = get(hObject,'Value');
% dalsa_src.DigitalGainAll = get(hObject,'Value');
% preview(dalsa,img0_h);


% --- Executes during object creation, after setting all properties.
function dalsa_gain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dalsa_gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider34_Callback(hObject, eventdata, handles)
% hObject    handle to slider34 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global dalsa dalsa_src img0_h;  % can only be called is dalsa is in preview mode...

% closepreview(dalsa);
% dalsa_src.AcquisitionFrameRateAbs = get(hObject,'Value');
% preview(dalsa,img0_h);



% --- Executes during object creation, after setting all properties.
function slider34_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider34 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


function c=scanbox_getconfig

global scanbox_h;

c.wavelength = str2num(get(findobj(scanbox_h,'Tag','wavelength'),'String'));
c.frames = str2num(get(findobj(scanbox_h,'Tag','frames'),'String'));
c.lines = str2num(get(findobj(scanbox_h,'Tag','lines'),'String'));
c.magnification = get(findobj(scanbox_h,'Tag','magnification'),'Value');
c.pmt0_gain = get(findobj(scanbox_h,'Tag','pmt0'),'Value');
c.pmt1_gain = get(findobj(scanbox_h,'Tag','pmt1'),'Value');

c.zstack.top = get(findobj(scanbox_h,'Tag','z_top'),'String');
c.zstack.bottom = get(findobj(scanbox_h,'Tag','z_top'),'String');
c.zstack.steps = get(findobj(scanbox_h,'Tag','z_steps'),'String');
c.zstack.size = get(findobj(scanbox_h,'Tag','z_size'),'String');

% --- Executes on button press in autoillum.
function autoillum_Callback(hObject, eventdata, handles)
% hObject    handle to autoillum (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function z_top_Callback(hObject, eventdata, handles)
% hObject    handle to z_top (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of z_top as text
%        str2double(get(hObject,'String')) returns contents of z_top as a double

global z_top z_bottom z_steps z_size z_vals;

z_top = str2num(get(hObject,'String'));

if(isempty(z_top))
    warndlg('Parameter should be a number.  Resetting to zero.')
    z_top = 0;
    set(hObject,'String','0');
end

z_vals = linspace(z_bottom,z_top,z_steps);
z_size = mean(diff(z_vals));
set(handles.z_size,'String',num2str(z_size));

% --- Executes during object creation, after setting all properties.
function z_top_CreateFcn(hObject, eventdata, handles)
% hObject    handle to z_top (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function z_bottom_Callback(hObject, eventdata, handles)
% hObject    handle to z_bottom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of z_bottom as text
%        str2double(get(hObject,'String')) returns contents of z_bottom as a double

global z_top z_bottom z_steps z_size z_vals;

z_bottom = str2num(get(hObject,'String'));

if(isempty(z_bottom))
    warndlg('Parameter should be a number.  Resetting to zero.')
    z_bottom = 0;
    set(hObject,'String','0');
end

z_vals = linspace(z_top,z_bottom,z_steps);
z_size = mean(diff(z_vals));
set(handles.z_size,'String',num2str(z_size));



% --- Executes during object creation, after setting all properties.
function z_bottom_CreateFcn(hObject, eventdata, handles)
% hObject    handle to z_bottom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function z_steps_Callback(hObject, eventdata, handles)
% hObject    handle to z_steps (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of z_steps as text
%        str2double(get(hObject,'String')) returns contents of z_steps as a double

global z_top z_bottom z_steps z_size z_vals;

z_steps = str2num(get(hObject,'String'));

if(isempty(z_steps))
    warndlg('Parameter should be a number.  Resetting to zero.')
    z_bottom = 0;
    set(hObject,'String','0');
end


z_vals = linspace(z_top,z_bottom,z_steps);
z_size = mean(diff(z_vals));
set(handles.z_size,'String',num2str(z_size));


% --- Executes during object creation, after setting all properties.
function z_steps_CreateFcn(hObject, eventdata, handles)
% hObject    handle to z_steps (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function z_size_Callback(hObject, eventdata, handles)
% hObject    handle to z_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of z_size as text
%        str2double(get(hObject,'String')) returns contents of z_size as a double

global z_top z_bottom z_steps z_size z_vals;

z_size = str2num(get(hObject,'String'));

if(isempty(z_size))
    warndlg('Parameter should be a number.  Resetting to zero.')
    z_size = 0;
    set(hObject,'String','0');
end

z_vals = z_top:z_size:z_bottom;
set(handles.z_steps,'String',length(z_vals));


% --- Executes during object creation, after setting all properties.
function z_size_CreateFcn(hObject, eventdata, handles)
% hObject    handle to z_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton53.
function pushbutton53_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton53 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on button press in pushbutton54.
function pushbutton54_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton54 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global z_top z_bottom z_steps z_size z_vals;
global motor_gain origin scanbox_h;
global experiment zstack_running motormode thpos_h dmpos zpos_h xpos_h ypos_h;

if(zstack_running)
    
    h = findobj(scanbox_h,'Tag','grabb');
    f = get(h,'Callback');
    f(h,guidata(h));  % press the grab button to abort...
    zstack_running = 0;
    set(hObject,'String','Acquire');
    drawnow;
    
else
    
    set(hObject,'String','Stop');
    drawnow;
    
    zstack_running = 1;
    
    z_vals = linspace(z_top,z_bottom,z_steps);
    
    if(~isempty(z_vals) && ~any(isnan(z_vals)))
        
        z_vals = [z_vals(1) diff(z_vals)];  % the differences...
        
        for(val=z_vals)
            
            if(zstack_running)
                %move the z-motor relative to the beginning...
                
                switch motormode
                    
                    case 1  % moves only in z (normal mode)
                        
                        valz = round(val/motor_gain(1));
                        r=tri_send('MVP',1,0,valz);
                        
                    case 2
                        
                        thval = str2double(thpos_h.String);
                        
                        valz = round( val/motor_gain(1))*cosd(thval);
                        r=tri_send('MVP',1,0,valz);
                        
                        valx = round(-val/motor_gain(3))*sind(thval);
                        r=tri_send('MVP',1,2,valx);
                        
                end
                
                pause(.5);                      % update reading
                
                v = zeros(1,4);
                for(i=3:-1:0)                   % let z be the last axis...
                    r = tri_send('GAP',1,i,0);
                    dmpos(i+1) = r.value;
                    v(i+1) =  motor_gain(i+1) * double(r.value-origin(i+1));  %%  (inches/rot) / (steps/rot) * 25400um
                end
                
                zpos_h.String=sprintf('%.2f',v(1));
                ypos_h.String=sprintf('%.2f',v(2));
                xpos_h.String=sprintf('%.2f',v(3));
                thpos_h.String=sprintf('%.2f',v(4));
                
                drawnow;
                
                %scan
                h = findobj(scanbox_h,'Tag','grabb');
                f = get(h,'Callback');
                f(h,guidata(h));  % press the grab button....
                
                % update file number - done by autoinc now...
                
            end
            
        end
        
    end
    
    % Done!
    zstack_running = 0;
    set(hObject,'String','Acquire');
    drawnow;
    
end


% --- Executes on button press in eyet.
function eyet_Callback(hObject, eventdata, handles)
% hObject    handle to eyet (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of eyet


% --- Executes on button press in pushbutton55.
function pushbutton55_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton55 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global eyecam eyecam_h eye_roi;

eyecam.ROIPosition = eye_roi;
eyecam_h = preview(eyecam);
colormap(ancestor(eyecam_h,'axes'),sqrt(gray(256)));


% --- Executes on button press in pushbutton56.
function pushbutton56_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton56 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global eyecam eyecam_h eye_roi;

closepreview(eyecam);
eyecam.ROIPosition = [0 0 eyecam.VideoResolution];
eye_roi = eyecam.ROIPosition;
start(eyecam);
pause(0.5);
stop(eyecam);
q = peekdata(eyecam,1);
figure('MenuBar','none','ToolBar','none','Name','Set ROI','NumberTitle','off');
imagesc(q); colormap(sqrt(gray(256))); axis off; truesize;

h = imrect(gca,[eyecam.VideoResolution/2-[320 225]/2 320 225]); % modified by SPG doubled size for eye camera (was 160 by 112)
h.setFixedAspectRatioMode(true);
h.setResizable(false);
eyecam.ROIPosition = wait(h);
eye_roi = eyecam.ROIPosition;
close(gcf);
eyecam_h = preview(eyecam);
colormap(ancestor(eyecam_h,'axes'),sqrt(gray(256)));

% --- Executes on button press in pushbutton57.
function pushbutton57_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton57 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global eyecam eyecam_h eye_roi;
closepreview(eyecam);
eyecam.ROIPosition = [0 0 eyecam.VideoResolution];
eye_roi = eyecam.ROIPosition;
eyecam_h = preview(eyecam);
colormap(ancestor(eyecam_h,'axes'),sqrt(gray(256)));


% --- Executes on slider movement.
function slider40_Callback(hObject, eventdata, handles)
% hObject    handle to slider40 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global wcam wcam_src;

closepreview(wcam);
wcam_src.Exposure = get(hObject,'Value');
preview(wcam);



% --- Executes during object creation, after setting all properties.
function slider40_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider40 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in pushbutton58.
function pushbutton58_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton58 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global wcam wcam_h wcam_roi;

closepreview(wcam);
wcam.ROIPosition = [0 0 wcam.VideoResolution];
wcam_roi = wcam.ROIPosition;
start(wcam);
pause(0.5);
stop(wcam);
q = peekdata(wcam,1);
figure('MenuBar','none','ToolBar','none','Name','Set ROI','NumberTitle','off');
imagesc(q); colormap(sqrt(gray(256))); axis off; truesize;
h = imrect(gca,[wcam.VideoResolution/2-[320 225]/2 320 225]); % modified by JZ, original: was [192 192]/2 192 192]
h.setFixedAspectRatioMode(true);
h.setFixedAspectRatioMode(true);
h.setResizable(false);
wcam.ROIPosition = wait(h);
wcam_roi = wcam.ROIPosition;
close(gcf);
wcam_h = preview(wcam);
colormap(ancestor(wcam_h,'axes'),sqrt(gray(256)));


% --- Executes on button press in pushbutton59.
function pushbutton59_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton59 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global wcam wcam_h wcam_roi;
closepreview(wcam);
wcam.ROIPosition = [0 0 wcam.VideoResolution];
wcam_roi = wcam.ROIPosition;
wcam_h = preview(wcam);
colormap(ancestor(wcam_h,'axes'),sqrt(gray(256)));


% --- Executes during object creation, after setting all properties.
function lstatus_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lstatus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global lstatus;
lstatus = hObject;


% --- Executes on button press in ttlonline.
function ttlonline_Callback(hObject, eventdata, handles)
% hObject    handle to ttlonline (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ttlonline

global ttlonline;

ttlonline = get(hObject,'Value');


% --- Executes on button press in pushbutton60.
function pushbutton60_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton60 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dmpos mpos;
mpos{1} = dmpos;

% for(i=0:3)
%     tri_send('CCO',11,i,0);
% end



% --- Executes on button press in pushbutton61.
function pushbutton61_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton61 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global mpos dmpos;

for(i=0:3)
    tri_send('SCO',0,i,mpos{1}(i+1));
end

v = zeros(4,2);

for(i=0:3)                      % current vel and acc
    r1 = tri_send('GAP',4,i,0);
    r2 = tri_send('GAP',5,i,0);
    v(i+1,1) = r1.value;
    v(i+1,2) = r2.value;
    tri_send('SAP',4,i,1200);
    tri_send('SAP',5,i,275);
end

tri_send('MVP',2,hex2dec('8f'),0);

set(hObject,'ForegroundColor',[1 0 0]);
drawnow;
st = 0;                         % wait for movement to finish
while(st==0)
    st = 1;
    for(i=0:3)
        r = tri_send('GAP',8,i,0);
        st = st * r.value;
    end
end
set(hObject,'ForegroundColor',[0 0 0]);
drawnow;


for(i=0:3)
    r1 = tri_send('SAP',4,i,v(i+1,1));
    r2 = tri_send('SAP',5,i,v(i+1,2));
end

dmpos = mpos{1};
update_pos;


% --- Executes on button press in pushbutton62.
function pushbutton62_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton62 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dmpos mpos;
mpos{2} = dmpos;

% for(i=0:3)
%     tri_send('CCO',12,i,0);
% end

% --- Executes on button press in pushbutton63.
function pushbutton63_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton63 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global mpos dmpos;

global mpos dmpos;

for(i=0:3)
    tri_send('SCO',0,i,mpos{2}(i+1));
end

v = zeros(4,2);

for(i=0:3)                      % current vel and acc
    r1 = tri_send('GAP',4,i,0);
    r2 = tri_send('GAP',5,i,0);
    v(i+1,1) = r1.value;
    v(i+1,2) = r2.value;
    tri_send('SAP',4,i,1200);
    tri_send('SAP',5,i,275);
end

tri_send('MVP',2,hex2dec('8f'),0);

set(hObject,'ForegroundColor',[1 0 0]);
drawnow;
st = 0;                         % wait for movement to finish
while(st==0)
    st = 1;
    for(i=0:3)
        r = tri_send('GAP',8,i,0);
        st = st * r.value;
    end
end
set(hObject,'ForegroundColor',[0 0 0]);
drawnow;

for(i=0:3)
    r1 = tri_send('SAP',4,i,v(i+1,1));
    r2 = tri_send('SAP',5,i,v(i+1,2));
end

dmpos = mpos{2};
update_pos;


% --- Executes on button press in pushbutton64.
function pushbutton64_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton64 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dmpos mpos;
mpos{3} = dmpos;

% for(i=0:3)
%     tri_send('CCO',13,i,0);
% end

% --- Executes on button press in pushbutton65.
function pushbutton65_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton65 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global mpos dmpos;

for(i=0:3)
    tri_send('SCO',0,i,mpos{3}(i+1));
end

v = zeros(4,2);

for(i=0:3)                      % current vel and acc
    r1 = tri_send('GAP',4,i,0);
    r2 = tri_send('GAP',5,i,0);
    v(i+1,1) = r1.value;
    v(i+1,2) = r2.value;
    tri_send('SAP',4,i,1200);
    tri_send('SAP',5,i,275);
end

tri_send('MVP',2,hex2dec('8f'),0);

set(hObject,'ForegroundColor',[1 0 0]);
drawnow;
st = 0;                         % wait for movement to finish
while(st==0)
    st = 1;
    for(i=0:3)
        r = tri_send('GAP',8,i,0);
        st = st * r.value;
    end
end
set(hObject,'ForegroundColor',[0 0 0]);
drawnow;

for(i=0:3)
    r1 = tri_send('SAP',4,i,v(i+1,1));
    r2 = tri_send('SAP',5,i,v(i+1,2));
end

dmpos = mpos{3};
update_pos;


% --- Executes on button press in pushbutton66.
function pushbutton66_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton66 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dmpos mpos;
mpos{4} = dmpos;

% for(i=0:3)
%     tri_send('CCO',14,i,0);
% end

% --- Executes on button press in pushbutton67.
function pushbutton67_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton67 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global mpos dmpos;

for(i=0:3)
    tri_send('SCO',0,i,mpos{4}(i+1));
end

v = zeros(4,2);

for(i=0:3)                      % current vel and acc
    r1 = tri_send('GAP',4,i,0);
    r2 = tri_send('GAP',5,i,0);
    v(i+1,1) = r1.value;
    v(i+1,2) = r2.value;
    tri_send('SAP',4,i,1200);
    tri_send('SAP',5,i,275);
end

tri_send('MVP',2,hex2dec('8f'),0);

set(hObject,'ForegroundColor',[1 0 0]);
drawnow;
st = 0;                         % wait for movement to finish
while(st==0)
    st = 1;
    for(i=0:3)
        r = tri_send('GAP',8,i,0);
        st = st * r.value;
    end
end
set(hObject,'ForegroundColor',[0 0 0]);
drawnow;

for(i=0:3)
    r1 = tri_send('SAP',4,i,v(i+1,1));
    r2 = tri_send('SAP',5,i,v(i+1,2));
end

dmpos = mpos{4};
update_pos;




function update_pos

global dmpos motor_gain origin scanbox_h;

mname = {'zpos','ypos','xpos','thpos'};
v = zeros(1,4);

for(i=0:3)
    v(i+1) =  motor_gain(i+1) * double(dmpos(i+1)-origin(i+1));  %%  (inches/rot) / (steps/rot) * 25400um
end

for(i=0:3)
    h = findobj(scanbox_h,'Tag',mname{i+1});
    set(h,'String',sprintf('%.2f',v(i+1)));
    drawnow;
end




% --- Executes on button press in pushbutton68.
function pushbutton68_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton68 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global origin dmpos

for(i=0:2)
    r = tri_send('GAP',1,i,0);
    origin(i+1) = r.value;
end

dmpos(1:3) = origin(1:3);
update_pos;


% --- Executes on button press in text76.
function text76_Callback(hObject, eventdata, handles)
% hObject    handle to text76 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in text77.
function text77_Callback(hObject, eventdata, handles)
% hObject    handle to text77 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in alist.
function listbox6_Callback(hObject, eventdata, handles)
% hObject    handle to alist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns alist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from alist


% --- Executes during object creation, after setting all properties.
function listbox6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to alist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in blist.
function blist_Callback(hObject, eventdata, handles)
% hObject    handle to blist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns blist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from blist

global cellpoly

cellfun(@(x) set(x,'EdgeColor',[1 1 1],'LineWidth',1,'FaceAlpha',0.4),cellpoly);
try
    idx = str2num(hObject.String{hObject.Value});
    cellpoly{idx}.FaceAlpha = 0.7;
catch
end

% --- Executes during object creation, after setting all properties.
function blist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to blist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'String',{},'Value',0);


% --- Executes on button press in deletecell.
function deletecell_Callback(hObject, eventdata, handles)
% hObject    handle to deletecell (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ncell cellpoly;

l = get(handles.alist,'String');
v = get(handles.alist,'Value');
if(v>0)
    j = str2num(l{v});
    delete(cellpoly{j});
    cellpoly{j} = [];
    l(v) = [];
    set(handles.alist,'String',l,'Value',min(v,length(l)));
end

% --- Executes on button press in alla2b.
function alla2b_Callback(hObject, eventdata, handles)
% hObject    handle to alla2b (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


la = get(handles.alist,'String');
va = get(handles.alist,'Value');

lb = get(handles.blist,'String');
vb = get(handles.blist,'Value');

if(length(la)>0)
    lb = {lb{:} la{:}};
    la = {};
    set(handles.alist,'String',{},'Value',0);
    vb = length(lb);
    set(handles.blist,'String',lb,'Value',length(lb));
end





% --- Executes on button press in a2b.
function a2b_Callback(hObject, eventdata, handles)
% hObject    handle to a2b (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

la = get(handles.alist,'String');
va = get(handles.alist,'Value');

lb = get(handles.blist,'String');
vb = get(handles.blist,'Value');

if(length(la)>0)
    lb{end+1} = la{va};    % append
    
    la(va) = [];
    set(handles.alist,'String',la,'Value',min(va,length(la)));
    
    vb = length(lb);
    set(handles.blist,'String',lb,'Value',length(lb));
end


% --- Executes on button press in b2a.
function b2a_Callback(hObject, eventdata, handles)
% hObject    handle to b2a (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

la = get(handles.alist,'String');
va = get(handles.alist,'Value');

lb = get(handles.blist,'String');
vb = get(handles.blist,'Value');

if(length(lb)>0)
    la{end+1} = lb{vb};    % append
    
    lb(vb) = [];
    set(handles.blist,'String',lb,'Value',min(vb,length(lb)));
    
    va = length(la);
    set(handles.alist,'String',la,'Value',length(la));
end

% --- Executes on button press in addtoa.
function addtoa_Callback(hObject, eventdata, handles)
% hObject    handle to addtoa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ncell cellpoly sbconfig;

% h = imfreehand(handles.image0);
% h.setColor([.5 1 0]);

h = imfreehand(handles.image0);
xy = h.getPosition;
delete(h);
h = patch(xy(:,1),xy(:,2),'w','facealpha',0.4,'edgecolor',[1 1 1],'parent',handles.image0,'FaceLighting','none');


l = get(handles.alist,'String');
if(isempty(l))
    ncell = ncell+1;
    l = {num2str(ncell)};
    cellpoly{ncell} = h;
else
    ncell = ncell+1;
    l = {l{:} num2str(ncell)};
    cellpoly{ncell} = h;
end
set(handles.alist,'String',l,'Value',length(l));


% --- Executes on button press in allb2a.
function allb2a_Callback(hObject, eventdata, handles)
% hObject    handle to allb2a (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

la = get(handles.alist,'String');
va = get(handles.alist,'Value');

lb = get(handles.blist,'String');
vb = get(handles.blist,'Value');

if(length(lb)>0)
    la = {la{:} lb{:}};
    lb = {};
    set(handles.blist,'String',{},'Value',0);
    
    va = length(la);
    set(handles.alist,'String',la,'Value',length(la));
end


% --- Executes during object creation, after setting all properties.
function addtoa_CreateFcn(hObject, eventdata, handles)
% hObject    handle to addtoa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on button press in mmap.
function mmap_Callback(hObject, eventdata, handles)
% hObject    handle to mmap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of mmap



% --- Executes on button press in networkstream.
function networkstream_Callback(hObject, eventdata, handles)
% hObject    handle to networkstream (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of networkstream

global stream_udp sbconfig;

if(get(hObject,'Value'))
    try
        stream_udp  = udp(sbconfig.stream_host, 'RemotePort', sbconfig.stream_port);
        fopen(stream_udp);
    catch
        warndlg('Connection refused. Check network parameters.','scanbox');
        set(hObject,'Value',0);
        delete(stream_udp);
        stream_udp = [];
    end
else
    try
        fclose(stream_udp);
        stream_udp = [];
    catch
    end
end



% --- Executes on button press in dellall.
function dellall_Callback(hObject, eventdata, handles)
% hObject    handle to dellall (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ncell cellpoly roi_traces_h;

ncell = 0;
cellfun(@delete,cellpoly);
cellpoly = {};
set(handles.alist,'String',{},'Value',0);
set(handles.blist,'String',{},'Value',0);
delete(roi_traces_h.Children);


function edit38_Callback(hObject, eventdata, handles)
% hObject    handle to edit38 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit38 as text
%        str2double(get(hObject,'String')) returns contents of edit38 as a double


% --- Executes during object creation, after setting all properties.
function edit38_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit38 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in stabilize.
function stabilize_Callback(hObject, eventdata, handles)
% hObject    handle to stabilize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of stabilize

global ref_img

if(get(hObject,'Value')==1)
    if(isempty(ref_img))
        warndlg('First define a reference image by accumulating during times of no relative movement.','scanbox');
        set(hObject,'Value',0);
    end
else
    % ref_img = [];
end

% --- Executes on button press in pushbutton76.
function pushbutton76_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton76 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ref_img img0_h ref_img_fft xref yref ref_th sbconfig;
global gData gtime scanmode;


% set reference

if(gtime<10)
    warndlg('Please collect a longer sequence to define a reference image','scanbox');
    ref_img = [];
    return;
end


% mm = mean(gData(1:gtime,:,:),1);
% ss = std(gData(1:gtime,:,:),[],1);
% cv = mm./ss;
% Mx = max(cv(:));
% Mm = min(cv(:));
% ref_img = squeeze(gather((cv-Mm)/(Mx-Mm)));
% set(img0_h,'Cdata',uint8(255*ref_img));

mm = squeeze(mean(gData(1:gtime,:,:),1));
if(scanmode==0)
    mm(:,1:sbconfig.margin) = NaN;
    mm(:,end-sbconfig.margin:end) = NaN;
end
Mx = max(mm(:));
Mm = min(mm(:));
if(scanmode==0)
    mm(:,1:sbconfig.margin) = Mx;
    mm(:,end-sbconfig.margin:end) = Mx;
end
ref_img = squeeze(gather((mm-Mm)/(Mx-Mm)));
img0_h.CData(:,:,2) = 255-uint8(255*ref_img);
img0_h.CData(:,:,1) = 0;

R = cell(1,sbconfig.nroi_auto);
pos = zeros(sbconfig.nroi_auto,4);
theSize = sbconfig.nroi_auto_size(handles.magnification.Value);

for(i=1:sbconfig.nroi_auto)
    h = imrect(handles.image0,theSize*[1 1 1 1]);
    h.setFixedAspectRatioMode(true);
    h.setResizable(false);
    R{i} = h;
    pos(i,:) = wait(h);
end
pos = round(pos(:,1:2) + pos(:,3:4)/2);

for(i=1:length(R))
    delete(R{i});
end

ref_img_fft = cell(1,length(sbconfig.nroi_auto));
ref_th = zeros(1,length(sbconfig.nroi_auto));
xref = zeros(sbconfig.nroi_auto,theSize);
yref = zeros(sbconfig.nroi_auto,theSize);

for(i=1:sbconfig.nroi_auto)
    yref(i,:) = pos(i,2)- theSize/2 + 1 : pos(i,2) + theSize/2;
    xref(i,:) = pos(i,1)- theSize/2 + 1 : pos(i,1) + theSize/2;
    rsub = ref_img(yref(i,:),xref(i,:));
    ref_img_fft{i} = fft2(rot90(rsub,2));
end


% --- Executes during object creation, after setting all properties.
function mmap_CreateFcn(hObject, eventdata, handles)
% hObject    handle to mmap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function networkstream_CreateFcn(hObject, eventdata, handles)
% hObject    handle to networkstream (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


%-------------------------------------------------------------------------
function [] = wrap_cb()
% wrap_cb.m--Callback for "wrap" dial.
%-------------------------------------------------------------------------

wrapDial = dial.find_dial('wrapDial','-1');
dialVal = round(get(wrapDial,'Value'))


function [u,v] = fftalignauto(A)

global ref_img_fft xref yref ref_th sbconfig

u = zeros(1,sbconfig.nroi_auto);
v = zeros(1,sbconfig.nroi_auto);
N = sbconfig.roi_auto_size;

for(k=1:sbconfig.nroi_auto)
    C = fftshift(real(ifft2(fft2(A(yref(k,:),xref(k,:))).*ref_img_fft{k})));
    [~,i] = max(C(:));
    [ii jj] = ind2sub(size(C),i);
    u(k) = N/2-ii;
    v(k) = N/2-jj;
end


% --- Executes on button press in segment.
function segment_Callback(hObject, eventdata, handles)
% hObject    handle to segment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of segment

global scanbox_h img0_h gData gtime me va ku corrmap th_corr th_txt oldCData

if(get(hObject,'Value'))
    
    me = mean(gData(1:gtime,:,:),1);
    gData = bsxfun(@minus,gData(1:gtime,:,:),me);
    va = mean(gData(1:gtime,:,:).^2,1);
    gData = bsxfun(@rdivide,gData(1:gtime,:,:),sqrt(va));
    ku = mean(gData(1:gtime,:,:).^4,1)-3;
    
    corrmap = zeros([size(gData,2) size(gData,3)],'single','gpuArray');
    
    for(m=-1:1)
        for(n=-1:1)
            if(m~=0 || n~=0)
                corrmap = corrmap+squeeze(sum(gData(1:gtime,:,:).*circshift(gData(1:gtime,:,:),[0 m n]),1));
            end
        end
    end
    corrmap = corrmap/8/gtime;
    oldCData = img0_h.CData;
    
    qq = zeros([size(corrmap) 3]);
    qq(:,:,1) = adapthisteq(gather(corrmap));
    img0_h.CData = uint8(255*qq);
    
    global th_corr;
    th_corr = 0.2;
    th_txt = text(.05,.1,sprintf('%1.2f',th_corr),'color','w','fontsize',14,'parent',handles.image0,'units','normalized');
    
    set(scanbox_h,'WindowButtonMotionFcn',@wbmcb)
    set(scanbox_h,'WindowScrollWheelFcn',@wswcb)
    set(scanbox_h,'WindowButtonDownFcn',@wbdcb)
else
    set(scanbox_h,'WindowButtonMotionFcn',[])
    set(scanbox_h,'WindowScrollWheelFcn',[])
    set(scanbox_h,'WindowButtonDownFcn',[])
    delete(th_txt);
    img0_h.CData = oldCData;
    drawnow;
    
end


% --- Executes on selection change in reftype.
function reftype_Callback(hObject, eventdata, handles)
% hObject    handle to reftype (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns reftype contents as cell array
%        contents{get(hObject,'Value')} returns selected item from reftype


% --- Executes during object creation, after setting all properties.
function reftype_CreateFcn(hObject, eventdata, handles)
% hObject    handle to reftype (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton78.
function pushbutton78_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton78 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

set(handles.pmt0,'Value',0);
set(handles.pmt1,'Value',0);
set(handles.pmt0txt,'String','0.00');
set(handles.pmt1txt,'String','0.00');
sb_gain0(0);
sb_gain1(0);


% --- Executes on button press in stimmark.
function stimmark_Callback(hObject, eventdata, handles)
% hObject    handle to stimmark (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of stimmark


% --- Executes during object creation, after setting all properties.
function segment_CreateFcn(hObject, eventdata, handles)
% hObject    handle to segment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global segment_h;

segment_h = hObject;


% --- Executes on slider movement.
function pockval_Callback(hObject, eventdata, handles)
% hObject    handle to pockval (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

sb_pockels(0,get(hObject,'Value'));
handles.powertxt.String = sprintf('%3d%%',round(hObject.Value/255.0*100));



% --- Executes during object creation, after setting all properties.
function pockval_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pockval (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in quadcheck.
function quadcheck_Callback(hObject, eventdata, handles)
% hObject    handle to quadcheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of quadcheck


function mousedrv_cb(obj,b,varargin)

global motorstate motormode xpos_h ypos_h zpos_h thpos_h dmpos origin motor_gain nroi motorlock_h stabilize_h mstep


if(motorlock_h.Value==0)
    
    stabilize_h.Value = 0;   % stop stabilizing if you move motors...
    nroi = 0;                % in case real time was showing -- shut it down
    
    thval = str2double(thpos_h.String);
    
    newstate = [obj.Sen.Translation.Y -obj.Sen.Translation.Z obj.Sen.Translation.X ];
    newstate  = [(abs(newstate)>500).*sign(newstate) -sign(obj.Sen.Rotation.Y)*(obj.Sen.Rotation.Angle>250)];
    
    j = find(newstate ~= motorstate);
    
    if(~isempty(j))     % state changed
        
        switch motormode
            
            case 1
                
                for(i=j)
                    r = tri_send('ROR',0,i-1,newstate(i)*mstep(i));   % fix each axis that changed...
                end
                
            case 2
                
                for(i=j)
                    switch(i)
                        case 1
                            tri_send('ROR',0,0,newstate(i)*mstep(1)*cosd(thval));
                            tri_send('ROR',0,2,-newstate(i)*mstep(3)*sind(thval));
                        case 3
                            tri_send('ROR',0,0,newstate(i)*mstep(1)*sind(thval));
                            tri_send('ROR',0,2,newstate(i)*mstep(3)*cosd(thval));
                        otherwise
                            tri_send('ROR',0,i-1,newstate(i)*mstep(i));
                    end
                end
                
        end
        
        motorstate = newstate;
        
        % update position reading
        if(all(motorstate==0))
            
            % stop all motors
            %             tri_send('MST',0,0,0);
            %             tri_send('MST',0,1,0);
            %             tri_send('MST',0,2,0);
            %             tri_send('MST',0,3,0);
            
            v = zeros(1,4);
            for(i=3:-1:0)                   % let z be the last axis...
                r = tri_send('GAP',1,i,0);
                dmpos(i+1) = r.value;
                v(i+1) =  motor_gain(i+1) * double(r.value-origin(i+1));  %%  (inches/rot) / (steps/rot) * 25400um
            end
            
            zpos_h.String=sprintf('%.2f',v(1));
            ypos_h.String=sprintf('%.2f',v(2));
            xpos_h.String=sprintf('%.2f',v(3));
            thpos_h.String=sprintf('%.2f',v(4));
            drawnow;
            
        end
        
    end
end



% --- Executes during object creation, after setting all properties.
function motorlock_CreateFcn(hObject, eventdata, handles)
% hObject    handle to motorlock (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global motorlock_h;

motorlock_h = hObject;


% --- Executes during object creation, after setting all properties.
function stabilize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stabilize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global stabilize_h

stabilize_h = hObject;


% --- Executes on slider movement.
function optoslider_Callback(hObject, eventdata, handles)
% hObject    handle to optoslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global opto2pow sbconfig

sb_current(hObject.Value);

if(isempty(sbconfig.optocal))
    handles.ot_txt.String = sprintf('%04d',floor(hObject.Value));
else
    handles.ot_txt.String = sprintf('%03d um',floor(polyval(sbconfig.optocal,hObject.Value)));
end

if(handles.linkcheck.Value)
    handles.pockval.Value = opto2pow(floor(hObject.Value/16)+1); % set value
    pockval_Callback(handles.pockval,[],handles);                % execute callback
end

% --- Executes during object creation, after setting all properties.
function optoslider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optoslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in clearoptotable.
function clearoptotable_Callback(hObject, eventdata, handles)
% hObject    handle to clearoptotable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global opto2pow;

opto2pow = [];
handles.linkcheck.Value = 0;    % uncheck the link button


% --- Executes on button press in optolink.
function optolink_Callback(hObject, eventdata, handles)
% hObject    handle to optolink (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global opto2pow;

pow = round(handles.pockval.Value);        % 0-255
opto = floor(handles.optoslider.Value/16); % 0-255

pow = min(max(0,pow),255);
opto = min(max(0,opto),255);

opto2pow = [opto2pow ; opto pow];          % add points to the list




% --- Executes on button press in linkcheck.
function linkcheck_Callback(hObject, eventdata, handles)
% hObject    handle to linkcheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of linkcheck


global opto2pow;

if(hObject.Value)
    if(size(opto2pow,2)==2)
        opto2pow = interp1(opto2pow(:,1),opto2pow(:,2),0:255);
        nidx = find(~isnan(opto2pow));
        idx = min(nidx);
        opto2pow(1:idx-1) = opto2pow(idx);
        idx = max(nidx);
        opto2pow(idx+1:end) = opto2pow(idx);
        opto2pow = floor(opto2pow);
    end
    for(i=1:256)
        sb_current_power(i-1,opto2pow(i)); % link current to power
    end
    sb_current_power_active(1);     % active link between current and power
else
    sb_current_power_active(0);
end



function optomin_Callback(hObject, eventdata, handles)
% hObject    handle to optomin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of optomin as text
%        str2double(get(hObject,'String')) returns contents of optomin as a double


% --- Executes during object creation, after setting all properties.
function optomin_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optomin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function optoperiod_Callback(hObject, eventdata, handles)
% hObject    handle to optoperiod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of optoperiod as text
%        str2double(get(hObject,'String')) returns contents of optoperiod as a double


% --- Executes during object creation, after setting all properties.
function optoperiod_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optoperiod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function optomax_Callback(hObject, eventdata, handles)
% hObject    handle to optomax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of optomax as text
%        str2double(get(hObject,'String')) returns contents of optomax as a double


% --- Executes during object creation, after setting all properties.
function optomax_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optomax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in optowavestyle.
function optowavestyle_Callback(hObject, eventdata, handles)
% hObject    handle to optowavestyle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns optowavestyle contents as cell array
%        contents{get(hObject,'Value')} returns selected item from optowavestyle


% --- Executes during object creation, after setting all properties.
function optowavestyle_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optowavestyle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in volscan.
function volscan_Callback(hObject, eventdata, handles)
% hObject    handle to volscan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of volscan

global otwave otwave_um;

if(hObject.Value)
    sb_optotune_active(1);
else
    sb_optotune_active(0);
    
%     otwave = [];         %% Sandy complaint about this behavior
%     otwave_um = [];
end

% --- Executes on button press in pushbutton81.
function pushbutton81_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton81 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global messages captureDone buffersCompleted

r = tri_send('MST',0,4,0);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=0',buffersCompleted);
end


% --- Executes on button press in pushbutton82.
function pushbutton82_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton82 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global messages captureDone buffersCompleted

r = tri_send('ROR',0,4,200);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=1',buffersCompleted);
end

% --- Executes on button press in pushbutton83.
function pushbutton83_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton83 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global messages captureDone buffersCompleted

r = tri_send('ROR',0,4,400);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=2',buffersCompleted);
end


% --- Executes on slider movement.
function dgain_Callback(hObject, eventdata, handles)
% hObject    handle to dgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function dgain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

global dgain
dgain = hObject;

% --- Executes on slider movement.
function dbias_Callback(hObject, eventdata, handles)
% hObject    handle to dbias (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function dbias_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dbias (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

global dbias
dbias = hObject;



% --- Executes on slider movement.
function slider48_Callback(hObject, eventdata, handles)
% hObject    handle to dgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider48_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function notestxt_Callback(hObject, eventdata, handles)
% hObject    handle to notestxt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of notestxt as text
%        str2double(get(hObject,'String')) returns contents of notestxt as a double


% --- Executes during object creation, after setting all properties.
function notestxt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to notestxt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in unibi.
function unibi_Callback(hObject, eventdata, handles)
% hObject    handle to unibi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanmode sbconfig;

if(strcmp('Unidirectional',hObject.String))
    hObject.String = 'Bidirectional';
    sb_bidirectional;
    scanmode = 0;
else
    hObject.String = 'Unidirectional';
    sb_unidirectional;
    scanmode = 1;
end

frame_rate = sbconfig.resfreq(get(handles.magnification,'Value'))/str2num(handles.lines.String)*(2-scanmode); %% use actual resonant freq... % modified by JZ, original: sbconfig.resfreq
set(handles.frate,'String',sprintf('%2.2f',frame_rate));

drawnow;


% --- Executes on button press in otupload.
function otupload_Callback(hObject, eventdata, handles)
% hObject    handle to otupload (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global otwave otparam;

% compute and upload table...

m = str2double(handles.optomin.String);
M = str2double(handles.optomax.String);
per = str2double(handles.optoperiod.String);

otparam = [m M per];

switch(handles.optowavestyle.Value)
    
    case 1
        sb_optowave_square(m,M,per);
        
    case 2
        sb_optowave_sawtooth(m,M,per);
        
    case 3
        sb_optowave_triangular(m,M,per);
        
    case 4
        sb_optowave_sine(m,M,per);
end


% --- Executes on button press in pushbutton86.
function pushbutton86_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton86 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global captureDone

r = tri_send('ROR',0,4,-200);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=-1',buffersCompleted);
end

% --- Executes on button press in pushbutton87.
function pushbutton87_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton87 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global captureDone

r = tri_send('ROR',0,4,-400);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=-2',buffersCompleted);
end


% --- Executes on button press in arealine.
function arealine_Callback(hObject, eventdata, handles)
% hObject    handle to arealine (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global scanmode sbconfig;

if(strcmp('Area',hObject.String))
    hObject.String = 'Line';
    sb_linescan(1);
    handles.image0.Units = 'normalized';
    p = handles.image0.Position;
    global hline scanbox_h
    hline = annotation(scanbox_h,'line',[p(1) p(1)+p(3)],(p(2)+p(4)/2)*ones(1,2));
    hline.Color = [.8 .8 .8];
    hline.LineStyle = '--';
else
    hObject.String = 'Area';
    sb_linescan(0);
    global hline;
    delete(hline);
end
drawnow;

% --- Executes on button press in pushbutton89.
function pushbutton89_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton89 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanmode sbconfig;

if(strcmp('Normal Resonant',hObject.String))
    hObject.String = 'Continuous Resonant';
    sb_continuous_resonant(1);
else
    hObject.String = 'Normal Resonant';
    sb_continuous_resonant(0);
end

drawnow;

function flipDalsaImg(obj,event,himage) 
himage.CData=fliplr(event.Data);


% --- Executes on button press in slmstim.
function slmstim_Callback(hObject, eventdata, handles)
% hObject    handle to slmstim (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of slmstim

global cellphase slms

% present image for cellphase on holoeye

d = [0 zeros(1,str2double(handles.slmpulse.string)) 0]';
queueOutputData(slms,d);
startBackground(slms);  % send pulse


% --- Executes on button press in slmbox.
function slmbox_Callback(hObject, eventdata, handles)
% hObject    handle to slmbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of slmbox


% --- Executes on button press in phase.
function phase_Callback(hObject, eventdata, handles)
% hObject    handle to phase (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global cellpoly cellphase nlines sbconfig cellphase; %#ok<NUSED>

slm = load(sbconfig.slmcal); % load calibration file

cellphase = cell(1,length(cellpoly));

for(j=1:length(cellpoly))
    p = cellpoly{j}.Vertices;
    p(:,1) = p(:,1)/796;       %normalized coordinates
    p(:,2) = p(:,2)/nlines;
    p(:,1) = p(:,1)*slm.width; % match to scan size
    p(:,2) = p(:,2)*slm.height;
    vp = p(:,1)*xhat + p(:,2)*yhat;
    vp(:,1) = vp(:,1)+slm.x0;
    vp(:,2) = vp(:,2)+slm.y0;
    vp = ceil(vp);              % round up
    % create image with size of holoeye and vp <- 1
    % cellphase{i} = gs(maskp);
end
    



function slmpulse_Callback(hObject, eventdata, handles)
% hObject    handle to slmpulse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of slmpulse as text
%        str2double(get(hObject,'String')) returns contents of slmpulse as a double


% --- Executes during object creation, after setting all properties.
function slmpulse_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slmpulse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in dispenable.
function dispenable_Callback(hObject, eventdata, handles)
% hObject    handle to dispenable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of dispenable


% --- Executes on slider movement.
function deadleft_Callback(hObject, eventdata, handles)
% hObject    handle to deadleft (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global sbconfig

sb_deadband(handles.deadleft.Value,handles.deadright.Value);
sbconfig.deadband(1) = round(handles.deadleft.Value);

% --- Executes during object creation, after setting all properties.
function deadleft_CreateFcn(hObject, eventdata, handles)
% hObject    handle to deadleft (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function deadright_Callback(hObject, eventdata, handles)
% hObject    handle to deadright (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global sbconfig

sb_deadband(handles.deadleft.Value,handles.deadright.Value);
sbconfig.deadband(2) = round(handles.deadright.Value);


% --- Executes during object creation, after setting all properties.
function deadright_CreateFcn(hObject, eventdata, handles)
% hObject    handle to deadright (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in bishiftminus.
function bishiftminus_Callback(hObject, eventdata, handles)
% hObject    handle to bishiftminus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global preIdx sbconfig

sbconfig.bishift(handles.magnification.Value) = sbconfig.bishift(handles.magnification.Value)-1;
preIdx = preIdx-2;

% --- Executes on button press in bishiftplus.
function bishiftplus_Callback(hObject, eventdata, handles)
% hObject    handle to bishiftplus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global preIdx sbconfig

sbconfig.bishift(handles.magnification.Value) = sbconfig.bishift(handles.magnification.Value)+1;
preIdx = preIdx+2;


% --- Executes on button press in fshutter.
function fshutter_Callback(hObject, eventdata, handles)
% hObject    handle to fshutter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of fshutter

global sbconfig;

% It must be discovery otherwise button is disabled

laser_send(sprintf('SFIXED=%d',get(hObject,'Value')));

if(get(hObject,'Value'))
    set(hObject,'String','Shutter open','FontWeight','bold','Value',1);
else
    set(hObject,'String','Shutter closed','FontWeight','normal','Value',0);
end

r = laser_send('?GDDMIN');
[r,~] = strsplit(r,' ');
val = str2double(r{end});
handles.gddslider.Min = val;

r = laser_send('?GDDMAX');
[r,~] = strsplit(r,' ');
val = str2double(r{end});
handles.gddslider.Max= val;

r = laser_send('?GDD');
[r,~] = strsplit(r,' ');
val = str2double(r{end});
handles.gddslider.Value= val;
handles.gddtxt.String = r{end};


% --- Executes on slider movement.
function gddslider_Callback(hObject, eventdata, handles)
% hObject    handle to gddslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

msg = sprintf('GDD=%d',round(hObject.Value));
r = laser_send(msg);
handles.gddtxt.String = num2str(round(hObject.Value));

% --- Executes during object creation, after setting all properties.
function gddslider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gddslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in savebidi.
function savebidi_Callback(hObject, eventdata, handles)
% hObject    handle to savebidi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global sbconfig

fn = which('scanbox_config.m');
fid = fopen(fn,'a');

fprintf(fid,'\n%% Bishift calibration saved\n');
fprintf(fid,'sbconfig.bishift = [');
fprintf(fid,'%d ',sbconfig.bishift);
fprintf(fid,'];\n');
fclose(fid);

% --- Executes on button press in dbsave.
function dbsave_Callback(hObject, eventdata, handles)
% hObject    handle to dbsave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global sbconfig

fn = which('scanbox_config.m');
fid = fopen(fn,'a');

fprintf(fid,'\n%% Deadband settings saved\n');
fprintf(fid,'sbconfig.deadband = [');
fprintf(fid,'%d ',sbconfig.deadband);
fprintf(fid,'];\n');
fclose(fid);


% --- Executes during object creation, after setting all properties.
function text1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
