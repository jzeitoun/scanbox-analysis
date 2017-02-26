function varargout = sbxaligntool(varargin)
% SBXALIGNTOOL MATLAB code for sbxaligntool.fig
%      SBXALIGNTOOL, by itself, creates a new SBXALIGNTOOL or raises the existing
%      singleton*.
%
%      H = SBXALIGNTOOL returns the handle to a new SBXALIGNTOOL or the handle to
%      the existing singleton*.
%
%      SBXALIGNTOOL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SBXALIGNTOOL.M with the given input arguments.
%
%      SBXALIGNTOOL('Property','Value',...) creates a new SBXALIGNTOOL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before sbxaligntool_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to sbxaligntool_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help sbxaligntool

% Last Modified by GUIDE v2.5 31-Aug-2016 15:38:44

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @sbxaligntool_OpeningFcn, ...
                   'gui_OutputFcn',  @sbxaligntool_OutputFcn, ...
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


% --- Executes just before sbxaligntool is made visible.
function sbxaligntool_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to sbxaligntool (see VARARGIN)

% Choose default command line output for sbxaligntool
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes sbxaligntool wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = sbxaligntool_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global fname running ref FileName;

handles.status.String = 'Resetting/Clearing GPU. Please wait.';
drawnow;
dummy = eval(handles.gpu.String{handles.gpu.Value});

[FileName,PathName] = uigetfile('*sbx','multiselect','on');
cd(PathName);

if(~iscell(FileName))
    sbxload(FileName,handles);
else
    handles.status.String = sprintf('Batch processing of %d files',length(FileName));
end

function sbxload(FileName,handles)

global ref fname running

fname = strtok(FileName,'.');

if(exist([fname '.align'],'file'))         % use reference with rigidly aligned one
    r = load('-mat',[fname '.align'],'m');
    ref = r.m;
    handles.status.String = sprintf('File %s has been loaded; previous alignment used as reference',fname);
else
    z = sbxreadsample(fname,300,handles.chan.Value);    % pick 300 random frames...
    ref = squeeze(mean(z,length(size(z))));
    handles.status.String = sprintf('File %s has been loaded',fname);
end

axes(handles.axes1);
handles.img = imagesc(ref);
axis off;
colormap gray
running = 0;






% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

points = detectBRISKFeatures(handles.axes1.Children.CData,'MinQuality',0.2,'MinContrast',0.4);


% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global L F;
sz = str2num(handles.sz.String);
L{end+1} = imrect(handles.axes1,[10 10 sz sz]);
wait(L{end});
p = round(L{end}.getPosition);
x = p(1):p(1)+p(3)-1;
y = p(2):p(2)+p(4)-1;
F{end+1} = fft2(handles.axes1.Children(end).CData(y,x));


