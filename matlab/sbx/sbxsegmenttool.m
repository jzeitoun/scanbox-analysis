function varargout = sbxsegmenttool(varargin)
% SBXSEGMENTTOOL MATLAB code for sbxsegmenttool.fig
%      SBXSEGMENTTOOL, by itself, creates a new SBXSEGMENTTOOL or raises the existing
%      singleton*.
%
%      H = SBXSEGMENTTOOL returns the handle to a new SBXSEGMENTTOOL or the handle to
%      the existing singleton*.
%
%      SBXSEGMENTTOOL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SBXSEGMENTTOOL.M with the given input arguments.
%
%      SBXSEGMENTTOOL('Property','Value',...) creates a new SBXSEGMENTTOOL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before sbxsegmenttool_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to sbxsegmenttool_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help sbxsegmenttool

% Last Modified by GUIDE v2.5 03-Oct-2016 19:37:23

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @sbxsegmenttool_OpeningFcn, ...
                   'gui_OutputFcn',  @sbxsegmenttool_OutputFcn, ...
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


% --- Executes just before sbxsegmenttool is made visible.
function sbxsegmenttool_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to sbxsegmenttool (see VARARGIN)

% Choose default command line output for sbxsegmenttool
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes sbxsegmenttool wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = sbxsegmenttool_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in load.
function load_Callback(hObject, eventdata, handles)
% hObject    handle to load (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global bgimg data segmenttool_h nframes ncell cellpoly mask rfn pathname
handles.status.String = 'Resetting/Clearing GPU';
drawnow;
gpuDevice(1);

global sig;
delete(handles.axes3.Children);
sig = [];

[fn,pathname] = uigetfile({'*_rigid*sbx; *_nonrigid*sbx'});
fn = [pathname fn];
rfn = strtok(fn,'.');
idx = max(strfind(rfn,'_'));
rfnx = rfn(1 : (idx-1));

try
    load('-mat',[rfnx '.align']); 
catch
    return
end
axis off

handles.status.String = 'Loading alignment data';

if(exist('mnr','var'))
    m = gather(mnr);
end

m = (m-min(m(:)))/(max(m(:))-min(m(:)));
x = adapthisteq(m);
x = single(x);
x = (x-min(x(:)))/(max(x(:))-min(x(:)));
bgimg.CData(:,:,1) = uint8(255*x);
bgimg.CData(:,:,2) = bgimg.CData(:,:,1);
bgimg.CData(:,:,3) = bgimg.CData(:,:,1);

if(~isempty(cellpoly))
    cellfun(@delete,cellpoly);
end

drawnow;

handles.status.String = 'Loading spatio-temporal data';

[rfn,~] = strtok(fn,'.');

z = sbxread(rfn,0,1);
global info;

nframes = str2double(handles.frames.String);
skip = floor(info.max_idx/nframes);
data = single(gpuArray(sbxreadskip(rfn,nframes,skip)));
data = zscore(data,[],3);

% compute and display correlation map...

handles.status.String = 'Computing correlation map';
drawnow;

corrmap = zeros([size(data,1) size(data,2)],'single','gpuArray');
    
for(m=-1:1)
    for(n=-1:1)
        if(m~=0 || n~=0)
            corrmap = corrmap+squeeze(sum(data.*circshift(data,[m n 0]),3));
        end
    end
end
corrmap = corrmap/8/size(data,3);

x = gather(corrmap);
x = (x-min(x(:)))/(max(x(:))-min(x(:)));
bgimg.CData(:,:,1) = uint8(255*x);
bgimg.CData(:,:,2) = uint8(0);
bgimg.CData(:,:,3) = uint8(0);

drawnow;

    
set(segmenttool_h,'WindowButtonMotionFcn',@sbxwbmcb)
set(segmenttool_h,'WindowScrollWheelFcn',@sbxwswcb)
set(segmenttool_h,'WindowButtonDownFcn',@sbxwbdcb)

ncell = 0;
cellpoly = {};
mask = zeros(size(data,1),size(data,2));

handles.status.String = 'Showing correlation map. Start segmenting';
   
% --- Executes on button press in save.
function save_Callback(hObject, eventdata, handles)
% hObject    handle to save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global rfn mask cellpoly pathname ncell

save([rfn '.segment'],'mask');
handles.status.String = sprintf('Saved %d cells in %s.segment',ncell,rfn);

function frames_Callback(hObject, eventdata, handles)
% hObject    handle to frames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of frames as text
%        str2double(get(hObject,'String')) returns contents of frames as a double

global nframes
nframes = str2double(hObject.String);


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


% --- Executes during object creation, after setting all properties.
function ax_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate ax

global bgimg

bgimg = imagesc(zeros(512,796,3,'uint8'));
colormap gray
% axis off


function nhood_Callback(hObject, eventdata, handles)
% hObject    handle to nhood (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of nhood as text
%        str2double(get(hObject,'String')) returns contents of nhood as a double

global nhood
nhood = str2double(hObject.String);


% --- Executes during object creation, after setting all properties.
function nhood_CreateFcn(hObject, eventdata, handles)
% hObject    handle to nhood (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
'NHOOD'
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function figure1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global segmenttool_h frames th_corr zs ps
segmenttool_h = hObject;
zs = 0;
ps = 0;

frames = 300;
th_corr = 0.2;
   


% --- Executes during object creation, after setting all properties.
function bgimg_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate ax


% --- Executes during object creation, after setting all properties.
function status_CreateFcn(hObject, eventdata, handles)
% hObject    handle to status (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global status

status = hObject;


% --- Executes on selection change in method.
function method_Callback(hObject, eventdata, handles)
% hObject    handle to method (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns method contents as cell array
%        contents{get(hObject,'Value')} returns selected item from method

global method

method = hObject;


% --- Executes during object creation, after setting all properties.
function method_CreateFcn(hObject, eventdata, handles)
% hObject    handle to method (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function nhsize_Callback(hObject, eventdata, handles)
% hObject    handle to nhsize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of nhsize as text
%        str2double(get(hObject,'String')) returns contents of nhsize as a double

global nhood 
nhood = str2double(hObject.String);


% --- Executes during object creation, after setting all properties.
function nhsize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to nhsize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global  nhood_h
nhood_h = hObject;

% --- Executes on mouse press over figure background.
function figure1_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in popupmenu2.
function popupmenu2_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu2


global segmenttool_h

switch get(hObject,'Value')
    case 1
        pan(segmenttool_h,'off');
        zoom(segmenttool_h,'off');
    case 2
        pan(segmenttool_h,'off');
        zoom(segmenttool_h,'on');
    case 3
        pan(segmenttool_h,'on');
        zoom(segmenttool_h,'off');
end





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

global mode_h

mode_h = hObject;



% --- Executes on button press in extract.
function extract_Callback(hObject, eventdata, handles)
% hObject    handle to extract (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global rfn sig
sig = sbxpullsignals(rfn);
handles.status.String = sprintf('Signals extracted and saved');
plot(handles.axes3,zscore(sig));
handles.axes3.Visible = 'off';
handles.axes3.YLim = [-0.5 10];


% --- Executes during object creation, after setting all properties.
function axes3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axes3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate axes3

axis off;


% --- Executes on button press in checkbox2.
function checkbox2_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox2
