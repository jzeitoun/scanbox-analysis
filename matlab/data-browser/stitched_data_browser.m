function varargout = stitched_data_browser(varargin)
% STITCHED_DATA_BROWSER MATLAB code for stitched_data_browser.fig
%      STITCHED_DATA_BROWSER, by itself, creates a new STITCHED_DATA_BROWSER or raises the existing
%      singleton*.
%
%      H = STITCHED_DATA_BROWSER returns the handle to a new STITCHED_DATA_BROWSER or the handle to
%      the existing singleton*.
%
%      STITCHED_DATA_BROWSER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in STITCHED_DATA_BROWSER.M with the given input arguments.
%
%      STITCHED_DATA_BROWSER('Property','Value',...) creates a new STITCHED_DATA_BROWSER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before stitched_data_browser_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to stitched_data_browser_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help stitched_data_browser

% Last Modified by GUIDE v2.5 06-Apr-2017 16:16:00

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @stitched_data_browser_OpeningFcn, ...
                   'gui_OutputFcn',  @stitched_data_browser_OutputFcn, ...
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

% --- Executes just before stitched_data_browser is made visible.
function stitched_data_browser_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to stitched_data_browser (see VARARGIN)

% Choose default command line output for stitched_data_browser
handles.output = hObject;

% Set GUI window name
set(handles.figure1,'Name','Stitched Data Browser');

% Make GUI scalable
set(hObject,'Resize','on');

% Get merged roi data
handles.fname = varargin{1};
load(handles.fname);
handles.merged_rois = merged_dict.rois;

% Update pop-up menu with ROI options
cell_ids = fieldnames(handles.merged_rois);
for n = 1:size(cell_ids,1)
    id = cell_ids{n};
    cell_ids{n} = str2num(id(9:end));
end
sorted_ids = sort(cell2mat(cell_ids));
roi_selection = num2cell(sorted_ids);
for k = 1:size(roi_selection,1)
    roi_selection{k} = num2str(roi_selection{k});
end
set(handles.roi_popup,'String',roi_selection);
default_roi = ['cell_id_' roi_selection{1}];

% Plot first ROI
plot_mean_traces(handles.merged_rois.(default_roi),handles.avgtrace_panel);
plot_t_curve(handles.merged_rois.(default_roi),handles.t_curve_axes);
plot_stats(handles.merged_rois.(default_roi),handles.uitable);

% Update current roi handle
handles.current_roi = default_roi;

% Update handles structure
guidata(hObject, handles);


% --- Outputs from this function are returned to the command line.
function varargout = stitched_data_browser_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in roi_popup.
function roi_popup_Callback(hObject, eventdata, handles)
% hObject    handle to roi_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

contents = cellstr(get(hObject,'String'));
selected_roi = ['cell_id_' contents{get(hObject,'Value')}];
plot_mean_traces(handles.merged_rois.(selected_roi),handles.avgtrace_panel);
plot_t_curve(handles.merged_rois.(selected_roi),handles.t_curve_axes);
plot_stats(handles.merged_rois.(selected_roi),handles.uitable);

% update current_roi handle
handles.current_roi = selected_roi;


% --- Executes during object creation, after setting all properties.
function roi_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roi_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function save_top_Callback(hObject, eventdata, handles)
% hObject    handle to save_top (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function save_fig_Callback(hObject, eventdata, handles)
% hObject    handle to save_fig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

subplots = findobj(handles.avgtrace_panel,'Type','axes'); % Get subplots
for k = 1:size(subplots,1)
    ax = subplots(k);
    ax.XColor = 'k';
    ax.YColor = 'k';
end
fig = figure();
s = copyobj(subplots,fig); % Copy axes object h into figure f1
savefig(fig,[handles.fname(1:end-4), '_', handles.current_roi]);
delete(fig);


% --------------------------------------------------------------------
function save_pdf_Callback(hObject, eventdata, handles)
% hObject    handle to save_fig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

subplots=findobj(handles.avgtrace_panel,'Type','axes');
fig = figure();
s = copyobj(subplots,fig);
saveas(fig,[handles.fname(1:end-4), '_', handles.current_roi, '.pdf']);
delete(fig);