% --- Executes on selection change in method.
function method_Callback(hObject, eventdata, handles)
% hObject    handle to method (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns method contents as cell array
%        contents{get(hObject,'Value')} returns selected item from method


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


% --- Executes on button press in align.
function align_Callback(hObject, eventdata, handles)
% hObject    handle to align (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global info fname ref running FileName

if(strcmp(hObject.String,'Abort'))
    hObject.String = 'Align';
    running = 0;
    return;
else
    hObject.String = 'Abort';
    running = 1;
end

switch handles.method.Value
    
    case 1
        
        handles.status.String = 'Allocating disk space...  Please wait.';
        dummy = system(sprintf('copy %s.sbx %s_rigid.sbx',fname,fname));
        dummy = system(sprintf('copy %s.mat %s_rigid.mat',fname,fname));

        mm = sbxreadmmap(fname,'_rigid');
        z = sbxread(fname,0,1);
        
        handles.status.String = sprintf('Aligned %d / %d frames',0,info.max_idx+1);
        T = zeros(info.max_idx,2);
        
        m = zeros(info.sz);
        
        pp = gcp;       % get the current pool
        
        tic
        
        for i = 0:pp.NumWorkers:(info.max_idx-1)
            
            if(running==0) 
                break;
            end
            
            M = min([pp.NumWorkers info.max_idx-1-i]);
            
            handles.status.String = ...
                sprintf('Aligned %d / %d frames (%2.1f%%)',i,info.max_idx+1,100*i/(info.max_idx+1));
            
            drawnow;
            
            z = sbxread(fname,i,M);
            z = squeeze(z(handles.chan.Value,:,:,:));
            
            parfor j=1:M
                T(i+j,:) = fftalign(squeeze(z(:,:,j)),ref); 
            end
            
            for(j=1:M)
                reg = circshift(squeeze(z(:,:,j)),T(i+j,:));
                mm.Data.img(handles.chan.Value,:,:,i+j) = intmax('uint16')-reg';
                m = m + double(reg);
            end
            
        end
        
        if(running==1)
            et = toc;
            m = m / info.max_idx;
            ref = m;
            save([fname '.align'],'m','T');
            handles.axes1.Children.CData = ref;
            handles.status.String = sprintf('File %s has been rigidly aligned (%.2f frames/s)',fname,info.max_idx/et);
        else
            handles.status.String = 'Aborted!';
        end
        running = 0;
        handles.align.String = 'Align';
        clear mm
        
    case 2      % translation imregtform
        
        [opt,met] = imregconfig('monomodal');
%         opt.MinimumStepLength = 0.0001;
%         opt.MaximumStepLength = 0.08;

        handles.status.String = 'Allocating disk space...  Please wait.';
        dummy = system(sprintf('copy %s.sbx %s_rigidsb.sbx',fname,fname));
        dummy = system(sprintf('copy %s.mat %s_rigidsb.mat',fname,fname));
        mm = sbxreadmmap(fname,'_rigidsb');
        z = sbxread(fname,0,1);

        handles.status.String = sprintf('Aligned %d / %d frames',0,info.max_idx+1);
        tform = cell(1,info.max_idx);
        m = zeros(info.sz);
        
        pp = gcp;       % get the current pool
        
        tic
        
        for i = 0:pp.NumWorkers:(info.max_idx-1)
            
            if(running==0)
                break;
            end
            
            M = min([pp.NumWorkers info.max_idx-1-i]);
            
            handles.status.String = ...
                sprintf('Aligned %d / %d frames (%2.1f%%)',i,info.max_idx+1,100*i/(info.max_idx+1));
            
            drawnow;
            
            z = sbxread(fname,i,M);
            z = squeeze(z(handles.chan.Value,:,:,:));
            
            parfor j=1:M
                tform{i+j,:} = imregtform(squeeze(z(:,70:end-70,j)),ref(:,70:end-70),'translation',opt,met);
            end
            
            for(j=1:M)
                reg = imwarp(squeeze(z(:,:,j)),tform{i+j},'OutputView',imref2d(size(ref)));
                mm.Data.img(handles.chan.Value,:,:,i+j) = intmax('uint16')-reg';
                m = m + double(reg);
            end
            
        end
        
        if(running==1)
            et = toc;
            msub = m / info.max_idx;
            ref = msub;
            save([fname '.align'],'msub');
            handles.axes1.Children.CData = ref;
            handles.status.String = sprintf('File %s has been rigidly aligned (%.2f frames/s)',fname,info.max_idx/et);
        else
            handles.status.String = 'Aborted!';
        end
        clear mm
        running = 0;
        handles.align.String = 'Align';

        
    case 3      % affine imregtform
        
        [opt,met] = imregconfig('monomodal');
%         opt.MinimumStepLength = 0.0001;
%         opt.MaximumStepLength = 0.08;

        handles.status.String = 'Allocating disk space...  Please wait.';
        dummy = system(sprintf('copy %s.sbx %s_affine.sbx',fname,fname));
        dummy = system(sprintf('copy %s.mat %s_affine.mat',fname,fname));
        mm = sbxreadmmap(fname,'_affine');
        z = sbxread(fname,0,1);

        handles.status.String = sprintf('Aligned %d / %d frames',0,info.max_idx+1);
        tform = cell(1,info.max_idx);
        m = zeros(info.sz);
        
        pp = gcp;       % get the current pool
        
        tic
        
        for i = 0:pp.NumWorkers:(info.max_idx-1)
            
            if(running==0)
                break;
            end
            
            M = min([pp.NumWorkers info.max_idx-1-i]);
            
            handles.status.String = ...
                sprintf('Aligned %d / %d frames (%2.1f%%)',i,info.max_idx+1,100*i/(info.max_idx+1));
            
            drawnow;
            
            z = sbxread(fname,i,M);
            z = squeeze(z(handles.chan.Value,:,:,:));
            
            parfor j=1:M
                tform{i+j,:} = imregtform(squeeze(z(:,70:end-70,j)),ref(:,70:end-70),'affine',opt,met);
            end
            
            for(j=1:M)
                reg = imwarp(squeeze(z(:,:,j)),tform{i+j},'OutputView',imref2d(size(ref)));
                mm.Data.img(handles.chan.Value,:,:,i+j) = intmax('uint16')-reg';
                m = m + double(reg);
            end
            
        end
        
        if(running==1)
            et = toc;
            maff = m / info.max_idx;
            ref = msub;
            save([fname '.align'],'maff');
            handles.axes1.Children.CData = ref;
            handles.status.String = sprintf('File %s has been rigidly aligned (%.2f frames/s)',fname,info.max_idx/et);
        else
            handles.status.String = 'Aborted!';
        end
        clear mm
        running = 0;
        handles.align.String = 'Align';

    case 4
        
        handles.status.String = 'Allocating disk space...  Please wait.';

        gref = gpuArray(ref);
        dummy = system(sprintf('copy %s.sbx %s_nonrigid.sbx',fname,fname));
        dummy = system(sprintf('copy %s.mat %s_nonrigid.mat',fname,fname));
        mm = sbxreadmmap(fname,'_nonrigid');
        
        z = sbxread(fname,0,1);
        handles.status.String = sprintf('Aligned %d / %d frames',0,info.max_idx+1);
        m = zeros(info.sz);

        pp = gcp;       % get the current pool
        
        tic
        for i = 0:pp.NumWorkers:(info.max_idx-1)
            
            if(running==0)
                break;
            end
            
            M = min([pp.NumWorkers info.max_idx-1-i]);
                        
            handles.status.String = ...
                sprintf('Aligned %d / %d frames (%2.1f%%)',i,info.max_idx+1,100*i/(info.max_idx+1));
            
            drawnow;
            
            z = sbxread(fname,i,M);
            z = squeeze(z(handles.chan.Value,:,:,:));
            
            gz = gpuArray(z);
            zr = zeros(size(z),'uint16','gpuArray');
            
            parfor j=1:M
                [~,zr(:,:,j)] = imregdemons(squeeze(gz(:,:,j)),gref,[32 16 8],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',3,'DisplayWaitBar',false);
            end
            
            for j=1:M
                r = gather(squeeze(zr(:,:,j)));
                mm.Data.img(handles.chan.Value,:,:,i+j) = intmax('uint16')-r';
                m = m + double(r);
            end

        end
        
        if(running ==1) 
        et = toc;
        m = m / info.max_idx;
        ref = m;
        mnr = m;
        handles.axes1.Children.CData = gather(ref);
        handles.status.String = sprintf('File %s has been rigidly aligned (%.2f frames/s)',fname,info.max_idx/et);
        if(exist([fname '.align'],'file'))
            save('-append',[fname '.align'],'mnr');
        else
            save([fname '.align'],'mnr');
        end
        else
            handles.status.String = 'Aborted!';
        end
        clear mm
        running = 0;
        handles.align.String = 'Align';
        
        
    case 5
        
        handles.status.String = 'Allocating disk space...  Please wait.';
        dummy = system(sprintf('copy %s.sbx %s_nonrigid.sbx',fname,fname));
        dummy = system(sprintf('copy %s.mat %s_nonrigid.mat',fname,fname));
        mm = sbxreadmmap(fname,'_nonrigid');
        
        z = sbxread(fname,0,1);
        handles.status.String = sprintf('Aligned %d / %d frames',0,info.max_idx+1);
        m = zeros(info.sz);

        pp = gcp;       % get the current pool
        
        tic
        for i = 0:pp.NumWorkers:(info.max_idx-1)
            
            if(running==0)
                break;
            end
            
            M = min([pp.NumWorkers info.max_idx-1-i]);
                        
            handles.status.String = ...
                sprintf('Aligned %d / %d frames (%2.1f%%)',i,info.max_idx+1,100*i/(info.max_idx+1));
            
            drawnow;
            
            z = sbxread(fname,i,M);
            z = squeeze(z(handles.chan.Value,:,:,:));
            zr = zeros(size(z),'uint16');
            
            parfor j=1:M
                [~,zr(:,:,j)] = imregdemons(squeeze(z(:,:,j)),ref,[32 16 8],'AccumulatedFieldSmoothing',2.5,'PyramidLevels',3,'DisplayWaitBar',false);
            end
            
            for j=1:M
                r = squeeze(zr(:,:,j));
                mm.Data.img(handles.chan.Value,:,:,i+j) = intmax('uint16')-r';
                m = m + double(r);
            end

        end
        
        if(running ==1) 
        et = toc;
        m = m / info.max_idx;
        ref = m;
        mnr = m;
        handles.axes1.Children.CData = gather(ref);
        handles.status.String = sprintf('File %s has been rigidly aligned (%.2f frames/s)',fname,info.max_idx/et);
        if(exist([fname '.align'],'file'))
            save('-append',[fname '.align'],'mnr');
        else
            save([fname '.align'],'mnr');
        end
        else
            handles.status.String = 'Aborted!';
        end
        clear mm
        running = 0;
        handles.align.String = 'Align';
        
end


% --- Executes during object creation, after setting all properties.
function axes1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate axes1
hObject.Visible = 'off';


% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

imcontrast(handles.axes1);



function sz_Callback(hObject, eventdata, handles)
% hObject    handle to sz (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of sz as text
%        str2double(get(hObject,'String')) returns contents of sz as a double


% --- Executes during object creation, after setting all properties.
function sz_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sz (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in chan.
function chan_Callback(hObject, eventdata, handles)
% hObject    handle to chan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns chan contents as cell array
%        contents{get(hObject,'Value')} returns selected item from chan


% --- Executes during object creation, after setting all properties.
function chan_CreateFcn(hObject, eventdata, handles)
% hObject    handle to chan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in gpu.
function gpu_Callback(hObject, eventdata, handles)
% hObject    handle to gpu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns gpu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from gpu


% --- Executes during object creation, after setting all properties.
function gpu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gpu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

if(gpuDeviceCount>1)
    hObject.String = {'gpuDevice(1)','gpuDevice(2)'};
end

% --- Executes during object creation, after setting all properties.
function pushbutton1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function align_CreateFcn(hObject, eventdata, handles)
% hObject    handle to align (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function pushbutton5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on button press in pushbutton8.
function pushbutton8_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ref

[FileName,PathName] = uigetfile('*align','multiselect','off');

a = load('-mat',FileName);
if isfield(a,'mnr')
    ref = a.mnr;
    handles.status.String = 'Reference replaced with non-linear alignment';
elseif isfield(a,'m')
    ref = m;
    handles.status.String = 'Reference replaced with rigid alignment';
end

handles.axes1.Children.CData = ref;
